import os
import io
import aiohttp
import asyncio
import tifffile
import datetime

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.crud import save_ndvi
from app.utils.cache import cache_get, cache_set

router = APIRouter(prefix="/api", tags=["Sentinel NDVI"])

# CDSE (Copernicus Data Space Ecosystem)

CLIENT_ID = os.getenv("SENTINEL_CLIENT_ID")
CLIENT_SECRET = os.getenv("SENTINEL_CLIENT_SECRET")

TOKEN_URL = (
    "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/"
    "protocol/openid-connect/token"
)

PROCESS_URL = "https://sh.dataspace.copernicus.eu/api/v1/process"

_cached_token = None
_token_timestamp = None


async def get_token(force_new=False):
    """Return cached token or fetch new one"""
    global _cached_token, _token_timestamp

    if not force_new and _cached_token and _token_timestamp:
        age = (datetime.datetime.utcnow() - _token_timestamp).seconds
        if age < 3300:  # ~55 minutes
            return _cached_token

    async with aiohttp.ClientSession() as session:
        async with session.post(
            TOKEN_URL,
            data={
                "grant_type": "client_credentials",
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
            },
        ) as resp:

            if resp.status != 200:
                print("TOKEN ERROR:", await resp.text())
                raise HTTPException(500, "CDSE token fetch failed")

            data = await resp.json()
            _cached_token = data["access_token"]
            _token_timestamp = datetime.datetime.utcnow()
            return _cached_token


def payload_for_bbox(bbox):
    return {
        "input": {
            "bounds": {"bbox": bbox},
            "data": [{"type": "sentinel-2-l2a"}],
        },
        "output": {
            "width": 1,
            "height": 1,
            "responses": [
                {"identifier": "default", "format": {"type": "image/tiff"}}
            ],
        },
        "evalscript": """
            //VERSION=3
            function setup() {
                return {
                    input: ["B04", "B08"],
                    output: { bands: 1, sampleType: "FLOAT32" }
                };
            }
            function evaluatePixel(p) {
                let ndvi = (p.B08 - p.B04) / (p.B08 + p.B04);
                if (!isFinite(ndvi)) ndvi = -1;
                return [ndvi];
            }
        """,
    }


async def call_ndvi_api(session, payload, token):
    """Single call to CDSE API"""
    return await session.post(
        PROCESS_URL,
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )


async def fetch_ndvi(lat, lon):
    """Fetch NDVI with automatic token refresh on 401"""
    lat_r = round(lat, 4)
    lon_r = round(lon, 4)
    key = f"ndvi:{lat_r}:{lon_r}"

    
    cached = cache_get(key)
    if cached is not None:
        return cached

    delta = 0.0001
    bbox = [lon - delta, lat - delta, lon + delta, lat + delta]
    payload = payload_for_bbox(bbox)

    token = await get_token()
    async with aiohttp.ClientSession() as session:
        resp = await call_ndvi_api(session, payload, token)

        
        if resp.status == 401:
            print("🔁 TOKEN EXPIRED — refreshing and retrying...")
            token = await get_token(force_new=True)
            resp = await call_ndvi_api(session, payload, token)

        if resp.status != 200:
            print("NDVI PROCESS ERROR:", await resp.text())
            return None

        data = await resp.read()
        arr = tifffile.imread(io.BytesIO(data))
        ndvi = float(arr[0][0])

        if ndvi > -1:
            ndvi = round(ndvi, 3)
            cache_set(key, ndvi)
            return ndvi

    return None


# ---------------- ROUTES -----------------

@router.get("/sentinel_ndvi_value")
async def sentinel_ndvi_value(lat: float, lon: float, db: Session = Depends(get_db)):
    ndvi = await fetch_ndvi(lat, lon)

    if ndvi is None:
        raise HTTPException(404, "NDVI not available")

    save_ndvi(db, lat, lon, ndvi)

    return {
        "lat": lat,
        "lon": lon,
        "ndvi": ndvi,
        "status": (
            "Healthy" if ndvi >= 0.4 else
            "Stressed" if ndvi >= 0.2 else
            "Critical"
        ),
    }


@router.post("/sentinel_ndvi_polygon")
async def sentinel_ndvi_polygon(geojson: dict, db: Session = Depends(get_db)):
    coords = geojson["geometry"]["coordinates"][0]

    tasks = [fetch_ndvi(lat, lon) for lat, lon in coords]
    results = await asyncio.gather(*tasks)

    values = [v for v in results if v is not None]
    if not values:
        return {"average_ndvi": None, "status": "no data"}

    avg = round(sum(values) / len(values), 3)

    first_lat, first_lon = coords[0]
    save_ndvi(db, first_lat, first_lon, avg)

    return {
        "average_ndvi": avg,
        "status": (
            "Healthy" if avg >= 0.4 else
            "Stressed" if avg >= 0.2 else
            "Critical"
        ),
    }
