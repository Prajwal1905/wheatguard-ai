import os
import requests
import math

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY")

def send_fcm(token: str, title: str, body: str, data=None):
    headers = {
        "Authorization": f"key={FCM_SERVER_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "to": token,
        "notification": {"title": title, "body": body, "sound": "default"},
        "data": data or {}
    }

    requests.post(
        "https://fcm.googleapis.com/fcm/send",
        headers=headers,
        json=payload,
    )

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (
        math.sin(dlat / 2) ** 2 +
        math.cos(math.radians(lat1)) *
        math.cos(math.radians(lat2)) *
        math.sin(dlon / 2) ** 2
    )

    return 2 * R * math.asin(math.sqrt(a))
