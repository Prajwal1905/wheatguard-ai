import React, { useEffect, useState } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polygon,
  useMapEvents,
  useMap,
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

async function fetchNdvi(lat, lon) {
  try {
    const res = await fetch(
      `${API_BASE}/api/sentinel_ndvi_value?lat=${lat}&lon=${lon}`,
    );

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      return {
        status: "unavailable",
        lat,
        lon,
        message:
          body.detail ||
          "No satellite data available for this location right now.",
      };
    }

    const data = await res.json();
    return {
      status: "ok",
      lat,
      lon,
      ndvi: data.ndvi,
      statusText: data.status,
    };
  } catch {
    return {
      status: "error",
      lat,
      lon,
      message: "Could not reach the satellite data service.",
    };
  }
}

function ClickNDVI({ setClicked }) {
  useMapEvents({
    click: async (e) => {
      const { lat, lng } = e.latlng;
      setClicked({ status: "loading", lat, lon: lng });
      const result = await fetchNdvi(lat, lng);
      setClicked(result);
    },
  });
  return null;
}

function HeatLayer({ points }) {
  const map = useMapEvents({});
  useEffect(() => {
    if (!points?.length) return;
    const layer = L.heatLayer(points, {
      radius: 35,
      blur: 25,
      maxZoom: 12,
      max: 1.0,
      minOpacity: 0.5,
      gradient: {
        0.0: "#2b6cb0", // blue  - low severity
        0.3: "#38a169", // green
        0.5: "#ecc94b", // yellow
        0.7: "#ed8936", // orange
        1.0: "#e53e3e", // red   - high severity
      },
    }).addTo(map);
    return () => map.removeLayer(layer);
  }, [points, map]);
  return null;
}

function polygonCentroid(poly) {
  const n = poly.length;
  const sum = poly.reduce((acc, p) => [acc[0] + p[0], acc[1] + p[1]], [0, 0]);
  return [sum[0] / n, sum[1] / n];
}

const ndviColor = (status) => {
  if (status === "Healthy") return "#1B5E20";
  if (status === "Stressed") return "#E65100";
  if (status === "Critical") return "#A32D2D";
  return "#999"; // no data
};

function FieldNdviLayer({ fields, onSelect }) {
  const [fieldNdvi, setFieldNdvi] = useState({});

  useEffect(() => {
    let cancelled = false;

    fields.forEach(async (f) => {
      if (!f.polygon) return;
      const poly = Array.isArray(f.polygon) ? f.polygon : JSON.parse(f.polygon);
      if (poly.length < 3) return;

      try {
        const res = await fetch(`${API_BASE}/api/sentinel_ndvi_polygon`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            geometry: {
              // GeoJSON expects [lon, lat]
              coordinates: [poly.map((p) => [p[1], p[0]])],
            },
          }),
        });
        const data = await res.json();
        if (!cancelled) {
          setFieldNdvi((prev) => ({ ...prev, [f.id]: data }));
        }
      } catch {
        if (!cancelled) {
          setFieldNdvi((prev) => ({
            ...prev,
            [f.id]: { average_ndvi: null, status: "no data" },
          }));
        }
      }
    });

    return () => {
      cancelled = true;
    };
  }, [fields]);

  return (
    <>
      {fields.map((f) => {
        if (!f.polygon) return null;
        const poly = Array.isArray(f.polygon)
          ? f.polygon
          : JSON.parse(f.polygon);
        if (poly.length < 3) return null;

        const centroid = polygonCentroid(poly);
        const ndviData = fieldNdvi[f.id];
        const loading = !ndviData;
        const status = ndviData?.status;
        const value = ndviData?.average_ndvi;

        return (
          <Marker
            key={`ndvi-${f.id}`}
            position={centroid}
            icon={L.divIcon({
              className: "",
              html: `<div style="
                width: 28px; height: 28px; border-radius: 50%;
                background: ${loading ? "#ccc" : ndviColor(status)};
                border: 3px solid white;
                box-shadow: 0 1px 4px rgba(0,0,0,0.3);
                display:flex; align-items:center; justify-content:center;
                color:white; font-size:10px; font-weight:600;
              ">${loading ? "…" : (value ?? "-")}</div>`,
              iconSize: [28, 28],
              iconAnchor: [14, 14],
            })}
            eventHandlers={{
              click: () => {
                if (ndviData?.average_ndvi != null) {
                  onSelect({
                    status: "ok",
                    lat: centroid[0],
                    lon: centroid[1],
                    ndvi: ndviData.average_ndvi,
                    statusText: ndviData.status,
                  });
                } else {
                  onSelect({
                    status: "unavailable",
                    lat: centroid[0],
                    lon: centroid[1],
                    message:
                      ndviData?.message ||
                      "No cloud-free imagery available for this field.",
                  });
                }
              },
            }}
          >
            <Popup>
              <div style={{ fontSize: 12 }}>
                <strong>
                  Field #{f.id} — {f.village}
                </strong>
                <br />
                {loading
                  ? "Loading NDVI…"
                  : value != null
                    ? `NDVI: ${value} (${status})`
                    : "No satellite data available"}
              </div>
            </Popup>
          </Marker>
        );
      })}
    </>
  );
}

function FlyToLocation({ center, onArrive }) {
  const map = useMap();
  useEffect(() => {
    if (!center) return;
    map.flyTo([center.lat, center.lon], 16, { duration: 1.2 });

    const timer = setTimeout(() => {
      onArrive?.(center.lat, center.lon);
    }, 1300);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center]);
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

  // Called once the map finishes flying to the searched location
  const handleArrive = async (lat, lon) => {
    setClicked({ status: "loading", lat, lon });
    const result = await fetchNdvi(lat, lon);
    setClicked(result);
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
        <div style={styles.layerPanelLabel}>
          <i
            className="ti ti-layers-intersect"
            style={{ fontSize: 12 }}
            aria-hidden="true"
          />
          Layers
        </div>
        <div style={styles.layerPanelGroup}>
          <LayerOption
            active={!satellite}
            onClick={() => setSatellite(false)}
            icon="ti-map-2"
            label="Map"
          />
          <LayerOption
            active={satellite}
            onClick={() => setSatellite(true)}
            icon="ti-satellite"
            label="Satellite"
          />
        </div>
        <div style={styles.layerPanelDivider} />
        <LayerToggle
          active={heatmap}
          onClick={() => setHeatmap(!heatmap)}
          icon="ti-flame"
          label="Heatmap"
          hint="Detection density"
        />
        <LayerToggle
          active={ndviOn}
          onClick={() => setNdviOn(!ndviOn)}
          icon="ti-leaf"
          label="Field NDVI"
          hint="Crop health from satellite"
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
        {center && <FlyToLocation center={center} onArrive={handleArrive} />}

        <TileLayer
          url={
            satellite
              ? "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
              : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          }
        />

        {heatmap && <HeatLayer points={heatPoints} />}

        {ndviOn && <FieldNdviLayer fields={fields} onSelect={setClicked} />}

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
                <strong>
                  NDVI:{" "}
                  {typeof clicked.ndvi === "number"
                    ? clicked.ndvi.toFixed(3)
                    : clicked.ndvi}
                </strong>
                <br />
                <span
                  style={{
                    color:
                      clicked.statusText === "Healthy"
                        ? "#1B5E20"
                        : clicked.statusText === "Stressed"
                          ? "#E65100"
                          : "#A32D2D",
                    fontWeight: 500,
                  }}
                >
                  {clicked.statusText}
                </span>
                <NdviTrendGraph lat={clicked.lat} lon={clicked.lon} />
              </div>
            </Popup>
          </Marker>
        )}

        {clicked?.status === "loading" && (
          <Marker position={[clicked.lat, clicked.lon]}>
            <Popup>
              <span style={{ fontSize: 12 }}>
                <i className="ti ti-loader-2" aria-hidden="true" /> Fetching
                satellite data…
              </span>
            </Popup>
          </Marker>
        )}

        {(clicked?.status === "unavailable" || clicked?.status === "error") && (
          <Marker position={[clicked.lat, clicked.lon]}>
            <Popup minWidth={220}>
              <div style={{ fontSize: 12 }}>
                <strong style={{ color: "#A32D2D" }}>
                  <i
                    className="ti ti-cloud-off"
                    aria-hidden="true"
                    style={{ marginRight: 4 }}
                  />
                  NDVI unavailable
                </strong>
                <p style={{ color: "#666", marginTop: 6, marginBottom: 0 }}>
                  {clicked.message}
                </p>
              </div>
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

/** Segmented control option — e.g. Map vs Satellite (mutually exclusive) */
function LayerOption({ active, onClick, icon, label }) {
  return (
    <button
      onClick={onClick}
      style={{
        ...layerStyles.option,
        ...(active ? layerStyles.optionActive : {}),
      }}
    >
      <i className={`ti ${icon}`} style={{ fontSize: 13 }} aria-hidden="true" />
      {label}
    </button>
  );
}

/** Independent toggle — e.g. Heatmap, Field NDVI (each can be on/off) */
function LayerToggle({ active, onClick, icon, label, hint }) {
  return (
    <button onClick={onClick} style={layerStyles.toggleRow}>
      <div
        style={{
          ...layerStyles.toggleIcon,
          ...(active ? layerStyles.toggleIconActive : {}),
        }}
      >
        <i
          className={`ti ${icon}`}
          style={{ fontSize: 14 }}
          aria-hidden="true"
        />
      </div>
      <div style={layerStyles.toggleText}>
        <div style={layerStyles.toggleLabel}>{label}</div>
        <div style={layerStyles.toggleHint}>{hint}</div>
      </div>
      <div
        style={{
          ...layerStyles.switchTrack,
          ...(active ? layerStyles.switchTrackActive : {}),
        }}
      >
        <div
          style={{
            ...layerStyles.switchThumb,
            ...(active ? layerStyles.switchThumbActive : {}),
          }}
        />
      </div>
    </button>
  );
}

const layerStyles = {
  option: {
    flex: 1,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 5,
    padding: "6px 0",
    background: "transparent",
    border: "none",
    borderRadius: 6,
    fontSize: 12,
    fontWeight: 500,
    color: "#777",
    cursor: "pointer",
  },
  optionActive: {
    background: "#1B5E20",
    color: "#fff",
  },
  toggleRow: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    width: "100%",
    padding: "6px 4px",
    background: "transparent",
    border: "none",
    cursor: "pointer",
    textAlign: "left",
  },
  toggleIcon: {
    width: 26,
    height: 26,
    borderRadius: 7,
    background: "#f2f2f2",
    color: "#999",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  toggleIconActive: {
    background: "#E8F0E3",
    color: "#1B5E20",
  },
  toggleText: {
    flex: 1,
    minWidth: 0,
  },
  toggleLabel: {
    fontSize: 12,
    fontWeight: 500,
    color: "#333",
  },
  toggleHint: {
    fontSize: 10,
    color: "#999",
    marginTop: 1,
  },
  switchTrack: {
    width: 28,
    height: 16,
    borderRadius: 10,
    background: "#d9d9d9",
    position: "relative",
    flexShrink: 0,
    transition: "background 0.15s",
  },
  switchTrackActive: {
    background: "#1B5E20",
  },
  switchThumb: {
    position: "absolute",
    top: 2,
    left: 2,
    width: 12,
    height: 12,
    borderRadius: "50%",
    background: "#fff",
    transition: "left 0.15s",
  },
  switchThumbActive: {
    left: 14,
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
    top: 100,
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
    background: "#fff",
    borderRadius: 10,
    padding: 10,
    width: 180,
    boxShadow: "0 4px 16px rgba(0,0,0,0.15)",
    border: "0.5px solid rgba(0,0,0,0.08)",
  },
  layerPanelLabel: {
    fontSize: 11,
    fontWeight: 600,
    color: "#999",
    textTransform: "uppercase",
    letterSpacing: "0.05em",
    display: "flex",
    alignItems: "center",
    gap: 5,
    marginBottom: 8,
  },
  layerPanelGroup: {
    display: "flex",
    background: "#f2f2f2",
    borderRadius: 7,
    padding: 3,
    gap: 2,
  },
  layerPanelDivider: {
    height: 1,
    background: "rgba(0,0,0,0.06)",
    margin: "10px 0",
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
