from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app import models

router = APIRouter(prefix="/sync", tags=["Local Sync"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/local-detection")
def sync_local_detection(data: dict, db: Session = Depends(get_db)):
    """
    Save offline mobile capture.
    If AI prediction not available → mark as pending.
    """

    # 1️⃣ Create report
    report = models.Report(
        source="local-mobile",
        lat=data.get("lat"),
        lon=data.get("lon"),
        image_url=data.get("image_url")
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    # 2️⃣ Handle missing AI prediction
    disease = data.get("disease")
    confidence = data.get("confidence")

    if disease is None or confidence is None:
        disease = "pending"
        confidence = 0.0

    # 3️⃣ Create detection safely
    detection = models.Detection(
        report_id=report.id,
        disease_label=disease,
        confidence=confidence,
        bbox=None,
        severity=data.get("severity", "Medium"),
        model_version="offline-upload"
    )

    db.add(detection)
    db.commit()

    return {
        "message": "Local detection synced",
        "id": detection.id,
        "status": "pending-ai" if disease == "pending" else "complete"
    }
