# app/routes/fields.py

from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from fastapi.responses import FileResponse
import os, uuid, json
from app.models.fields import Field


from app.db.database import SessionLocal
from app import crud

router = APIRouter(prefix="/fields", tags=["Fields"])

FARMER_FOLDER = "uploads/farmers"
FIELD_FOLDER = "uploads/fields"

os.makedirs(FARMER_FOLDER, exist_ok=True)
os.makedirs(FIELD_FOLDER, exist_ok=True)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/")
async def register_field(
    farmer_id: int = Form(...),
    village: str = Form(...),
    phone: str = Form(...),
    crop: str = Form(...),
    polygon: str = Form(...),
    geo_lat: float = Form(...),
    geo_lon: float = Form(...),

    farmer_photo: UploadFile = File(...),
    field_photo: UploadFile = File(...),

    db: Session = Depends(get_db),
):

    ext1 = farmer_photo.filename.split(".")[-1]
    fname1 = f"{uuid.uuid4()}.{ext1}"
    farmer_path = os.path.join(FARMER_FOLDER, fname1)
    with open(farmer_path, "wb") as f:
        f.write(await farmer_photo.read())
    farmer_url = f"/fields/photo/farmer/{fname1}"

    ext2 = field_photo.filename.split(".")[-1]
    fname2 = f"{uuid.uuid4()}.{ext2}"
    field_path = os.path.join(FIELD_FOLDER, fname2)
    with open(field_path, "wb") as f:
        f.write(await field_photo.read())
    field_url = f"/fields/photo/field/{fname2}"

    data = {
        "farmer_id": farmer_id,
        "village": village,
        "phone": phone,
        "crop": crop,
        "polygon": json.loads(polygon),
        "photo_url": farmer_url,
        "field_photo_url": field_url,
        "geo_lat": geo_lat,
        "geo_lon": geo_lon,
    }

    return crud.create_field(db, data)

@router.put("/{field_id}")
async def update_field(
    field_id: int,

    farmer_id: int = Form(...),
    village: str = Form(...),
    phone: str = Form(...),
    crop: str = Form(...),
    polygon: str = Form(...),
    geo_lat: float = Form(...),
    geo_lon: float = Form(...),

    farmer_photo: UploadFile = File(None),
    field_photo: UploadFile = File(None),

    db: Session = Depends(get_db),
):
    updates = {
        "farmer_id": farmer_id,
        "village": village,
        "phone": phone,
        "crop": crop,
        "polygon": json.loads(polygon),
        "geo_lat": geo_lat,
        "geo_lon": geo_lon,
    }

    
    if farmer_photo:
        ext = farmer_photo.filename.split(".")[-1]
        fname = f"{uuid.uuid4()}.{ext}"
        path = os.path.join(FARMER_FOLDER, fname)
        with open(path, "wb") as f:
            f.write(await farmer_photo.read())
        updates["photo_url"] = f"/fields/photo/farmer/{fname}"

    if field_photo:
        ext = field_photo.filename.split(".")[-1]
        fname = f"{uuid.uuid4()}.{ext}"
        path = os.path.join(FIELD_FOLDER, fname)
        with open(path, "wb") as f:
            f.write(await field_photo.read())
        updates["field_photo_url"] = f"/fields/photo/field/{fname}"

    updated = crud.update_field(db, field_id, updates)

    if not updated:
        raise HTTPException(status_code=404, detail="Field not found")

    return {"message": "Field updated", "field": updated}


@router.get("/photo/farmer/{filename}")
def serve_farmer_photo(filename: str):
    return FileResponse(os.path.join(FARMER_FOLDER, filename))

@router.get("/photo/field/{filename}")
def serve_field_photo(filename: str):
    return FileResponse(os.path.join(FIELD_FOLDER, filename))

@router.get("/")
def list_fields(db: Session = Depends(get_db)):
    return crud.get_all_fields(db)

@router.delete("/{field_id}")
def delete_field(field_id: int, db: Session = Depends(get_db)):
    field = db.query(Field).filter(Field.id == field_id).first()

    if not field:
        return {"error": "Field not found"}

    
    db.delete(field)
    db.commit()

    return {"message": "Field deleted successfully"}