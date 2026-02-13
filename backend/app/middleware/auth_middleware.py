# app/middleware/auth_middleware.py

from fastapi import Request
from fastapi.responses import JSONResponse   
import jwt, os

SECRET = os.getenv("ADMIN_SECRET", "supersecret123")

async def verify_token(request: Request):
    """
    Middleware token checker.
    Works for all protected routes.
    """

    auth_header = request.headers.get("Authorization")

    if not auth_header:
        return JSONResponse(
            status_code=401,
            content={"detail": "Missing Authorization header"}
        )

    if not auth_header.startswith("Bearer "):
        return JSONResponse(
            status_code=401,
            content={"detail": "Invalid token format"}
        )

    token = auth_header.split(" ")[1]

    try:
        jwt.decode(token, SECRET, algorithms=["HS256"])
        return True
    except jwt.ExpiredSignatureError:
        return JSONResponse(
            status_code=401,
            content={"detail": "Token expired"}
        )
    except Exception as e:
        return JSONResponse(
            status_code=401,
            content={"detail": f"Invalid token: {str(e)}"}
        )
