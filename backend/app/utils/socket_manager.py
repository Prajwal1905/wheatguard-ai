from typing import Optional
import socketio

# Global Socket.IO server instance (created in main.py)
sio: Optional[socketio.AsyncServer] = None


# -------------------------------------------------
# 🔴 REALTIME DISEASE DETECTIONS (Mobile / Drone)
# -------------------------------------------------
async def broadcast_new_detection(data):
    """
    Emits a new_detection event to all connected clients.
    Safe to import anywhere (no circular imports).
    """
    if sio:
        print("📡 Broadcasting NEW DETECTION:", data)
        await sio.emit("new_detection", data)
    else:
        print("⚠️ SocketIO not initialized yet (detection).")


# -------------------------------------------------
# 🟠 REALTIME MANUAL ALERTS (Admin / Drone / System)
# -------------------------------------------------
async def broadcast_new_alert(data):
    """
    Emits a new_alert event for farmer apps.
    Includes source: admin | drone | mobile
    """
    if sio:
        print("📡 Broadcasting NEW ALERT:", data)
        await sio.emit("new_alert", data)
    else:
        print("⚠️ SocketIO not initialized yet (alerts).")

async def broadcast_ndvi_stress_updates(alerts):
    """
    Emits updated NDVI stress alerts to all clients.
    The frontend listens to 'ndvi_stress_update'.
    """
    if sio:
        print("📡 Broadcasting NDVI STRESS UPDATE:", len(alerts))
        await sio.emit("ndvi_stress_update", alerts)
    else:
        print("⚠️ SocketIO not initialized yet (NDVI).")
