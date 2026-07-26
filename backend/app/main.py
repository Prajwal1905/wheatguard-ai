# app/main.py

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from collections import defaultdict
import socketio
import uvicorn
import time
from app.db.database import init_db
from dotenv import load_dotenv
load_dotenv()
ALLOWED_ORIGINS = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost",
    "http://localhost:80",
    "http://127.0.0.1",
    "http://127.0.0.1:80",
    "https://wheatguard-ai.vercel.app",
    "https://wheatguard-ai-git-main-prajwal1905s-projects.vercel.app",
]

sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins=ALLOWED_ORIGINS,
)

fastapi_app = FastAPI(
    title="WheatGuard AI Backend",
    version="3.0",
)

app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app)


fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)

from app.api import (
    detections,
    map_data,
    admin_auth,
    drone,
    alerts,
    upload,
    fcm_tokens,
    ndvi_history,
    fields,
    local_sync,
    stats,
)
from app.api import nasa_ndvi
from app.api import sentinel_ndvi
from app.api.ai_explain import router as ai_router
from app.middleware.auth_middleware import verify_token
from app.utils import socket_manager
from app.ml.model_utils import load_model
from app import ndvi_stress
from app.scheduler import start_scheduler

fastapi_app.include_router(admin_auth.router)
fastapi_app.include_router(detections.router)
fastapi_app.include_router(map_data.router)
fastapi_app.include_router(nasa_ndvi.router)
fastapi_app.include_router(sentinel_ndvi.router)
fastapi_app.include_router(ai_router)
fastapi_app.include_router(local_sync.router)
fastapi_app.include_router(stats.router)
fastapi_app.include_router(upload.router)
fastapi_app.include_router(alerts.router)
fastapi_app.include_router(drone.router)
fastapi_app.include_router(fcm_tokens.router)
fastapi_app.include_router(ndvi_history.router)
fastapi_app.include_router(ndvi_stress.router)
fastapi_app.include_router(fields.router)

from fastapi.staticfiles import StaticFiles
fastapi_app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

OPEN_EXACT = {
    "/",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/admin/login",
}

OPEN_PREFIXES = (
   
    "/detections/predict",
    "/detections/save",
    "/detections/map_data", 
    "/sync/local-detection",

    "/ai/remedy",
    "/ai/explain",
    "/ai/chat",

    "/alerts/nearby",

    "/api/sentinel_ndvi_value",
    "/api/sentinel_ndvi_tile",
    "/api/nasa_ndvi_tile",
    "/api/nasa_ndvi_value",
    "/api/nasa_ndvi_polygon",
    "/api/ndvi_history",

    "/upload/image",

    "/fcm/register",

    "/uploads",

    "/fields/photo",
    "/fields/", 
)

_login_attempts: dict = defaultdict(list)
LOGIN_MAX_ATTEMPTS = 10
LOGIN_WINDOW_SECONDS = 60


def is_rate_limited(ip: str) -> bool:
    now = time.time()
    attempts = _login_attempts[ip]
    # Remove attempts older than the window
    _login_attempts[ip] = [t for t in attempts if now - t < LOGIN_WINDOW_SECONDS]
    if len(_login_attempts[ip]) >= LOGIN_MAX_ATTEMPTS:
        return True
    _login_attempts[ip].append(now)
    return False


@fastapi_app.middleware("http")
async def auth_middleware(request: Request, call_next):
    path   = request.url.path
    method = request.method

    # Always allow preflight
    if method == "OPTIONS":
        return await call_next(request)

    # Rate-limit login attempts
    if path == "/admin/login" and method == "POST":
        client_ip = request.client.host if request.client else "unknown"
        if is_rate_limited(client_ip):
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many login attempts. Try again in 1 minute."},
            )
        return await call_next(request)
    
    if method == "DELETE" and path.startswith("/detections/"):
        return await call_next(request)


    # Exact open paths
    if path in OPEN_EXACT:
        return await call_next(request)

    # Prefix open paths
    if any(path.startswith(prefix) for prefix in OPEN_PREFIXES):
        return await call_next(request)

    # Everything else requires a valid JWT
    token_ok = await verify_token(request)
    if token_ok is not True:
        return token_ok

    return await call_next(request)


socket_manager.sio = sio

@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")

@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")

@fastapi_app.get("/")
def root():
    return {"message": "WheatGuard Backend Running"}

@fastapi_app.on_event("startup")
async def startup_event():
    print("Starting WheatGuard AI Backend...")
    init_db()
    load_model()
    start_scheduler()
    print("Model loaded and scheduler running")


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
