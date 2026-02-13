from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import jwt, datetime, os

router = APIRouter(prefix="/admin", tags=["Admin Auth"])

SECRET = os.getenv("ADMIN_SECRET", "supersecret123")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@gmail.com")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")

class LoginData(BaseModel):
    email: str
    password: str

def create_jwt_token(email: str):
    payload = {
        "email": email,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=10),
        "iat": datetime.datetime.utcnow()
    }
    return jwt.encode(payload, SECRET, algorithm="HS256")

def verify_jwt_token(token: str):
    return jwt.decode(token, SECRET, algorithms=["HS256"])

@router.post("/login")
def login(data: LoginData):
    if data.email != ADMIN_EMAIL or data.password != ADMIN_PASSWORD:
        raise HTTPException(401, "Invalid email or password")

    token = create_jwt_token(data.email)
    return {"token": token}

@router.get("/verify")
def verify(token: str):
    try:
        verify_jwt_token(token)
        return {"status": "valid"}
    except:
        raise HTTPException(401, "Invalid or expired token")

@router.post("/logout")
def logout():
    return {"message": "Logged out"}
