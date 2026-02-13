from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Optional
from app.db.database import SessionLocal
from app.models.fcm_device import FCMDevice
from app.utils.fcm_sender import send_fcm

router = APIRouter(prefix="/fcm", tags=["FCM"])

class FCMRegister(BaseModel):
    device_id: str
    token: str
    lat: Optional[float] = None
    lon: Optional[float] = None

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/register")
def register_fcm_token(payload: FCMRegister, db: Session = Depends(get_db)):
    existing = db.query(FCMDevice).filter_by(device_id=payload.device_id).first()

    if existing:
        existing.token = payload.token
        existing.lat = payload.lat
        existing.lon = payload.lon
    else:
        new_entry = FCMDevice(
            device_id=payload.device_id,
            token=payload.token,
            lat=payload.lat,
            lon=payload.lon
        )
        db.add(new_entry)

    db.commit()

    return {"message": "Token saved"}

@router.post("/send-test")
def send_test_notification(db: Session = Depends(get_db)):
    
    device = db.query(FCMDevice).order_by(FCMDevice.id.desc()).first()

    if not device:
        return {"error": "No device registered"}

    send_fcm(
        token=device.token,
        title="WheatGuard Test Alert 🌾",
        body="Your FCM push notification is working!",
        data={"test": "ok"}
    )

    return {
        "message": "Test notification sent",
        "device_id": device.device_id,
        "token": device.token
    }