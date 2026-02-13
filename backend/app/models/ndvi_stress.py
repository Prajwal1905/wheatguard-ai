# app/models/ndvi_stress.py
from sqlalchemy import Column, Integer, Float, DateTime, String, Boolean
from sqlalchemy.sql import func
from app.db.database import Base

class NDVIStressAlert(Base):
    __tablename__ = "ndvi_stress_alerts"

    id = Column(Integer, primary_key=True, index=True)

    lat = Column(Float, index=True)
    lon = Column(Float, index=True)

    baseline_ndvi = Column(Float)   
    current_ndvi = Column(Float)    
    drop = Column(Float)            

    severity = Column(String(20), index=True)

    resolved = Column(Boolean, default=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now()
    )
