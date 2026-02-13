from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel

class ReportBase(BaseModel):
    field_id: Optional[int] = None
    source: str
    image_url: Optional[str] = None
    captured_at: Optional[datetime] = None
    lat: Optional[float] = None
    lon: Optional[float] = None

class ReportCreate(ReportBase):
    pass

class ReportResponse(ReportBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True



class DetectionBase(BaseModel):
    report_id: int
    disease_label: str
    confidence: float
    bbox: Optional[dict] = None
    severity: Optional[str] = None
    model_version: Optional[str] = None

class DetectionCreate(DetectionBase):
    pass

class DetectionResponse(DetectionBase):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True


class AlertBase(BaseModel):
    disease: str
    severity: str               
    cases: int                  
    lat: float
    lon: float
    message: Optional[str] = None
    source: str = "admin"       

class AlertCreate(AlertBase):
    pass

class AlertResponse(AlertBase):
    id: int
    created_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None

    class Config:
        orm_mode = True

class FCMTokenBase(BaseModel):
    device_id: str
    token: str
    lat: Optional[float] = None
    lon: Optional[float] = None

class FCMTokenResponse(FCMTokenBase):
    id: int
    class Config:
        orm_mode = True

class FieldBase(BaseModel):
    farmer_id: int
    village: str
    phone: str
    crop: str
    polygon: dict
    photo_url: Optional[str] = None
    geo_lat: float
    geo_lon: float


class FieldCreate(FieldBase):
    pass


class FieldResponse(FieldBase):
    id: int
    created_at: Optional[datetime] = None

    class Config:
        orm_mode = True