# app/routes/drone.py
from fastapi import APIRouter, UploadFile, File, Form, Depends
from datetime import datetime
from uuid import uuid4

from app.ml.model_utils import predict_image
from app.utils.socket_manager import broadcast_new_detection, broadcast_new_alert
from app.db.database import SessionLocal
from app import crud, schemas

router = APIRouter(prefix="/drone", tags=["Drone"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/analyze")
async def analyze_drone_image(
    file: UploadFile = File(...),
    lat: float = Form(...),
    lon: float = Form(...),
    db=Depends(get_db)
):
    image_bytes = await file.read()

    result = predict_image(image_bytes)

    detection_data = {
        "report_id": None,
        "disease_label": result["label"],
        "confidence": result["confidence"],
        "severity": result["severity"],
        "bbox": result.get("bbox"),
        "model_version": "v1.0"
    }

    detection = crud.create_detection(db, detection_data)

    
    await broadcast_new_detection({
        "id": detection.id,
        "lat": lat,
        "lon": lon,
        "disease": detection.disease_label,
        "confidence": detection.confidence,
        "severity": detection.severity,
        "timestamp": detection.created_at.isoformat(),
        "source": "drone"
    })

    alert = crud.create_alert(db, schemas.AlertCreate(
        disease=result["label"],
        severity=result["severity"],
        lat=lat,
        lon=lon,
        cases=1,
        source="drone"
    ))

    await broadcast_new_alert({
        "id": alert.id,
        "disease": alert.disease,
        "severity": alert.severity,
        "lat": alert.lat,
        "lon": alert.lon,
        "cases": alert.cases,
        "source": "drone",
        "timestamp": alert.created_at.isoformat()
    })

    return {
        "detection": detection.id,
        "alert": alert.id,
        "result": result
    }
