import React, { useEffect, useState } from "react";
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
import DetectionDetailPanel from "./DetectionDetailPanel";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9/dist/images/marker-shadow.png",
});

const iconBase =
  "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img";
const makeIcon = (color) =>
  new L.Icon({
    iconUrl: `${iconBase}/marker-icon-${color}.png`,
    shadowUrl: `${iconBase}/marker-shadow.png`,
    iconSize: [25, 41],
    iconAnchor: [12, 41],
  });
const redIcon = makeIcon("red");
const orangeIcon = makeIcon("orange");
const greenIcon = makeIcon("green");

function severityIcon(sev) {
  if (sev === "High" || sev === "Critical") return redIcon;
  if (sev === "Medium" || sev === "Moderate") return orangeIcon;
  return greenIcon;
}

function parseLatLon(input) {
  if (!input) return null;
  const cleaned = input.trim().replace(/\s+/g, "");
  if (!isNaN(parseFloat(cleaned))) return parseFloat(cleaned);
  return null;
}

function ClickNDVI({ setClicked }) {
  useMapEvents({
    click: async (e) => {
      const { lat, lng } = e.latlng;
      setClicked({ status: "loading", lat, lon: lng });
      try {
        const res = await fetch(
          `${API_BASE}/api/sentinel_ndvi_value?lat=${lat}&lon=${lng}`,
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
    if (!points?.length) return;
    const layer = L.heatLayer(points, {
      radius: 55,
      blur: 15,
      maxZoom: 17,
      max: 3,
    }).addTo(map);
    return () => map.removeLayer(layer);
  }, [points, map]);
  return null;
}

function FlyToLocation({ center }) {
  const map = useMapEvents({});
  useEffect(() => {
    if (center) map.flyTo([center.lat, center.lon], 16, { duration: 1.2 });
  }, [center, map]);
  return null;
}

export default function MapView({
  detections = [],
  fields = [],
  polygonMode = false,
  forceCenter = null,
}) {
  const [latInput, setLatInput] = useState("");
  const [lonInput, setLonInput] = useState("");
  const [satellite, setSatellite] = useState(false);
  const [heatmap, setHeatmap] = useState(false);
  const [ndviOn, setNdviOn] = useState(true);
  const [clicked, setClicked] = useState(null);
  const [localCenter, setLocalCenter] = useState(null);
  const [selectedId, setSelectedId] = useState(null);

  const center = forceCenter || localCenter;

  const handleSearch = () => {
    const lat = parseLatLon(latInput);
    const lon = parseLatLon(lonInput);
    if (lat === null || lon === null) {
      alert("Invalid latitude or longitude.");
      return;
    }
    setLocalCenter({ lat, lon });
  };

  const heatPoints = detections.map((d) => [
    d.lat,
    d.lon,
    d.severity === "High" || d.severity === "Critical"
      ? 1.5
      : d.severity === "Medium" || d.severity === "Moderate"
        ? 1.0
        : 0.6,
  ]);

  return (
    <div style={styles.root}>
      <div style={styles.searchPanel}>
        <div style={styles.searchTitle}>
          <i
            className="ti ti-search"
            style={{ fontSize: 13, color: "#1B5E20" }}
            aria-hidden="true"
          />
          Jump to location
        </div>
        <input
          value={latInput}
          onChange={(e) => setLatInput(e.target.value)}
          placeholder="Latitude"
          style={styles.searchInput}
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
        />
        <input
          value={lonInput}
          onChange={(e) => setLonInput(e.target.value)}
          placeholder="Longitude"
          style={{ ...styles.searchInput, marginTop: 6 }}
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
        />
        <button onClick={handleSearch} style={styles.searchBtn}>
          <i
            className="ti ti-map-pin"
            style={{ fontSize: 13 }}
            aria-hidden="true"
          />
          Locate & show NDVI
        </button>
      </div>

      <div style={styles.layerPanel}>
        <ToggleBtn
          active={satellite}
          onClick={() => setSatellite(!satellite)}
          icon={satellite ? "ti-map-2" : "ti-satellite"}
          label={satellite ? "Map" : "Satellite"}
        />
        <ToggleBtn
          active={heatmap}
          onClick={() => setHeatmap(!heatmap)}
          icon="ti-flame"
          label={heatmap ? "Markers" : "Heatmap"}
        />
        <ToggleBtn
          active={ndviOn}
          onClick={() => setNdviOn(!ndviOn)}
          icon="ti-leaf"
          label={ndviOn ? "Hide NDVI" : "NDVI"}
        />
      </div>

      {detections.length > 0 && (
        <div style={styles.countBadge}>
          <i
            className="ti ti-map-pin"
            style={{ fontSize: 12 }}
            aria-hidden="true"
          />
          {detections.length} detections — click a marker for details
        </div>
      )}

      <MapContainer center={[20.5, 78.5]} zoom={6} style={styles.map}>
        {center && <FlyToLocation center={center} />}

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

        {heatmap && <HeatLayer points={heatPoints} />}

        <ClickNDVI setClicked={setClicked} />

        {fields.map((f) => {
          if (!f.polygon) return null;
          const poly = Array.isArray(f.polygon)
            ? f.polygon
            : JSON.parse(f.polygon);
          return (
            <Polygon
              key={f.id}
              positions={poly.map((p) => [p[0], p[1]])}
              pathOptions={{ color: "#1B5E20", weight: 2 }}
            >
              <Popup>
                <div style={{ fontSize: 12, lineHeight: 1.6 }}>
                  <strong>Field #{f.id}</strong>
                  <br />
                  Village: {f.village}
                  <br />
                  Crop: {f.crop}
                  <br />
                  Phone: {f.phone}
                </div>
              </Popup>
            </Polygon>
          );
        })}

        {!heatmap &&
          detections.map((d, idx) => (
            <Marker
              key={d.id || idx}
              position={[d.lat, d.lon]}
              icon={severityIcon(d.severity)}
              eventHandlers={{
                click: () => setSelectedId(d.id),
              }}
            >
              <Popup>
                <div style={{ fontSize: 12, lineHeight: 1.7 }}>
                  <strong>{d.disease}</strong>
                  <br />
                  Severity: {d.severity}
                  <br />
                  <span
                    style={{
                      fontFamily: "monospace",
                      fontSize: 11,
                      color: "#666",
                    }}
                  >
                    {d.lat?.toFixed(4)}, {d.lon?.toFixed(4)}
                  </span>
                  <br />
                  <button
                    onClick={() => setSelectedId(d.id)}
                    style={styles.detailBtn}
                  >
                    <i
                      className="ti ti-external-link"
                      style={{ fontSize: 11 }}
                      aria-hidden="true"
                    />
                    View full details
                  </button>
                </div>
              </Popup>
            </Marker>
          ))}

        {clicked?.status === "ok" && (
          <Marker position={[clicked.lat, clicked.lon]}>
            <Popup minWidth={220}>
              <div style={{ fontSize: 12 }}>
                <strong>NDVI: {clicked.ndvi}</strong>
                <br />
                <span style={{ color: "#666" }}>{clicked.statusText}</span>
                <NdviTrendGraph lat={clicked.lat} lon={clicked.lon} />
              </div>
            </Popup>
          </Marker>
        )}

        {clicked?.status === "loading" && (
          <Marker position={[clicked.lat, clicked.lon]}>
            <Popup>
              <span style={{ fontSize: 12 }}>Loading NDVI…</span>
            </Popup>
          </Marker>
        )}
      </MapContainer>

      {selectedId && (
        <DetectionDetailPanel
          detectionId={selectedId}
          onClose={() => setSelectedId(null)}
        />
      )}
    </div>
  );
}

function ToggleBtn({ active, onClick, icon, label }) {
  return (
    <button
      onClick={onClick}
      style={{ ...toggleStyles.btn, ...(active ? toggleStyles.active : {}) }}
    >
      <i className={`ti ${icon}`} style={{ fontSize: 13 }} aria-hidden="true" />
      {label}
    </button>
  );
}

const toggleStyles = {
  btn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "6px 10px",
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.15)",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    color: "#444",
    cursor: "pointer",
    boxShadow: "0 1px 4px rgba(0,0,0,0.1)",
  },
  active: {
    background: "#1B5E20",
    color: "#fff",
    borderColor: "#1B5E20",
  },
};

const styles = {
  root: {
    position: "relative",
    height: "75vh",
    width: "100%",
    borderRadius: 12,
    overflow: "hidden",
    border: "0.5px solid rgba(0,0,0,0.08)",
  },
  map: { height: "100%", width: "100%" },
  searchPanel: {
    position: "absolute",
    top: 80,
    left: 10,
    zIndex: 5000,
    background: "#fff",
    padding: 14,
    width: 220,
    borderRadius: 10,
    boxShadow: "0 4px 16px rgba(0,0,0,0.15)",
    border: "0.5px solid rgba(0,0,0,0.08)",
  },
  searchTitle: {
    fontSize: 12,
    fontWeight: 500,
    color: "#333",
    marginBottom: 8,
    display: "flex",
    alignItems: "center",
    gap: 5,
  },
  searchInput: {
    width: "100%",
    padding: "7px 10px",
    borderRadius: 6,
    border: "0.5px solid #d0d0d0",
    fontSize: 13,
    color: "#1a1a1a",
    background: "#fafafa",
    outline: "none",
    boxSizing: "border-box",
  },
  searchBtn: {
    width: "100%",
    marginTop: 8,
    padding: "8px 0",
    background: "#1B5E20",
    color: "#fff",
    border: "none",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
  },
  layerPanel: {
    position: "absolute",
    top: 12,
    right: 12,
    zIndex: 5000,
    display: "flex",
    gap: 6,
  },
  countBadge: {
    position: "absolute",
    bottom: 16,
    left: "50%",
    transform: "translateX(-50%)",
    zIndex: 5000,
    background: "rgba(0,0,0,0.65)",
    color: "#fff",
    fontSize: 12,
    padding: "6px 14px",
    borderRadius: 20,
    display: "flex",
    alignItems: "center",
    gap: 6,
    backdropFilter: "blur(4px)",
    pointerEvents: "none",
  },
  detailBtn: {
    marginTop: 6,
    display: "inline-flex",
    alignItems: "center",
    gap: 4,
    padding: "4px 8px",
    background: "#1B5E20",
    color: "#fff",
    border: "none",
    borderRadius: 5,
    fontSize: 11,
    cursor: "pointer",
    fontWeight: 500,
  },
};
