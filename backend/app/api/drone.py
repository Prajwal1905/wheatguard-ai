# app/api/drone.py

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.ml.model_utils import predict_image
from app.utils.socket_manager import broadcast_new_detection, broadcast_new_alert
from app.db.database import SessionLocal
from app import crud, schemas
from app.models.report import Report

router = APIRouter(prefix="/drone", tags=["Drone"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def calculate_severity(confidence: float) -> str:
    """Single source of truth for severity — used everywhere."""
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
    # 1. Read image
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file")

    # 2. Run inference
    result = predict_image(image_bytes)
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])

    disease   = result["exact_disease"]
    confidence = float(result.get("confidence", 0))
    severity  = calculate_severity(confidence)

    # 3. Save a Report row so Detection has a valid report_id
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

    # 4. Save Detection
    detection = crud.create_detection(db, {
        "report_id":     report.id,
        "disease_label": disease,
        "confidence":    confidence,
        "severity":      severity,
        "bbox":          result.get("bbox"),
        "model_version": "19-class-efficientnet-b3-onnx",
    })

    # 5. Broadcast detection over Socket.IO
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

    # 6. Only create an alert if disease is not Healthy
    alert = None
    if disease != "Healthy":
        alert = crud.create_alert(db, schemas.AlertCreate(
            disease=disease,
            severity=severity,
            lat=lat,
            lon=lon,
            cases=1,
            source="drone",
        ))

        await broadcast_new_alert({
            "id":        alert.id,
            "disease":   alert.disease,
            "severity":  alert.severity,
            "lat":       alert.lat,
            "lon":       alert.lon,
            "cases":     alert.cases,
            "source":    "drone",
            "timestamp": alert.created_at.isoformat(),
        })

    # 7. Return clean response
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
        "alert": {
            "id":       alert.id,
            "disease":  alert.disease,
            "severity": alert.severity,
        } if alert else None,
        "result": {
            "label":         disease,
            "exact_disease": disease,
            "confidence":    round(confidence, 2),
            "severity":      severity,
            "remedy":        result.get("remedy"),
            "ai_explanation": result.get("ai_explanation"),
        },
    }
