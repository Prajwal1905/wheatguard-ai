from fastapi import APIRouter, Depends, File, UploadFile, Form, Body
from sqlalchemy.orm import Session
import uuid

from app.db.database import SessionLocal
from app.models.report import Report
from app.models.detection import Detection

from app import crud
from app.utils.socket_manager import broadcast_new_detection
from app.utils.supabase_upload import upload_detection_image
from app.ml.model_utils import predict_image

router = APIRouter(prefix="/detections", tags=["Detections"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/predict")
async def predict_disease(
    file: UploadFile = File(...),
    language: str = Form("en"),
    lat: float = Form(...),
    lon: float = Form(...),
    db: Session = Depends(get_db)
):
    try:
        
        image_bytes = await file.read()
        unique_filename = f"{uuid.uuid4()}.jpg"

        image_url = upload_detection_image(image_bytes, unique_filename)
        if image_url is None:
            return {"error": "Image upload failed"}

        result = predict_image(image_bytes, language=language)
        if "error" in result:
            return result

        exact = result["exact_disease"]
        confidence = float(result["confidence"])
        remedy = result["remedy"]
        explanation = result["ai_explanation"]

        
        if confidence >= 85:
            severity = "High"
        elif confidence >= 60:
            severity = "Moderate"
        else:
            severity = "Low"

        report = Report(
            source="mobile",
            image_url=image_url,
            lat=lat,
            lon=lon
        )
        db.add(report)
        db.commit()
        db.refresh(report)

        detection = crud.create_detection(db, {
            "report_id": report.id,
            "disease_label": exact,
            "confidence": confidence,
            "severity": severity,
            "bbox": None,
            "model_version": "15-class-v1"
        })

        
        return {
            "report_id": report.id,
            "detection_id": detection.id,
            "image_url": image_url,
            "disease": exact,
            "confidence": confidence,
            "severity": severity,
            "remedy": remedy,
            "ai_explanation": explanation,
        }

    except Exception as e:
        print(" Predict error:", e)
        return {"error": str(e)}


@router.post("/save")
async def save_detection(
    payload: dict = Body(...),
    db: Session = Depends(get_db)
):
    try:
        lat = payload.get("lat")
        lon = payload.get("lon")

        
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
            "report_id": report.id,
            "disease_label": payload.get("disease"),
            "confidence": float(payload.get("confidence", 0)),
            "severity": payload.get("severity", "Medium"),
            "bbox": payload.get("bbox"),
            "model_version": payload.get("model_version", "15-class-v1"),
        })

        
        await broadcast_new_detection({
            "id": detection.id,
            "disease": detection.disease_label,
            "confidence": detection.confidence,
            "severity": detection.severity,
            "timestamp": detection.created_at.isoformat(),
            "lat": lat,
            "lon": lon
        })

        return {"message": "saved", "id": detection.id}

    except Exception as e:
        print(" Error saving detection:", e)
        return {"error": str(e)}


@router.get("/map_data")
def get_map_data(db: Session = Depends(get_db)):
    detections = crud.get_detections(db)
    out = []

    for d in detections:
        out.append({
            "id": d.id,
            "disease": d.disease_label,
            "confidence": d.confidence,
            "severity": d.severity,
            "lat": d.report.lat,
            "lon": d.report.lon,
            "timestamp": d.created_at.isoformat(),
        })

    return out


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
