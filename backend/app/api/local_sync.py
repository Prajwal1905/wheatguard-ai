# app/api/local_sync.py

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, validator
from typing import Optional
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


class LocalDetectionPayload(BaseModel):
    lat:           float
    lon:           float
    image_url:     Optional[str]  = None
    disease:       Optional[str]  = None
    confidence:    Optional[float] = Field(None, ge=0, le=100)
    severity:      Optional[str]  = None
    model_version: Optional[str]  = None

    @validator("lat")
    def validate_lat(cls, v):
        if not (-90 <= v <= 90):
            raise ValueError("Latitude must be between -90 and 90")
        return round(v, 6)

    @validator("lon")
    def validate_lon(cls, v):
        if not (-180 <= v <= 180):
            raise ValueError("Longitude must be between -180 and 180")
        return round(v, 6)

    @validator("severity")
    def validate_severity(cls, v):
        allowed = {"High", "Moderate", "Low", "Medium", None}
        if v not in allowed:
            raise ValueError(f"Severity must be one of {allowed}")
        return v

    @validator("confidence")
    def validate_confidence(cls, v):
        if v is not None:
            return round(float(v), 2)
        return v


@router.post("/local-detection")
def sync_local_detection(
    data: LocalDetectionPayload,
    db: Session = Depends(get_db),
):
    
    report = models.Report(
        source="local-mobile",
        lat=data.lat,
        lon=data.lon,
        image_url=data.image_url,
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    
    disease    = data.disease    or "pending"
    confidence = data.confidence or 0.0
    status     = "pending-ai" if disease == "pending" else "complete"

    detection = models.Detection(
        report_id=report.id,
        disease_label=disease,
        confidence=confidence,
        bbox=None,
        severity=data.severity or "Low",
        model_version=data.model_version or "offline-upload",
    )

    db.add(detection)
    db.commit()

    return {
        "message": "Local detection synced",
        "id":      detection.id,
        "status":  status,
    }
