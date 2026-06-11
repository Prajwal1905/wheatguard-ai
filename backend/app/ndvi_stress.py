# app/ndvi_stress.py

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime

from app.db.database import get_db
from app.crud import (
    clear_ndvi_stress_alerts,
    create_ndvi_stress_alert,
    get_active_ndvi_stress_alerts,
)
from app.models.ndvi_history import NDVIHistory

router = APIRouter(prefix="/api", tags=["NDVI Stress"])

COORD_TOLERANCE = 0.0001  # -11 metres


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

    # Get all unique locations by rounding to 4 decimal places
    all_entries = db.query(NDVIHistory).all()

    # Group manually to avoid SQL float rounding issues
    location_map: dict = {}
    for entry in all_entries:
        key = (round(float(entry.lat), 4), round(float(entry.lon), 4))
        if key not in location_map:
            location_map[key] = []
        location_map[key].append(entry)

    total_alerts = 0

    for (lat_r, lon_r), entries in location_map.items():
        # Sort by timestamp descending
        entries.sort(key=lambda e: e.timestamp, reverse=True)

        if len(entries) < 3:
            continue

        current_ndvi = float(entries[0].ndvi)
        past_values  = [float(e.ndvi) for e in entries[1:]]

        if not past_values:
            continue

        baseline = sum(past_values) / len(past_values)
        drop     = baseline - current_ndvi

        severity = classify_severity(drop)
        if not severity:
            continue

        create_ndvi_stress_alert(
            db,
            lat=lat_r,
            lon=lon_r,
            baseline=round(baseline, 3),
            current=round(current_ndvi, 3),
            drop=round(drop, 3),
            severity=severity,
        )

        total_alerts += 1

    return {"status": "ok", "alerts_created": total_alerts}


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
