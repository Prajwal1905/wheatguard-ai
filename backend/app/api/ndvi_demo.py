from fastapi import APIRouter
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.ndvi_history import NDVIHistory
import random

router = APIRouter(prefix="/api/ndvi/demo", tags=["NDVI Demo"])

@router.post("/insert")
def insert_demo_points(db: Session = Depends(get_db)):

    lat = 19.0869
    lon = 76.7842

    values = [0.78, 0.76, 0.74, 0.71, 0.70, 0.68, 0.45, 0.40]  

    for ndvi in values:
        row = NDVIHistory(lat=lat, lon=lon, ndvi=ndvi)
        db.add(row)

    db.commit()

    return {"inserted": len(values)}
