# app/routes/upload.py
from fastapi import APIRouter, UploadFile, File, HTTPException
import uuid

from app.utils.supabase_upload import upload_detection_image

router = APIRouter(prefix="/upload", tags=["Uploads"])


@router.post("/image")
async def upload_image(file: UploadFile = File(...)):
    
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file")

    ext = (file.filename or "jpg").split(".")[-1].lower()
    filename = f"{uuid.uuid4()}.{ext}"

    url = upload_detection_image(file_bytes, filename)
    if not url:
        raise HTTPException(status_code=500, detail="Failed to upload to Supabase")

    return {"url": url}
