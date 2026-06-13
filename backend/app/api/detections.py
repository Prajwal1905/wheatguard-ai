# app/api/detections.py

from fastapi import APIRouter, Depends, File, UploadFile, Form, Body, HTTPException, Request
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
from app.utils.rate_limiter import rate_limit
from app.utils.image_validation import validate_image_bytes
from app.api.alerts import create_alert_internal
from datetime import datetime

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
    request: Request,
    file: UploadFile = File(...),
    language: str = Form("en"),
    lat: float = Form(...),
    lon: float = Form(...),
    device_id: str = Form(None),  # device that captured this — used for ownership
    db: Session = Depends(get_db),
):
    # 10 predictions per minute per IP
    rate_limit(request, max_requests=10, window_seconds=60)
    try:
        image_bytes = await file.read()
        validate_image_bytes(image_bytes)

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

        report = Report(
            source="mobile",
            image_url=image_url,
            lat=lat,
            lon=lon,
            device_id=device_id,
        )
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

        # High-severity mobile detections trigger a nearby-farmer alert
        if severity == "High" and disease != "Healthy":
            try:
                await create_alert_internal(
                    db,
                    disease=disease,
                    severity=severity,
                    lat=lat,
                    lon=lon,
                    cases=1,
                    source="mobile",
                )
            except Exception as e:
                print("Alert creation error:", e)

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
        device_id  = payload.get("device_id")

        report = Report(
            source="mobile",
            image_url=payload.get("image_url"),
            lat=lat,
            lon=lon,
            device_id=device_id,
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
    include_resolved: bool = False,
    db: Session = Depends(get_db),
):
    
    query = (
        db.query(Detection)
        .join(Report, Detection.report_id == Report.id)
        .filter(Report.lat.isnot(None), Report.lon.isnot(None))
    )

    if not include_resolved:
        query = query.filter(Detection.is_resolved == False)

    detections = (
        query
        .order_by(Detection.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        {
            "id":          d.id,
            "disease":     d.disease_label,
            "confidence":  round(float(d.confidence or 0), 2),
            "severity":    d.severity,
            "lat":         float(d.report.lat),
            "lon":         float(d.report.lon),
            "timestamp":   d.created_at.isoformat(),
            "source":      d.report.source,
            "is_resolved": d.is_resolved,
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

    conf = float(detection.confidence or 0)
    # Handle both 0-1 and 0-100 scale data (older test records)
    if conf <= 1:
        conf = conf * 100

    return {
        "id":            detection.id,
        "disease":       detection.disease_label,
        "confidence":    round(conf, 2),
        "severity":      detection.severity,
        "model_version": detection.model_version,
        "timestamp":     detection.created_at.isoformat(),
        "image_url":     detection.report.image_url if detection.report else None,
        "lat":           float(detection.report.lat) if detection.report else None,
        "lon":           float(detection.report.lon) if detection.report else None,
        "source":        detection.report.source if detection.report else None,
        "remedy":        remedy,
        "is_resolved":   detection.is_resolved,
    }


@router.patch("/{detection_id}/resolve")
def resolve_detection(detection_id: int, db: Session = Depends(get_db)):
    
    detection = db.query(Detection).filter(Detection.id == detection_id).first()
    if not detection:
        raise HTTPException(status_code=404, detail="Detection not found")

    detection.is_resolved = True
    detection.resolved_at = datetime.utcnow()
    db.commit()

    return {"message": "resolved", "id": detection_id}


@router.patch("/{detection_id}/reopen")
def reopen_detection(detection_id: int, db: Session = Depends(get_db)):
    
    detection = db.query(Detection).filter(Detection.id == detection_id).first()
    if not detection:
        raise HTTPException(status_code=404, detail="Detection not found")

    detection.is_resolved = False
    detection.resolved_at = None
    db.commit()

    return {"message": "reopened", "id": detection_id}


@router.delete("/{report_id}")
def delete_detection(
    report_id: int,
    device_id: str = None,
    db: Session = Depends(get_db),
):
   
    try:
        report = db.query(Report).filter(Report.id == report_id).first()

        if not report:
            raise HTTPException(status_code=404, detail="Report not found")

        # Ownership check — only enforced if the report has a device_id
        if report.device_id is not None and report.device_id != device_id:
            raise HTTPException(
                status_code=403,
                detail="You can only delete detections from your own device.",
            )

        db.query(Detection).filter(Detection.report_id == report_id).delete()
        db.query(Report).filter(Report.id == report_id).delete()
        db.commit()
        return {"message": "deleted"}

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        return {"error": str(e)}