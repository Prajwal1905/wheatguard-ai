from sqlalchemy import Column, Integer, Float, DateTime
from sqlalchemy.sql import func
from app.db.database import Base

class NDVIHistory(Base):
    __tablename__ = "ndvi_history"

    id = Column(Integer, primary_key=True, index=True)
    lat = Column(Float, index=True)
    lon = Column(Float, index=True)
    ndvi = Column(Float)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
