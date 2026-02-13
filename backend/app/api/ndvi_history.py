from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.ndvi_history import NDVIHistory

router = APIRouter(prefix="/api", tags=["NDVI History"])

@router.get("/ndvi_history")
def get_ndvi_history(lat: float, lon: float, db: Session = Depends(get_db)):
    
    lat_r = round(lat, 4)
    lon_r = round(lon, 4)

    history = (
        db.query(NDVIHistory)
        .filter(NDVIHistory.lat == lat_r, NDVIHistory.lon == lon_r)
        .order_by(NDVIHistory.timestamp.desc())
        .limit(10)
        .all()
    )

    return [
        {
            "ndvi": h.ndvi,
            "timestamp": h.timestamp,
        }
        for h in history
    ]
