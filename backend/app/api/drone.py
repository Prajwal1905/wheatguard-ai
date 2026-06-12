# app/api/drone.py

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.ml.model_utils import predict_image
from app.utils.socket_manager import broadcast_new_detection
from app.db.database import SessionLocal
from app import crud
from app.models.report import Report
from app.models.detection import Detection
from app.api.alerts import create_alert_internal

router = APIRouter(prefix="/drone", tags=["Drone"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def calculate_severity(confidence: float) -> str:
    
    if confidence >= 85:
        return "High"
    if confidence >= 60:
        return "Moderate"
    return "Low"


@router.post("/analyze")
async def analyze_drone_image(
    file: UploadFile = File(...),
    lat: float = Form(...),
    lon: float = Form(...),
    db: Session = Depends(get_db),
):
    #  Read image
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file")

    #  Run inference
    result = predict_image(image_bytes)
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])

    disease    = result["exact_disease"]
    confidence = float(result.get("confidence", 0))
    severity   = calculate_severity(confidence)

    #  Save a Report row so Detection has a valid report_id
    report = Report(
        source="drone",
        image_url=None,
        lat=lat,
        lon=lon,
        created_at=datetime.utcnow(),
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    #  Save Detection
    detection = crud.create_detection(db, {
        "report_id":     report.id,
        "disease_label": disease,
        "confidence":    confidence,
        "severity":      severity,
        "bbox":          result.get("bbox"),
        "model_version": "19-class-efficientnet-b3-onnx",
    })

    #  Broadcast detection over Socket.IO (shows up on live map immediately)
    await broadcast_new_detection({
        "id":         detection.id,
        "lat":        lat,
        "lon":        lon,
        "disease":    detection.disease_label,
        "confidence": detection.confidence,
        "severity":   detection.severity,
        "timestamp":  detection.created_at.isoformat(),
        "source":     "drone",
    })

    
    return {
        "detection": {
            "id":         detection.id,
            "disease":    detection.disease_label,
            "confidence": round(detection.confidence, 2),
            "severity":   detection.severity,
            "lat":        lat,
            "lon":        lon,
            "timestamp":  detection.created_at.isoformat(),
        },
        "result": {
            "label":          disease,
            "exact_disease":  disease,
            "confidence":     round(confidence, 2),
            "severity":       severity,
            "remedy":         result.get("remedy"),
            "ai_explanation": result.get("ai_explanation"),
        },
    }


@router.post("/detections/{detection_id}/alert")
async def send_drone_alert(detection_id: int, db: Session = Depends(get_db)):
    
    detection = db.query(Detection).filter(Detection.id == detection_id).first()
    if not detection:
        raise HTTPException(status_code=404, detail="Detection not found")

    if not detection.report or detection.report.lat is None or detection.report.lon is None:
        raise HTTPException(status_code=400, detail="Detection has no location data")

    if detection.disease_label == "Healthy":
        raise HTTPException(status_code=400, detail="Cannot alert on a Healthy detection")

    alert = await create_alert_internal(
        db,
        disease=detection.disease_label,
        severity=detection.severity,
        lat=detection.report.lat,
        lon=detection.report.lon,
        cases=1,
        source="drone",
    )

    return {
        "message": "Alert sent to nearby farmers",
        "alert": {
            "id":       alert.id,
            "disease":  alert.disease,
            "severity": alert.severity,
        },
    }
