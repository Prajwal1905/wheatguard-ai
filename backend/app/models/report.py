from sqlalchemy import Column, Integer, Float, String, DateTime, Text
from datetime import datetime
from sqlalchemy.orm import relationship
from app.db.database import Base

class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    source = Column(String(30), nullable=False)
    image_url = Column(Text, nullable=True)
    captured_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    lat = Column(Float)
    lon = Column(Float)

    detections = relationship("Detection", back_populates="report", cascade="all, delete-orphan")
