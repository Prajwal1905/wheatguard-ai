import React, { useEffect, useState } from "react";
import { getNDVIStressAlerts, getMapData } from "../services/api";
import { useNavigate } from "react-router-dom";

export default function Alerts() {
  const navigate = useNavigate();

  const [tab, setTab] = useState("stress");
  const [severityFilter, setSeverityFilter] = useState("All");

  const [stressAlerts, setStressAlerts] = useState([]);
  const [droneAlerts, setDroneAlerts] = useState([]);
  const [manualAlerts, setManualAlerts] = useState([]);

  useEffect(() => {
    loadAlerts();
  }, []);

  async function loadAlerts() {
    try {
      const stress = await getNDVIStressAlerts();
      setStressAlerts(stress);

      const mapData = await getMapData();
      const drone = mapData.filter((x) => x.source === "drone");
      const manual = mapData.filter((x) => x.source === "manual");

      setDroneAlerts(drone);
      setManualAlerts(manual);
    } catch (err) {
      console.error(err);
    }
  }

  function applyFilter(list) {
    return severityFilter === "All"
      ? list
      : list.filter((a) => a.severity === severityFilter);
  }

  function colorOf(sev) {
    if (sev === "Critical") return "#c62828";
    if (sev === "High") return "#f57c00";
    if (sev === "Moderate") return "#fbc02d";
    if (sev === "Low") return "#388e3c";
    return "#555";
  }

  function viewOnMap(lat, lon) {
    navigate(`/map?lat=${lat}&lon=${lon}`);
  }

  function renderTable(list, type) {
    const items = applyFilter(list);

    if (!items.length)
      return (
        <div style={{ padding: 20, textAlign: "center", color: "#777" }}>
          No alerts found.
        </div>
      );

    return (
      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.th}>Type</th>
            <th style={styles.th}>Severity</th>
            <th style={styles.th}>Location</th>
            <th style={styles.th}>Details</th>
            <th style={styles.th}>Action</th>
          </tr>
        </thead>

        <tbody>
          {items.map((a) => (
            <tr key={a.id} style={styles.tr}>
              <td style={styles.td}>
                {type === "stress" && "🌱 NDVI Stress"}
                {type === "drone" && "🚁 Drone Detection"}
                {type === "manual" && "⚠ Manual Alert"}
              </td>

              <td style={{ ...styles.td, fontWeight: "bold", color: colorOf(a.severity) }}>
                {a.severity}
              </td>

              <td style={styles.td}>
                {a.lat.toFixed(4)}, {a.lon.toFixed(4)}
              </td>

              <td style={styles.td}>
                {type === "stress" && (
                  <>
                    Drop: <b>{a.drop}</b>
                    <br />
                    Baseline: {a.baseline_ndvi}
                    <br />
                    Current: {a.current_ndvi}
                  </>
                )}

                {type === "drone" && (
                  <>
                    Disease: <b>{a.disease}</b>
                    <br />
                    Severity: {a.severity}
                  </>
                )}

                {type === "manual" && (
                  <>
                    Disease: <b>{a.disease}</b>
                    <br />
                    Message: {a.message}
                  </>
                )}
              </td>

              <td style={styles.td}>
                <button style={styles.viewBtn} onClick={() => viewOnMap(a.lat, a.lon)}>
                  📍 View
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    );
  }

  return (
    <div style={{ padding: 20, color:"black" }}>
      <h2> Alerts Panel</h2>

      
      <div style={{ display: "flex", gap: 10, margin: "15px 0" }}>
        <button
          style={tab === "stress" ? styles.tabActive : styles.tab}
          onClick={() => setTab("stress")}
        >
          🌱 NDVI Stress Alerts
        </button>

        <button
          style={tab === "drone" ? styles.tabActive : styles.tab}
          onClick={() => setTab("drone")}
        >
          🚁 Drone Alerts
        </button>

        <button
          style={tab === "manual" ? styles.tabActive : styles.tab}
          onClick={() => setTab("manual")}
        >
          ⚠ Manual Alerts
        </button>
      </div>

      
      <div style={{ marginBottom: 10 }}>
        <select
          value={severityFilter}
          onChange={(e) => setSeverityFilter(e.target.value)}
          style={{
            padding: "6px 12px",
            borderRadius: 6,
            border: "1px solid #aaa",
          }}
        >
          <option value="All">All</option>
          <option value="Critical">Critical</option>
          <option value="High">High</option>
          <option value="Moderate">Moderate</option>
          <option value="Low">Low</option>
        </select>
      </div>

      {tab === "stress" && renderTable(stressAlerts, "stress")}
      {tab === "drone" && renderTable(droneAlerts, "drone")}
      {tab === "manual" && renderTable(manualAlerts, "manual")}
    </div>
  );
}

const styles = {
  table: {
    width: "100%",
    background: "#fff",
    borderRadius: 10,
    borderCollapse: "collapse",
    overflow: "hidden",
  },
  th: {
    padding: "10px",
    background: "#e8eaf6",
    textAlign: "left",
    fontWeight: "bold",
    fontSize: 14,
  },
  tr: {
    borderBottom: "1px solid #ddd",
  },
  td: {
    padding: "10px",
    fontSize: 14,
  },
  viewBtn: {
    padding: "6px 12px",
    background: "#2e7d32",
    color: "white",
    borderRadius: 6,
    border: "none",
    cursor: "pointer",
  },
  tab: {
    padding: "8px 14px",
    background: "#ccc",
    border: "none",
    borderRadius: 6,
    fontWeight: "bold",
    cursor: "pointer",
  },
  tabActive: {
    padding: "8px 14px",
    background: "#1976d2",
    color: "white",
    borderRadius: 6,
    fontWeight: "bold",
    cursor: "pointer",
    border: "none",
  },
};
