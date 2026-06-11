# app/api/ndvi_history.py

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.ndvi_history import NDVIHistory

router = APIRouter(prefix="/api", tags=["NDVI History"])

# Tolerance for float coordinate matching — 0.0001 degrees -11 metres
COORD_TOLERANCE = 0.0001


@router.get("/ndvi_history")
def get_ndvi_history(lat: float, lon: float, db: Session = Depends(get_db)):
    
    history = (
        db.query(NDVIHistory)
        .filter(
            NDVIHistory.lat >= lat - COORD_TOLERANCE,
            NDVIHistory.lat <= lat + COORD_TOLERANCE,
            NDVIHistory.lon >= lon - COORD_TOLERANCE,
            NDVIHistory.lon <= lon + COORD_TOLERANCE,
        )
        .order_by(NDVIHistory.timestamp.desc())
        .limit(30)
        .all()
    )

    return [
        {
            "ndvi":      round(float(h.ndvi), 3),
            "timestamp": h.timestamp,
            "lat":       h.lat,
            "lon":       h.lon,
        }
        for h in history
    ]
