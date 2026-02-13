from sqlalchemy import Column, Integer, Float, String, DateTime, Boolean
from datetime import datetime
from app.db.database import Base

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True)
    disease = Column(String)
    severity = Column(String)
    cases = Column(Integer)
    lat = Column(Float)
    lon = Column(Float)
    source = Column(String)
    message = Column(String)
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    resolved_at = Column(DateTime, nullable=True)
