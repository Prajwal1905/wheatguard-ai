import React, { useEffect, useState } from "react";
import MapView from "../components/MapView";
import { getMapData, getNDVIStressAlerts, getFields } from "../services/api";
import { socket } from "../services/socket";
import toast from "react-hot-toast";
import { useSearchParams } from "react-router-dom";
import NDVIStressPanel from "../components/NDVIStressPanel";

export default function LiveMap() {
  const [detections, setDetections] = useState([]);
  const [fields, setFields] = useState([]);
  const [filters, setFilters] = useState({ severity: "All", disease: "All" });
  const [locatePoint, setLocatePoint] = useState(null);

  const notificationsEnabled = () =>
    localStorage.getItem("notifications") !== "false";

  useEffect(() => {
    loadAllData();

    socket.on("new_detection", (d) => {
      setDetections((prev) =>
        prev.some((x) => x.id === d.id) ? prev : [...prev, d],
      );
      if (notificationsEnabled()) {
        toast.success(`${d.disease} (${d.severity}) detected`);
      }
    });

    socket.on("ndvi_stress_update", (items) => {
      const newStress = items.map((s) => ({
        id: `stress-${s.id}`,
        lat: s.lat,
        lon: s.lon,
        disease: "NDVI stress",
        severity: s.severity,
        drop: s.drop,
        baseline: s.baseline_ndvi,
        current: s.current_ndvi,
        type: "stress",
      }));
      setDetections((prev) => [
        ...prev.filter((p) => p.type !== "stress"),
        ...newStress,
      ]);
      if (notificationsEnabled()) {
        toast(`NDVI stress updated — ${items.length} locations`);
      }
    });

    return () => {
      socket.off("new_detection");
      socket.off("ndvi_stress_update");
    };
  }, []);

  useEffect(() => {
    let interval;

    const startInterval = () => {
      if (interval) clearInterval(interval);
      const seconds = parseInt(localStorage.getItem("refreshRate") || "30", 10);
      if (seconds > 0) {
        interval = setInterval(loadAllData, seconds * 1000);
      }
    };

    startInterval();
    window.addEventListener("wheatguard-settings-changed", startInterval);

    return () => {
      if (interval) clearInterval(interval);
      window.removeEventListener("wheatguard-settings-changed", startInterval);
    };
  }, []);

  const [params] = useSearchParams();
  const urlLat = params.get("lat");
  const urlLon = params.get("lon");

  useEffect(() => {
    if (urlLat && urlLon)
      setLocatePoint({ lat: parseFloat(urlLat), lon: parseFloat(urlLon) });
  }, [urlLat, urlLon]);

  useEffect(() => {
    if (locatePoint) loadAllData();
  }, [locatePoint]);

  async function loadAllData() {
    try {
      const det = await getMapData();
      const stress = await getNDVIStressAlerts();
      const flds = await getFields();

      const stressPoints = stress.map((s) => ({
        id: `stress-${s.id}`,
        lat: s.lat,
        lon: s.lon,
        severity: s.severity,
        disease: "NDVI stress",
        drop: s.drop,
        baseline: s.baseline_ndvi,
        current: s.current_ndvi,
        type: "stress",
      }));

      setDetections([...det, ...stressPoints]);
      setFields(flds);
    } catch (err) {
      console.error("Map data error:", err);
    }
  }

  const filtered = detections.filter((d) => {
    const severityOk =
      filters.severity === "All" || d.severity === filters.severity;
    const diseaseOk =
      filters.disease === "All" || d.disease === filters.disease;
    return severityOk && diseaseOk;
  });

  const uniqueDiseases = ["All", ...new Set(detections.map((d) => d.disease))];

  return (
    <div style={styles.page}>
      <div style={styles.pageHeader}>
        <div>
          <h1 style={styles.title}>Live field map</h1>
          <p style={styles.subtitle}>NDVI overlay — VIIRS + MODIS + Sentinel</p>
        </div>
      </div>

      <NDVIStressPanel onLocate={(lat, lon) => setLocatePoint({ lat, lon })} />

      <div style={styles.controlBar}>
        <div style={styles.filterGroup}>
          <i
            className="ti ti-alert-triangle"
            style={styles.filterIcon}
            aria-hidden="true"
          />
          <select
            value={filters.severity}
            onChange={(e) =>
              setFilters({ ...filters, severity: e.target.value })
            }
            style={styles.select}
            aria-label="Filter by severity"
          >
            {["All", "High", "Medium", "Low", "Critical", "Moderate"].map(
              (s) => (
                <option key={s} value={s}>
                  {s === "All" ? "All severities" : s}
                </option>
              ),
            )}
          </select>
        </div>

        <div style={styles.filterGroup}>
          <i
            className="ti ti-virus"
            style={styles.filterIcon}
            aria-hidden="true"
          />
          <select
            value={filters.disease}
            onChange={(e) =>
              setFilters({ ...filters, disease: e.target.value })
            }
            style={styles.select}
            aria-label="Filter by disease"
          >
            {uniqueDiseases.map((d) => (
              <option key={d} value={d}>
                {d === "All" ? "All diseases" : d}
              </option>
            ))}
          </select>
        </div>

        <button onClick={loadAllData} style={styles.btnGhost}>
          <i
            className="ti ti-refresh"
            style={{ fontSize: 14 }}
            aria-hidden="true"
          />
          Refresh
        </button>
      </div>

      <MapView
        detections={filtered}
        fields={fields}
        forceCenter={locatePoint}
        onDataChange={loadAllData}
      />
    </div>
  );
}

const styles = {
  page: {
    padding: "24px 20px",
    color: "#1a1a1a",
  },
  pageHeader: {
    marginBottom: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: 500,
    color: "#1a1a1a",
    margin: 0,
  },
  subtitle: {
    fontSize: 13,
    color: "#888",
    marginTop: 3,
  },
  controlBar: {
    display: "flex",
    gap: 8,
    flexWrap: "wrap",
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.1)",
    borderRadius: 10,
    padding: "10px 12px",
    marginBottom: 16,
    alignItems: "center",
  },
  filterGroup: {
    display: "flex",
    alignItems: "center",
    gap: 5,
    background: "#fafafa",
    border: "0.5px solid #d0d0d0",
    borderRadius: 7,
    padding: "0 8px",
  },
  filterIcon: {
    fontSize: 14,
    color: "#999",
  },
  select: {
    border: "none",
    background: "transparent",
    padding: "7px 4px",
    fontSize: 13,
    color: "#333",
    cursor: "pointer",
    outline: "none",
  },
  btnGhost: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    padding: "7px 12px",
    background: "transparent",
    border: "0.5px solid #d0d0d0",
    borderRadius: 7,
    fontSize: 13,
    fontWeight: 500,
    color: "#444",
    cursor: "pointer",
  },
};
