from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app import crud, schemas

from app.models.fcm_device import FCMDevice
from app.utils.socket_manager import broadcast_new_alert
from app.utils.fcm_sender import send_fcm, haversine

router = APIRouter(prefix="/alerts", tags=["Alerts"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/", response_model=schemas.AlertResponse)
async def create_alert(alert: schemas.AlertCreate, db: Session = Depends(get_db)):

    
    saved = crud.create_alert(db, alert)

    await broadcast_new_alert({
        "id": saved.id,
        "disease": saved.disease,
        "severity": saved.severity,
        "cases": saved.cases,
        "lat": saved.lat,
        "lon": saved.lon,
        "source": saved.source,
        "timestamp": saved.created_at.isoformat()
    })

    
    users = db.query(FCMToken).all()

    for user in users:
        if user.lat is None or user.lon is None:
            continue

        dist = haversine(alert.lat, alert.lon, user.lat, user.lon)

        if dist <= 5:  
            send_fcm(
                token=user.token,
                title=f"Disease Alert: {alert.disease}",
                body=f"{alert.severity} severity near your area ({dist:.1f} km)",
                data={
                    "lat": alert.lat,
                    "lon": alert.lon,
                    "disease": alert.disease
                }
            )

    return saved

@router.get("/", response_model=list[schemas.AlertResponse])
def list_alerts(db: Session = Depends(get_db)):
    return crud.get_alerts(db)

@router.get("/nearby")
def get_nearby_alerts(lat: float, lon: float, db: Session = Depends(get_db)):
    alerts = crud.get_alerts(db)
    nearby = []

    from math import radians, sin, cos, sqrt, atan2
    R = 6371

    for a in alerts:
        if a.lat is None or a.lon is None:
            continue

        dlat = radians(a.lat - lat)
        dlon = radians(a.lon - lon)

        x = sin(dlat/2)**2 + cos(radians(lat)) * cos(radians(a.lat)) * sin(dlon/2)**2
        distance = R * 2 * atan2(sqrt(x), sqrt(1-x))

        if distance <= 5:
            nearby.append({
                "id": a.id,
                "disease": a.disease,
                "severity": a.severity,
                "cases": a.cases,
                "lat": a.lat,
                "lon": a.lon,
                "distance": round(distance, 2),
                "timestamp": a.created_at.isoformat()
            })

    return nearby
