# backend/app/routes/map_data.py

from fastapi import APIRouter, Query, Depends
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app import models
import math

router = APIRouter(prefix="/map", tags=["Map Data"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def haversine(lat1, lon1, lat2, lon2):
    R = 6371  
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

@router.get("/data")
def get_map_data(db: Session = Depends(get_db)):
    results = (
        db.query(
            models.Detection.id,
            models.Detection.disease_label.label("disease"),
            models.Detection.confidence,
            models.Detection.severity,
            models.Report.lat,
            models.Report.lon,
        )
        .join(models.Report, models.Detection.report_id == models.Report.id)
        .filter(models.Report.lat.isnot(None))
        .filter(models.Report.lon.isnot(None))
        .all()
    )



    return [
        {
            "id": r.id,
            "disease": r.disease,
            "confidence": float(r.confidence or 0),
            "severity": r.severity,
            "lat": float(r.lat or 0),
            "lon": float(r.lon or 0),
        }
        for r in results
    ]

@router.get("/nearby")
def get_nearby_alerts(
    lat: float = Query(...),
    lon: float = Query(...),
    db: Session = Depends(get_db),
):
    results = (
        db.query(
            models.Detection.disease_label.label("disease"),
            models.Detection.severity,
            models.Report.lat,
            models.Report.lon,
        )
        .join(models.Report, models.Detection.report_id == models.Report.id)
        .filter(models.Report.lat.isnot(None))
        .filter(models.Report.lon.isnot(None))
        .all()
    )

    nearby = []
    for r in results:
        dist = haversine(lat, lon, r.lat, r.lon)
        if dist <= 5:  
            nearby.append({
                "disease": r.disease,
                "severity": r.severity,
                "distance": round(dist, 2),
            })
    return nearby