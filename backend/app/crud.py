# crud.py
from sqlalchemy.orm import Session
from sqlalchemy import func

# Models
from app.models.report import Report
from app.models.detection import Detection
from app.models.alert import Alert
from app.models.fcm_device import FCMDevice
from app.models.ndvi_history import NDVIHistory
from app.models.ndvi_stress import NDVIStressAlert
from app.models.fields import Field   # <-- IMPORTANT


def create_report(db: Session, data):
    report = Report(**data)
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


def create_detection(db: Session, data):
    detection = Detection(**data)
    db.add(detection)
    db.commit()
    db.refresh(detection)
    return detection

def get_detections(db: Session):
    return db.query(Detection).all()


def create_alert(db: Session, data):
    alert = Alert(**data)
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert

def get_alerts(db: Session):
    return db.query(Alert).order_by(Alert.created_at.desc()).all()


# ---------------------------------------------------------
# FCM DEVICE TOKENS
# ---------------------------------------------------------
def save_fcm_token(db: Session, data):
    existing = db.query(FCMDevice).filter(
        FCMDevice.device_id == data.device_id
    ).first()

    if existing:
        existing.token = data.token
        existing.lat = data.lat
        existing.lon = data.lon
        db.commit()
        db.refresh(existing)
        return existing

    new = FCMDevice(
        device_id=data.device_id,
        token=data.token,
        lat=data.lat,
        lon=data.lon
    )

    db.add(new)
    db.commit()
    db.refresh(new)
    return new

def get_all_fcm_tokens(db: Session):
    return db.query(FCMDevice).all()


def save_ndvi(db: Session, lat: float, lon: float, ndvi: float):
    entry = NDVIHistory(
        lat=round(lat, 4),
        lon=round(lon, 4),
        ndvi=ndvi
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry

def get_ndvi_history(db: Session, lat: float, lon: float):
    return (
        db.query(NDVIHistory)
        .filter(
            NDVIHistory.lat == lat,
            NDVIHistory.lon == lon
        )
        .order_by(NDVIHistory.timestamp.asc())
        .all()
    )

def clear_ndvi_stress_alerts(db: Session):
    db.query(NDVIStressAlert).delete()
    db.commit()

def create_ndvi_stress_alert(
    db: Session,
    lat: float,
    lon: float,
    baseline: float,
    current: float,
    drop: float,
    severity: str,
):
    alert = NDVIStressAlert(
        lat=lat,
        lon=lon,
        baseline_ndvi=baseline,
        current_ndvi=current,
        drop=drop,
        severity=severity,
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert

def get_active_ndvi_stress_alerts(db: Session):
    return (
        db.query(NDVIStressAlert)
        .filter(NDVIStressAlert.resolved == False)
        .order_by(NDVIStressAlert.created_at.desc())
        .all()
    )


def create_field(db: Session, field_data):
    db_field = Field(
        farmer_id=field_data["farmer_id"],
        village=field_data["village"],
        phone=field_data["phone"],
        crop=field_data["crop"],
        polygon=field_data["polygon"],
        photo_url=field_data.get("photo_url"),          # farmer photo
        field_photo_url=field_data.get("field_photo_url"),  # field photo
        geo_lat=field_data["geo_lat"],
        geo_lon=field_data["geo_lon"],
    )

    db.add(db_field)
    db.commit()
    db.refresh(db_field)
    return db_field


def get_all_fields(db: Session):
    return db.query(Field).order_by(Field.created_at.desc()).all()


def get_fields_by_farmer(db: Session, farmer_id: int):
    return db.query(Field).filter(Field.farmer_id == farmer_id).all()


def update_field(db, field_id: int, updates: dict):
    field = db.query(Field).filter(Field.id == field_id).first()
    if not field:
        return None

    for key, value in updates.items():
        setattr(field, key, value)

    db.commit()
    db.refresh(field)
    return field
