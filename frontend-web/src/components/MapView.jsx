import React, { useState, useEffect } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polygon,
  useMapEvents,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "leaflet.heat";
import NdviTrendGraph from "./NdviTrendGraph";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";


delete L.Icon.Default.prototype._getIconUrl;
L.IconDefault = L.Icon.Default.mergeOptions({
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9/dist/images/marker-shadow.png",
});

const iconBase =
  "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img";

const redIcon = new L.Icon({
  iconUrl: `${iconBase}/marker-icon-red.png`,
  shadowUrl: `${iconBase}/marker-shadow.png`,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

const orangeIcon = new L.Icon({
  iconUrl: `${iconBase}/marker-icon-orange.png`,
  shadowUrl: `${iconBase}/marker-shadow.png`,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

const greenIcon = new L.Icon({
  iconUrl: `${iconBase}/marker-icon-green.png`,
  shadowUrl: `${iconBase}/marker-shadow.png`,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

function parseLatLon(input, isLat = true) {
  if (!input) return null;
  input = input.trim().toUpperCase().replace(/\s+/g, "");

  if (/^\d{6}$/.test(input)) {
    let d = +input.slice(0, 2);
    let m = +input.slice(2, 4);
    let s = +input.slice(4, 6);
    return d + m / 60 + s / 3600;
  }

  let compact = input.match(/^(\d{2,3})(\d{2})(\d{2})([NSEW])$/);
  if (compact) {
    let d = +compact[1],
      m = +compact[2],
      s = +compact[3];
    let val = d + m / 60 + s / 3600;
    if (["S", "W"].includes(compact[4])) val = -val;
    return val;
  }

  if (!isNaN(parseFloat(input))) return parseFloat(input);

  return null;
}


function ClickNDVI({ setClicked }) {
  useMapEvents({
    click: async (e) => {
      const { lat, lng } = e.latlng;
      setClicked({ status: "loading", lat, lon: lng });

      try {
        const res = await fetch(
          `${API_BASE}/api/sentinel_ndvi_value?lat=${lat}&lon=${lng}`
        );
        const data = await res.json();

        setClicked({
          status: "ok",
          lat,
          lon: lng,
          ndvi: data.ndvi,
          statusText: data.status,
          date_used: data.date,
        });
      } catch {
        setClicked({ status: "error", lat, lon: lng });
      }
    },
  });

  return null;
}

function HeatLayer({ points }) {
  const map = useMapEvents({});

  useEffect(() => {
    if (!points || points.length === 0) return;

    const layer = L.heatLayer(points, {
      radius: 55,
      blur: 15,
      maxZoom: 17,
      max: 3,
    }).addTo(map);

    return () => map.removeLayer(layer);
  }, [points]);

  return null;
}

function FlyToLocation({ center }) {
  const map = useMapEvents({});
  useEffect(() => {
    if (center) {
      map.flyTo([center.lat, center.lon], 16, { duration: 1.2 });
    }
  }, [center]);
  return null;
}

export default function MapView({ detections = [] }) {
  const [latInput, setLatInput] = useState("");
  const [lonInput, setLonInput] = useState("");

  const [fields, setFields] = useState([]);
  const [satellite, setSatellite] = useState(false);
  const [heatmap, setHeatmap] = useState(false);
  const [ndviOn, setNdviOn] = useState(true);

  const [clicked, setClicked] = useState(null);
  const [forceCenter, setForceCenter] = useState(null);

  useEffect(() => {
    async function loadFields() {
      try {
        const res = await fetch(`${API_BASE}/fields/`);
        const data = await res.json();
        setFields(data);
      } catch (e) {
        console.error("Error loading fields:", e);
      }
    }
    loadFields();
  }, []);

  
  const handleSearch = () => {
    const lat = parseLatLon(latInput, true);
    const lon = parseLatLon(lonInput, false);

    if (lat === null || lon === null) {
      alert(" Invalid latitude or longitude format");
      return;
    }

    setForceCenter({ lat, lon });
  };

  return (
    <div style={{ height: "75vh", width: "100%", position: "relative" }}>
      
      <div
        style={{
          position: "absolute",
          top: 90,
          left: 10,
          zIndex: 5000,
          background: "#fff",
          padding: 14,
          width: 260,
          borderRadius: 12,
          boxShadow: "0 4px 12px rgba(0,0,0,0.2)",
        }}
      >
        <input
          value={latInput}
          onChange={(e) => setLatInput(e.target.value)}
          placeholder="Latitude"
          style={{
            width: "90%",
            padding: 8,
            marginBottom: 8,
            borderRadius: 6,
            border: "1px solid #ccc",
          }}
        />

        <input
          value={lonInput}
          onChange={(e) => setLonInput(e.target.value)}
          placeholder="Longitude"
          style={{
            width: "90%",
            padding: 8,
            borderRadius: 6,
            border: "1px solid #ccc",
          }}
        />

        <button
          onClick={handleSearch}
          style={{
            width: "95%",
            marginTop: 10,
            padding: 10,
            background: "#0D6EFD",
            color: "#fff",
            fontWeight: 600,
            borderRadius: 6,
            border: "none",
            cursor: "pointer",
          }}
        >
          Locate & Show NDVI
        </button>
      </div>

      
      <div
        style={{
          position: "absolute",
          top: 20,
          right: 20,
          zIndex: 5000,
          padding: 10,
          background: "#fff",
          borderRadius: 12,
          display: "flex",
          gap: 10,
          boxShadow: "0 4px 10px rgba(0,0,0,0.25)",
        }}
      >
        <button onClick={() => setSatellite(!satellite)}>
          {satellite ? "🗺 Map" : "🛰 Satellite"}
        </button>
        <button onClick={() => setHeatmap(!heatmap)}>
          {heatmap ? "📍 Markers" : "🔥 Heatmap"}
        </button>
        <button onClick={() => setNdviOn(!ndviOn)}>
          {ndviOn ? "🌾 Hide NDVI" : "🌱 NDVI"}
        </button>
      </div>

      
      <MapContainer center={[20.5, 78.5]} zoom={6} style={{ height: "100%" }}>
        <FlyToLocation center={forceCenter} />

        
        <TileLayer
          url={
            satellite
              ? "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
              : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          }
        />

        
        {ndviOn && (
          <TileLayer
            url="https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_SNPP_NDVI/default/2024-01-01/GoogleMapsCompatible/{z}/{y}/{x}.png"
            opacity={0.55}
          />
        )}

        
        {heatmap && (
          <HeatLayer
            points={detections.map((d) => [
              d.lat,
              d.lon,
              d.severity === "High" ? 1.5 : d.severity === "Medium" ? 1.0 : 0.6,
            ])}
          />
        )}

        <ClickNDVI setClicked={setClicked} />

        
        {fields.map((f) => {
          if (!f.polygon) return null;

          const poly = Array.isArray(f.polygon)
            ? f.polygon
            : JSON.parse(f.polygon);

          const positions = poly.map((p) => [p[0], p[1]]);

          return (
            <Polygon
              key={f.id}
              positions={positions}
              pathOptions={{ color: "blue", weight: 2 }}
            >
              <Popup>
                <div style={{ width: 220 }}>
                  <h4>Field #{f.id}</h4>
                  <b>Village:</b> {f.village} <br />
                  <b>Crop:</b> {f.crop} <br />
                  <b>Phone:</b> {f.phone} <br />
                  <b>Farmer ID:</b> {f.farmer_id} <br />

                  {f.photo_url && (
                    <>
                      <br />
                      <img
                        src={`${API_BASE}${f.photo_url}`}
                        style={{ width: "100%", borderRadius: 8 }}
                      />
                    </>
                  )}

                  {f.field_photo_url && (
                    <>
                      <br />
                      <img
                        src={`${API_BASE}${f.field_photo_url}`}
                        style={{
                          width: "100%",
                          borderRadius: 8,
                          marginTop: 6,
                        }}
                      />
                    </>
                  )}
                </div>
              </Popup>
            </Polygon>
          );
        })}

        
        {detections.map((d, idx) => (
          <Marker
            key={idx}
            position={[d.lat, d.lon]}
            icon={
              d.severity === "High"
                ? redIcon
                : d.severity === "Medium"
                ? orangeIcon
                : greenIcon
            }
          >
            <Popup>
              <b>Disease:</b> {d.disease} <br />
              <b>Severity:</b> {d.severity} <br />
              <b>Lat:</b> {d.lat} <br />
              <b>Lon:</b> {d.lon} <br />
            </Popup>
          </Marker>
        ))}

        
        {clicked && clicked.status === "ok" && (
          <Marker position={[clicked.lat, clicked.lon]}>
            <Popup>
              <b>NDVI:</b> {clicked.ndvi} <br />
              <b>{clicked.statusText}</b> <br />
              <NdviTrendGraph lat={clicked.lat} lon={clicked.lon} />
            </Popup>
          </Marker>
        )}
      </MapContainer>
    </div>
  );
}
