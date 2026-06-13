# app/utils/image_validation.py

import io
from PIL import Image, UnidentifiedImageError
from fastapi import HTTPException

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024

ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}


def validate_image_bytes(image_bytes: bytes) -> None:
    
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file")

    if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail=f"Image too large — max {MAX_IMAGE_SIZE_BYTES // (1024*1024)}MB",
        )

    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.verify()  # checks the file is not truncated/corrupted

        
        img2 = Image.open(io.BytesIO(image_bytes))
        fmt = img2.format

        if fmt not in ALLOWED_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported image format: {fmt}. Allowed: JPEG, PNG, WEBP",
            )

    except UnidentifiedImageError:
        raise HTTPException(
            status_code=400,
            detail="File is not a valid image",
        )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="File is not a valid or readable image",
        )