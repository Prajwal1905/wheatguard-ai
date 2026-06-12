# app/ndvi_stress.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.crud import (
    create_ndvi_stress_alert,
    get_active_ndvi_stress_alerts,
)
from app.models.ndvi_history import NDVIHistory
from app.models.ndvi_stress import NDVIStressAlert

router = APIRouter(prefix="/api", tags=["NDVI Stress"])

COORD_TOLERANCE = 0.0001  # ~11 metres


def classify_severity(drop: float) -> str:
    if drop > 0.35:
        return "Critical"
    if drop > 0.20:
        return "High"
    if drop > 0.10:
        return "Moderate"
    return ""


@router.post("/ndvi/stress/scan")
def scan_ndvi_stress(db: Session = Depends(get_db)):
   
    # Get all unique locations by rounding to 4 decimal places
    all_entries = db.query(NDVIHistory).all()

    location_map: dict = {}
    for entry in all_entries:
        key = (round(float(entry.lat), 4), round(float(entry.lon), 4))
        location_map.setdefault(key, []).append(entry)

    stressed_locations = set()
    alerts_created = 0
    alerts_updated = 0

    for (lat_r, lon_r), entries in location_map.items():
        entries.sort(key=lambda e: e.timestamp, reverse=True)

        if len(entries) < 3:
            continue

        current_ndvi = float(entries[0].ndvi)
        past_values = [float(e.ndvi) for e in entries[1:]]

        if not past_values:
            continue

        baseline = sum(past_values) / len(past_values)
        drop = baseline - current_ndvi

        severity = classify_severity(drop)
        if not severity:
            continue  # location is healthy — handled by auto-resolve below

        stressed_locations.add((lat_r, lon_r))

        # Is there already an active (unresolved) alert for this location?
        existing = (
            db.query(NDVIStressAlert)
            .filter(
                NDVIStressAlert.lat == lat_r,
                NDVIStressAlert.lon == lon_r,
                NDVIStressAlert.resolved == False,
            )
            .first()
        )

        if existing:
            existing.baseline_ndvi = round(baseline, 3)
            existing.current_ndvi = round(current_ndvi, 3)
            existing.drop = round(drop, 3)
            existing.severity = severity
            alerts_updated += 1
        else:
            create_ndvi_stress_alert(
                db,
                lat=lat_r,
                lon=lon_r,
                baseline=round(baseline, 3),
                current=round(current_ndvi, 3),
                drop=round(drop, 3),
                severity=severity,
            )
            alerts_created += 1

    # --- Auto-resolve: any active alert whose location has recovered ---
    auto_resolved = 0
    active_alerts = (
        db.query(NDVIStressAlert)
        .filter(NDVIStressAlert.resolved == False)
        .all()
    )
    for alert in active_alerts:
        key = (round(alert.lat, 4), round(alert.lon, 4))
        if key not in stressed_locations:
            alert.resolved = True
            auto_resolved += 1

    db.commit()

    return {
        "status": "ok",
        "alerts_created": alerts_created,
        "alerts_updated": alerts_updated,
        "auto_resolved": auto_resolved,
    }


@router.get("/ndvi/stress")
def list_ndvi_stress(db: Session = Depends(get_db)):
    alerts = get_active_ndvi_stress_alerts(db)

    return [
        {
            "id":            a.id,
            "lat":           a.lat,
            "lon":           a.lon,
            "baseline_ndvi": a.baseline_ndvi,
            "current_ndvi":  a.current_ndvi,
            "drop":          a.drop,
            "severity":      a.severity,
            "created_at":    a.created_at,
        }
        for a in alerts
    ]


@router.patch("/ndvi/stress/{alert_id}/resolve")
def resolve_stress_alert(alert_id: int, db: Session = Depends(get_db)):
   
    alert = db.query(NDVIStressAlert).filter(NDVIStressAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Stress alert not found")

    alert.resolved = True
    db.commit()
    return {"message": "resolved", "id": alert_id}


@router.patch("/ndvi/stress/{alert_id}/reopen")
def reopen_stress_alert(alert_id: int, db: Session = Depends(get_db)):
    """Undo a manual resolve."""
    alert = db.query(NDVIStressAlert).filter(NDVIStressAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Stress alert not found")

    alert.resolved = False
    db.commit()
    return {"message": "reopened", "id": alert_id}
