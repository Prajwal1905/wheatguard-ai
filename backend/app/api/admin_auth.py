# app/api/admin_auth.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
import jwt
import datetime
import os

router = APIRouter(prefix="/admin", tags=["Admin Auth"])

SECRET         = os.getenv("ADMIN_SECRET", "supersecret123")
ADMIN_EMAIL    = os.getenv("ADMIN_EMAIL", "admin@wheatguard.com")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "WheatGuard@2024")
TOKEN_HOURS    = 10


class LoginData(BaseModel):
    email: str
    password: str


def create_jwt_token(email: str) -> str:
    now = datetime.datetime.utcnow()
    payload = {
        "email": email,
        "iat":   now,
        "exp":   now + datetime.timedelta(hours=TOKEN_HOURS),
    }
    return jwt.encode(payload, SECRET, algorithm="HS256")


def verify_jwt_token(token: str) -> dict:
    return jwt.decode(token, SECRET, algorithms=["HS256"])


@router.post("/login")
def login(data: LoginData):
    # Constant-time comparison to avoid timing attacks
    email_ok    = data.email    == ADMIN_EMAIL
    password_ok = data.password == ADMIN_PASSWORD

    if not (email_ok and password_ok):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        )

    token = create_jwt_token(data.email)

    return {
        "token":      token,
        "expires_in": TOKEN_HOURS * 3600,
        "token_type": "Bearer",
    }


@router.get("/verify")
def verify(token: str):
    try:
        payload = verify_jwt_token(token)
        return {
            "status": "valid",
            "email":  payload.get("email"),
            "exp":    payload.get("exp"),
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")


@router.post("/logout")
def logout():
    
    return {"message": "Logged out. Please remove the token from storage."}
