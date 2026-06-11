# app/api/detections.py

from fastapi import APIRouter, Depends, File, UploadFile, Form, Body, HTTPException
from sqlalchemy.orm import Session
import uuid

from app.db.database import SessionLocal
from app.models.report import Report
from app.models.detection import Detection
from app import crud
from app.utils.socket_manager import broadcast_new_detection
from app.utils.supabase_upload import upload_detection_image
from app.ml.model_utils import predict_image
from app.ml.ai_helper import get_short_remedy

router = APIRouter(prefix="/detections", tags=["Detections"])


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


@router.post("/predict")
async def predict_disease(
    file: UploadFile = File(...),
    language: str = Form("en"),
    lat: float = Form(...),
    lon: float = Form(...),
    db: Session = Depends(get_db),
):
    try:
        image_bytes = await file.read()
        if not image_bytes:
            return {"error": "Empty image file"}

        unique_filename = f"{uuid.uuid4()}.jpg"
        image_url = upload_detection_image(image_bytes, unique_filename)
        if image_url is None:
            return {"error": "Image upload failed"}

        result = predict_image(image_bytes, language=language)
        if "error" in result:
            return result

        disease     = result["exact_disease"]
        confidence  = float(result["confidence"])
        severity    = calculate_severity(confidence)
        remedy      = result["remedy"]
        explanation = result["ai_explanation"]

        report = Report(source="mobile", image_url=image_url, lat=lat, lon=lon)
        db.add(report)
        db.commit()
        db.refresh(report)

        detection = crud.create_detection(db, {
            "report_id":     report.id,
            "disease_label": disease,
            "confidence":    confidence,
            "severity":      severity,
            "bbox":          None,
            "model_version": "19-class-efficientnet-b3-onnx",
        })

        return {
            "report_id":      report.id,
            "detection_id":   detection.id,
            "image_url":      image_url,
            "disease":        disease,
            "confidence":     round(confidence, 2),
            "severity":       severity,
            "remedy":         remedy,
            "ai_explanation": explanation,
        }

    except Exception as e:
        print("Predict error:", e)
        return {"error": str(e)}


@router.post("/save")
async def save_detection(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
):
    try:
        lat        = payload.get("lat")
        lon        = payload.get("lon")
        confidence = float(payload.get("confidence", 0))

        report = Report(
            source="mobile",
            image_url=payload.get("image_url"),
            lat=lat,
            lon=lon,
        )
        db.add(report)
        db.commit()
        db.refresh(report)

        detection = crud.create_detection(db, {
            "report_id":     report.id,
            "disease_label": payload.get("disease"),
            "confidence":    confidence,
            "severity":      payload.get("severity") or calculate_severity(confidence),
            "bbox":          payload.get("bbox"),
            "model_version": payload.get("model_version", "19-class-efficientnet-b3-onnx"),
        })

        await broadcast_new_detection({
            "id":         detection.id,
            "disease":    detection.disease_label,
            "confidence": detection.confidence,
            "severity":   detection.severity,
            "timestamp":  detection.created_at.isoformat(),
            "lat":        lat,
            "lon":        lon,
        })

        return {"message": "saved", "id": detection.id}

    except Exception as e:
        print("Error saving detection:", e)
        return {"error": str(e)}


@router.get("/map_data")
def get_map_data(
    skip: int = 0,
    limit: int = 500,
    db: Session = Depends(get_db),
):
    detections = (
        db.query(Detection)
        .join(Report, Detection.report_id == Report.id)
        .filter(Report.lat.isnot(None), Report.lon.isnot(None))
        .order_by(Detection.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        {
            "id":         d.id,
            "disease":    d.disease_label,
            "confidence": round(float(d.confidence or 0), 2),
            "severity":   d.severity,
            "lat":        float(d.report.lat),
            "lon":        float(d.report.lon),
            "timestamp":  d.created_at.isoformat(),
            "source":     d.report.source,
        }
        for d in detections
    ]


@router.get("/{detection_id}")
def get_detection_detail(detection_id: int, db: Session = Depends(get_db)):
    
    detection = db.query(Detection).filter(Detection.id == detection_id).first()

    if not detection:
        raise HTTPException(status_code=404, detail="Detection not found")

    remedy = None
    try:
        remedy = get_short_remedy(detection.disease_label, language="en")
    except Exception:
        pass

    return {
        "id":            detection.id,
        "disease":       detection.disease_label,
        "confidence":    round(float(detection.confidence or 0), 2),
        "severity":      detection.severity,
        "model_version": detection.model_version,
        "timestamp":     detection.created_at.isoformat(),
        "image_url":     detection.report.image_url if detection.report else None,
        "lat":           float(detection.report.lat) if detection.report else None,
        "lon":           float(detection.report.lon) if detection.report else None,
        "source":        detection.report.source if detection.report else None,
        "remedy":        remedy,
    }


@router.delete("/{report_id}")
def delete_detection(report_id: int, db: Session = Depends(get_db)):
    try:
        db.query(Detection).filter(Detection.report_id == report_id).delete()
        db.query(Report).filter(Report.id == report_id).delete()
        db.commit()
        return {"message": "deleted"}
    except Exception as e:
        db.rollback()
        return {"error": str(e)}
