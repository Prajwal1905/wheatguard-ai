# app/routes/ndvi_stress.py

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, Numeric, cast
from app.db.database import get_db

from app.crud import (
    clear_ndvi_stress_alerts,
    create_ndvi_stress_alert,
    get_active_ndvi_stress_alerts,
)
from app.models.ndvi_history import NDVIHistory

router = APIRouter(prefix="/api", tags=["NDVI Stress"])


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

    clear_ndvi_stress_alerts(db)

    locs = (
        db.query(
            func.round(cast(NDVIHistory.lat, Numeric(10, 6)), 4).label("lat_r"),
            func.round(cast(NDVIHistory.lon, Numeric(10, 6)), 4).label("lon_r"),
        )
        .group_by("lat_r", "lon_r")
        .all()
    )

    total_alerts = 0

    for lat_r, lon_r in locs:

        history = (
            db.query(NDVIHistory)
            .filter(
                func.round(cast(NDVIHistory.lat, Numeric(10, 6)), 4) == lat_r,
                func.round(cast(NDVIHistory.lon, Numeric(10, 6)), 4) == lon_r,
            )
            .order_by(NDVIHistory.timestamp.desc())
            .limit(10)
            .all()
        )

        if len(history) < 3:
            continue

        current_ndvi = history[0].ndvi
        past_values = [h.ndvi for h in history[1:]]

        if not past_values:
            continue

        baseline = sum(past_values) / len(past_values)
        drop = baseline - current_ndvi

        severity = classify_severity(drop)
        if not severity:
            continue

        create_ndvi_stress_alert(
            db,
            lat=float(lat_r),
            lon=float(lon_r),
            baseline=float(round(baseline, 3)),
            current=float(round(current_ndvi, 3)),
            drop=float(round(drop, 3)),
            severity=severity,
        )

        total_alerts += 1

    return {"status": "ok", "alerts_created": total_alerts}


@router.get("/ndvi/stress")
def list_ndvi_stress(db: Session = Depends(get_db)):
    alerts = get_active_ndvi_stress_alerts(db)

    return [
        {
            "id": a.id,
            "lat": a.lat,
            "lon": a.lon,
            "baseline_ndvi": a.baseline_ndvi,
            "current_ndvi": a.current_ndvi,
            "drop": a.drop,
            "severity": a.severity,
            "created_at": a.created_at,
        }
        for a in alerts
    ]
