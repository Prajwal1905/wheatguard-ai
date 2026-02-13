# app/main.py
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import socketio
import uvicorn
from app.db.database import init_db
from dotenv import load_dotenv
load_dotenv()

sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins=["*"],
)

fastapi_app = FastAPI(
    title=" WheatGuard AI Backend ",
    version="3.0"
)

app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app)

fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)

from app.api import (
    detections,
    map_data,
    admin_auth,
    drone


)
from app.api import nasa_ndvi
from app.api import sentinel_ndvi
from app.api.ai_explain import router as ai_router
from app.api import local_sync
from app.middleware.auth_middleware import verify_token
from app.utils import socket_manager
from app.ml.model_utils import load_model
from app.api import upload
from app.api import alerts
from app.api import fcm_tokens
from app.api import ndvi_history
from app import ndvi_stress
from app.scheduler import start_scheduler
from app.api import fields


fastapi_app.include_router(admin_auth.router)
fastapi_app.include_router(nasa_ndvi.router)
fastapi_app.include_router(sentinel_ndvi.router)
fastapi_app.include_router(ai_router)
fastapi_app.include_router(local_sync.router)
fastapi_app.include_router(upload.router)
fastapi_app.include_router(alerts.router)
fastapi_app.include_router(drone.router)
fastapi_app.include_router(fcm_tokens.router)
fastapi_app.include_router(ndvi_history.router)
fastapi_app.include_router(ndvi_stress.router)
fastapi_app.include_router(fields.router)


from fastapi.staticfiles import StaticFiles
fastapi_app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

UNPROTECTED_PATHS = [
    "/admin/login",

    "/detections/predict",
    "/detections/save",

    "/alerts",
    "/alerts/nearby",

    "/api/nasa_ndvi_tile",
    "/api/nasa_ndvi_value",
    "/api/nasa_ndvi_polygon",

    "/ai/remedy",
    "/ai/explain",
    "/ai/chat",
    "/detections/",
    "/drone/analyze",
    "/drone",

    "/map/data",
    "/map/nearby",

    "/upload/image",
    "/uploads",
    "/sync/local-detection",
    "/detections/map_data",

    "/api/sentinel_ndvi_tile",
    "/api/sentinel_ndvi_value",

    "/api/ndvi_tile",
    "/api/ndvi_value",
    "/api/planet_ndvi",
    "/api/planet_ndvi_tile",

    "/fcm/register",
    "/fcm/send-test",
    "/api/ndvi_history",

    "/api/ndvi/stress",
    "/api/ndvi/stress/",
    "/api/ndvi/stress/scan",
    "/api/ndvi/stress/scan/",

    "/fields",
    "/fields/",
    "/fields/photo",
    "/fields/photo/",

    "/",
    "/docs",
    "/openapi.json",
    "/redoc",

]



@fastapi_app.middleware("http")
async def auth_middleware(request: Request, call_next):
    path = request.url.path

    
    if request.method == "OPTIONS":
        return await call_next(request)

    
    if any(path.startswith(p) for p in UNPROTECTED_PATHS):
        return await call_next(request)

    token_ok = await verify_token(request)
    if token_ok is not True:
        return token_ok

    return await call_next(request)

fastapi_app.include_router(detections.router)
fastapi_app.include_router(map_data.router)

socket_manager.sio = sio

@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")

@sio.event
async def disconnect(sid):
    print(f" Client disconnected: {sid}")

@fastapi_app.get("/")
def root():
    return {"message": "WheatGuard Backend Running ✔"}

@fastapi_app.on_event("startup")
async def startup_event():
    print("Starting WheatGuard AI Backend...")
    init_db() 
    load_model()
    start_scheduler()  
    print(" Model loaded & Scheduler running")

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
 