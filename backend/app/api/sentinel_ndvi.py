import os
import io
import aiohttp
import asyncio
import tifffile
import datetime

from fastapi import APIRouter, HTTPException, Depends, Request
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.crud import save_ndvi
from app.utils.cache import cache_get, cache_set
from app.utils.rate_limiter import rate_limit

router = APIRouter(prefix="/api", tags=["Sentinel NDVI"])

# CDSE (Copernicus Data Space Ecosystem)

CLIENT_ID = os.getenv("SENTINEL_CLIENT_ID")
CLIENT_SECRET = os.getenv("SENTINEL_CLIENT_SECRET")

TOKEN_URL = (
    "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/"
    "protocol/openid-connect/token"
)

PROCESS_URL = "https://sh.dataspace.copernicus.eu/api/v1/process"

# How far back to search for a cloud-free scene
NDVI_LOOKBACK_DAYS = 30

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
    """
    Build a CDSE Process API request that:
    - searches the last NDVI_LOOKBACK_DAYS for imagery
    - picks the LEAST CLOUDY scene in that window (mosaickingOrder: leastCC)
    - masks out clouds/shadows/snow using the Scene Classification (SCL) band
      so cloudy pixels don't pollute the NDVI value
    """
    now = datetime.datetime.utcnow()
    start = (now - datetime.timedelta(days=NDVI_LOOKBACK_DAYS)).strftime("%Y-%m-%dT00:00:00Z")
    end = now.strftime("%Y-%m-%dT23:59:59Z")

    return {
        "input": {
            "bounds": {"bbox": bbox},
            "data": [
                {
                    "type": "sentinel-2-l2a",
                    "dataFilter": {
                        "timeRange": {"from": start, "to": end},
                        "mosaickingOrder": "leastCC",  # least cloud cover first
                        "maxCloudCoverage": 40,
                    },
                }
            ],
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
                    input: ["B04", "B08", "SCL"],
                    output: { bands: 1, sampleType: "FLOAT32" }
                };
            }

            // SCL classes considered "bad" — cloud, cloud shadow, snow/ice,
            // cloud probability (medium/high), cirrus, defective pixels.
            // See: https://sentinels.copernicus.eu/web/sentinel/technical-guides/sentinel-2-msi/level-2a/algorithm
            const BAD_SCL = [0, 1, 3, 8, 9, 10, 11];

            function evaluatePixel(p) {
                if (BAD_SCL.includes(p.SCL)) {
                    // Sentinel value for "no usable data" — caller treats this as null
                    return [-999];
                }
                let ndvi = (p.B08 - p.B04) / (p.B08 + p.B04);
                if (!isFinite(ndvi)) ndvi = -999;
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
            print("TOKEN EXPIRED — refreshing and retrying...")
            token = await get_token(force_new=True)
            resp = await call_ndvi_api(session, payload, token)

        if resp.status != 200:
            print("NDVI PROCESS ERROR:", await resp.text())
            return None

        data = await resp.read()
        arr = tifffile.imread(io.BytesIO(data))
        ndvi = float(arr[0][0])

        # -999 = cloud/cloud-shadow/no-data pixel (masked in evalscript)
        if ndvi <= -1:
            print(f"NDVI: pixel at ({lat_r},{lon_r}) is cloudy/no-data — skipping")
            return None

        ndvi = round(ndvi, 3)
        cache_set(key, ndvi)
        return ndvi

    return None


def classify_ndvi(ndvi: float) -> str:
    if ndvi >= 0.4:
        return "Healthy"
    if ndvi >= 0.2:
        return "Stressed"
    return "Critical"


@router.get("/sentinel_ndvi_value")
async def sentinel_ndvi_value(request: Request, lat: float, lon: float, db: Session = Depends(get_db)):
    
    rate_limit(request, max_requests=30, window_seconds=60)

    ndvi = await fetch_ndvi(lat, lon)

    if ndvi is None:
        raise HTTPException(
            404,
            f"No cloud-free Sentinel-2 imagery available for this location "
            f"in the last {NDVI_LOOKBACK_DAYS} days.",
        )

    save_ndvi(db, lat, lon, ndvi)

    return {
        "lat": lat,
        "lon": lon,
        "ndvi": ndvi,
        "status": classify_ndvi(ndvi),
    }


@router.post("/sentinel_ndvi_polygon")
async def sentinel_ndvi_polygon(request: Request, geojson: dict, db: Session = Depends(get_db)):
    
    rate_limit(request, max_requests=10, window_seconds=60)

    coords = geojson["geometry"]["coordinates"][0]

    tasks = [fetch_ndvi(lat=c[1], lon=c[0]) for c in coords]
    results = await asyncio.gather(*tasks)

    values = [v for v in results if v is not None]
    if not values:
        return {
            "average_ndvi": None,
            "status": "no data",
            "message": (
                f"No cloud-free Sentinel-2 imagery available for this field "
                f"in the last {NDVI_LOOKBACK_DAYS} days."
            ),
        }

    avg = round(sum(values) / len(values), 3)

    # First coordinate is [lon, lat] — save in correct (lat, lon) order
    first_lon, first_lat = coords[0][0], coords[0][1]
    save_ndvi(db, first_lat, first_lon, avg)

    return {
        "average_ndvi": avg,
        "status": classify_ndvi(avg),
        "points_sampled": len(coords),
        "points_with_data": len(values),
    }
