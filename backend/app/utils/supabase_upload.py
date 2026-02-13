from typing import Optional
import os
from supabase import create_client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
BUCKET = os.getenv("SUPABASE_BUCKET", "detections")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def upload_detection_image(file_bytes: bytes, filename: str) -> Optional[str]:
    """
    Uploads file to Supabase Storage and returns public URL.
    """
    try:
        path = filename

        supabase.storage.from_(BUCKET).upload(
            path,
            file_bytes,
            file_options={
                "content-type": "image/jpeg",
                "upsert": "true",
            },
        )

        public_url = supabase.storage.from_(BUCKET).get_public_url(path)
        return public_url

    except Exception as e:
        print("❌ Supabase Upload Error:", e)
        return None
