# app/models/fields.py

from sqlalchemy import Column, Integer, String, Float, JSON, TIMESTAMP
from sqlalchemy.sql import func
from app.db.database import Base

class Field(Base):
    __tablename__ = "fields"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, nullable=False)

    village = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    crop = Column(String, nullable=False)

    polygon = Column(JSON, nullable=False)

    photo_url = Column(String, nullable=True)         
    field_photo_url = Column(String, nullable=True)   

    geo_lat = Column(Float, nullable=False)
    geo_lon = Column(Float, nullable=False)

    created_at = Column(TIMESTAMP, server_default=func.now())
