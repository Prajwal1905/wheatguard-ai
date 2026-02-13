from fastapi import APIRouter, Response
from fastapi.responses import JSONResponse
import requests
import datetime

router = APIRouter(prefix="/api", tags=["NASA NDVI"])

def nearest_modis_date(date_str):
    date = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    day = date.timetuple().tm_yday

    modis_day = ((day - 1) // 16) * 16 + 1
    modis_date = datetime.datetime(date.year, 1, 1) + datetime.timedelta(days=modis_day - 1)

    return modis_date.strftime("%Y-%m-%d")

@router.get("/nasa_ndvi_tile")
def nasa_ndvi_tile(z: int, x: int, y: int, date: str):

    date = nearest_modis_date(date)

    url = (
        "https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/"
        f"VIIRS_SNPP_NDVI/default/{date}/GoogleMapsCompatible/{z}/{y}/{x}.png"
    )

    r = requests.get(url)

    if r.status_code == 200:
        return Response(r.content, media_type="image/png")

    return JSONResponse(
        {
            "error": "NDVI tile failed",
            "url": url,
            "date_used": date,
            "status": r.status_code,
        },
        status_code=400,
    )

@router.get("/nasa_ndvi_value")
def nasa_ndvi_value(lat: float, lon: float, date: str):

    date = nearest_modis_date(date)

    url = (
        "https://modis.ornl.gov/rst/api/v1/MOD13Q1"
        f"?latitude={lat}&longitude={lon}&date={date}"
    )

    r = requests.get(url)
    if r.status_code != 200:
        return JSONResponse({"ndvi": None, "status": "no data"}, status_code=400)

    data = r.json()
    ndvi = data.get("ndvi")

    if ndvi is None:
        return {"ndvi": None, "status": "no data"}

    ndvi = round(float(ndvi), 3)

    return {
        "lat": lat,
        "lon": lon,
        "date_used": date,
        "ndvi": ndvi,
        "status": (
            "Healthy" if ndvi >= 0.4 else
            "Stressed" if ndvi >= 0.2 else
            "Critical"
        ),
    }


@router.post("/nasa_ndvi_polygon")
def nasa_ndvi_polygon(geojson: dict, date: str):

    date = nearest_modis_date(date)
    coords = geojson["geometry"]["coordinates"][0]
    values = []

    for lat, lon in coords:
        url = (
            "https://modis.ornl.gov/rst/api/v1/MOD13Q1"
            f"?latitude={lat}&longitude={lon}&date={date}"
        )

        r = requests.get(url)
        if r.status_code == 200:
            ndvi = r.json().get("ndvi")
            if ndvi is not None:
                values.append(float(ndvi))

    if not values:
        return {"average_ndvi": None, "status": "no data"}

    avg = sum(values) / len(values)

    return {
        "average_ndvi": round(avg, 3),
        "date_used": date,
        "status": (
            "Healthy" if avg >= 0.4 else
            "Stressed" if avg >= 0.2 else
            "Critical"
        ),
    }
