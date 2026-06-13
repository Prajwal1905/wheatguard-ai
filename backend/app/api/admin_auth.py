# app/api/admin_auth.py

import os
import secrets
import datetime

import bcrypt
import jwt
from fastapi import APIRouter, HTTPException, Header

router = APIRouter(prefix="/admin", tags=["Admin Auth"])


SECRET = os.getenv("ADMIN_SECRET")
if not SECRET:
    raise RuntimeError(
        "ADMIN_SECRET environment variable is not set. "
        "Refusing to start with a default JWT signing secret."
    )

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL")
if not ADMIN_EMAIL:
    raise RuntimeError("ADMIN_EMAIL environment variable is not set.")

ADMIN_PASSWORD_HASH = os.getenv("ADMIN_PASSWORD_HASH")
if not ADMIN_PASSWORD_HASH:
    raise RuntimeError(
        "ADMIN_PASSWORD_HASH environment variable is not set. "
        "Generate one with bcrypt — see comment above this check."
    )

TOKEN_HOURS = 10


from pydantic import BaseModel


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
    
    email_ok = secrets.compare_digest(data.email, ADMIN_EMAIL)

    password_ok = bcrypt.checkpw(
        data.password.encode("utf-8"),
        ADMIN_PASSWORD_HASH.encode("utf-8"),
    )

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
def verify(authorization: str = Header(None)):
    """
    Verify a token passed via the Authorization header
    (e.g. "Bearer <token>") — NOT a query parameter, since query
    parameters can end up in server access logs and browser history.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()

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