from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime
from sqlalchemy.orm import relationship
from app.db.database import Base

class Detection(Base):
    __tablename__ = "detections"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, ForeignKey("reports.id", ondelete="CASCADE"))
    disease_label = Column(String(80))
    confidence = Column(Float)
    bbox = Column(JSONB, nullable=True)
    severity = Column(String(30))
    model_version = Column(String(40))
    created_at = Column(DateTime, default=datetime.utcnow)

    report = relationship("Report", back_populates="detections")
