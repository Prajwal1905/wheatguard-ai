# app/api/alerts.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.db.database import SessionLocal
from app import crud, schemas
from app.models.fcm_device import FCMDevice
from app.models.alert import Alert
from app.utils.socket_manager import broadcast_new_alert
from app.utils.fcm_sender import send_fcm, haversine

ALERT_RADIUS_KM = 2.0

router = APIRouter(prefix="/alerts", tags=["Alerts"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


async def create_alert_internal(
    db: Session,
    disease: str,
    severity: str,
    lat: float,
    lon: float,
    cases: int = 1,
    source: str = "mobile",
):
    """
    Create an alert + broadcast + FCM push, callable directly from
    other backend modules (e.g. detections.py for High-severity
    mobile detections) without going through the HTTP route
    (so no JWT needed for internal calls).
    """
    alert_data = schemas.AlertCreate(
        disease=disease,
        severity=severity,
        cases=cases,
        lat=lat,
        lon=lon,
        source=source,
    )

    saved = crud.create_alert(db, alert_data)

    await broadcast_new_alert({
        "id":        saved.id,
        "disease":   saved.disease,
        "severity":  saved.severity,
        "cases":     saved.cases,
        "lat":       saved.lat,
        "lon":       saved.lon,
        "source":    saved.source,
        "timestamp": saved.created_at.isoformat(),
    })

    # FCM push to farmers within ALERT_RADIUS_KM
    users = db.query(FCMDevice).all()
    for user in users:
        if user.lat is None or user.lon is None:
            continue
        dist = haversine(lat, lon, user.lat, user.lon)
        if dist <= ALERT_RADIUS_KM:
            send_fcm(
                token=user.token,
                title=f"Disease Alert: {disease}",
                body=f"{severity} severity near your area ({dist:.1f} km)",
                data={"lat": lat, "lon": lon, "disease": disease},
            )

    return saved


@router.post("/", response_model=schemas.AlertResponse)
async def create_alert(alert: schemas.AlertCreate, db: Session = Depends(get_db)):
    saved = crud.create_alert(db, alert)

    await broadcast_new_alert({
        "id":        saved.id,
        "disease":   saved.disease,
        "severity":  saved.severity,
        "cases":     saved.cases,
        "lat":       saved.lat,
        "lon":       saved.lon,
        "source":    saved.source,
        "timestamp": saved.created_at.isoformat(),
    })

    # FCM push to farmers within ALERT_RADIUS_KM
    users = db.query(FCMDevice).all()
    for user in users:
        if user.lat is None or user.lon is None:
            continue
        dist = haversine(alert.lat, alert.lon, user.lat, user.lon)
        if dist <= ALERT_RADIUS_KM:
            send_fcm(
                token=user.token,
                title=f"Disease Alert: {alert.disease}",
                body=f"{alert.severity} severity near your area ({dist:.1f} km)",
                data={"lat": alert.lat, "lon": alert.lon, "disease": alert.disease},
            )

    return saved


@router.get("/", response_model=list[schemas.AlertResponse])
def list_alerts(
    include_resolved: bool = False,
    db: Session = Depends(get_db),
):

    query = db.query(Alert)
    if not include_resolved:
        query = query.filter(Alert.is_resolved == False)
    return query.order_by(Alert.created_at.desc()).all()


@router.get("/nearby")
def get_nearby_alerts(lat: float, lon: float, db: Session = Depends(get_db)):
    from math import radians, sin, cos, sqrt, atan2
    R = 6371

    alerts = db.query(Alert).filter(Alert.is_resolved == False).all()
    nearby = []

    for a in alerts:
        if a.lat is None or a.lon is None:
            continue
        dlat = radians(a.lat - lat)
        dlon = radians(a.lon - lon)
        x = sin(dlat / 2) ** 2 + cos(radians(lat)) * cos(radians(a.lat)) * sin(dlon / 2) ** 2
        distance = R * 2 * atan2(sqrt(x), sqrt(1 - x))

        if distance <= ALERT_RADIUS_KM:
            nearby.append({
                "id":        a.id,
                "disease":   a.disease,
                "severity":  a.severity,
                "cases":     a.cases,
                "lat":       a.lat,
                "lon":       a.lon,
                "distance":  round(distance, 2),
                "timestamp": a.created_at.isoformat(),
            })

    return nearby


@router.patch("/{alert_id}/resolve")
def resolve_alert(alert_id: int, db: Session = Depends(get_db)):

    alert = db.query(Alert).filter(Alert.id == alert_id).first()

    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    if alert.is_resolved:
        return {"message": "Alert already resolved", "id": alert_id}

    alert.is_resolved  = True
    alert.resolved_at  = datetime.utcnow()
    db.commit()
    db.refresh(alert)

    return {
        "message":     "Alert resolved",
        "id":          alert.id,
        "resolved_at": alert.resolved_at.isoformat(),
    }


@router.patch("/{alert_id}/reopen")
def reopen_alert(alert_id: int, db: Session = Depends(get_db)):

    alert = db.query(Alert).filter(Alert.id == alert_id).first()

    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    alert.is_resolved = False
    alert.resolved_at = None
    db.commit()

    return {"message": "Alert reopened", "id": alert.id}


@router.delete("/{alert_id}")
def delete_alert(alert_id: int, db: Session = Depends(get_db)):
    alert = db.query(Alert).filter(Alert.id == alert_id).first()

    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    db.delete(alert)
    db.commit()

    return {"message": "Alert deleted", "id": alert_id}
