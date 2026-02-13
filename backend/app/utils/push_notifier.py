from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.fcm_token import FCMToken
from app.utils.fcm_sender import send_fcm, haversine


def send_alert_push(alert):
    db: Session = SessionLocal()

    farmers = db.query(FCMToken).all()

    for f in farmers:
        # If farmer has no location saved
        if f.lat is None or f.lon is None:
            continue

        dist = haversine(alert.lat, alert.lon, f.lat, f.lon)

        if dist <= 5:
            send_fcm(
                token=f.token,
                title=f"🚨 {alert.disease} Alert Nearby!",
                body=f"{alert.severity} outbreak detected {dist:.1f} km from your location.",
                data={
                    "lat": str(alert.lat),
                    "lon": str(alert.lon),
                    "disease": alert.disease
                }
            )

    db.close()
