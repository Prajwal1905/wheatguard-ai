import React, { useEffect, useState } from "react";
import { scanNDVIStress, getNDVIStressAlerts } from "../services/api";

export default function NDVIStressPanel({ onLocate }) {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadAlerts = async () => {
    try {
      const data = await getNDVIStressAlerts();
      setAlerts(data);
    } catch (e) {
      console.error("Stress alerts load error:", e);
    }
  };

  useEffect(() => {
    loadAlerts();
  }, []);

  const runScan = async () => {
    setLoading(true);
    try {
      await scanNDVIStress();
      await loadAlerts();     
    } catch (e) {
      console.error("Scan failed", e);
    } finally {
      setLoading(false);
    }
  };

  const badgeColor = (s) => {
    if (s === "Critical") return "red";
    if (s === "High") return "orange";
    if (s === "Moderate") return "gold";
    return "gray";
  };

  return (
    <div style={{ marginTop: 20 }}>
      <h3>🌾 NDVI Stress Alerts</h3>

      <button
        onClick={runScan}
        disabled={loading}
        style={{
          padding: "8px 12px",
          background: "#1976D2",
          color: "white",
          border: "none",
          borderRadius: 6,
          marginBottom: 10
        }}
      >
        {loading ? "Scanning…" : "🔍 Run NDVI Stress Scan"}
      </button>

      <table
        style={{
          width: "100%",
          borderCollapse: "collapse",
          background: "white",
          borderRadius: 8,
          overflow: "hidden",
          boxShadow: "0 0 5px rgba(0,0,0,0.2)"
        }}
      >
        <thead>
          <tr style={{ background: "#f5f5f5", textAlign: "left" }}>
            <th style={{ padding: 10 }}>Severity</th>
            <th style={{ padding: 10 }}>NDVI</th>
            <th style={{ padding: 10 }}>Drop</th>
            <th style={{ padding: 10 }}>Location</th>
            <th style={{ padding: 10 }}>Action</th>
          </tr>
        </thead>

        <tbody>
          {alerts.map((a) => (
            <tr key={a.id}>
              <td style={{ padding: 10 }}>
                <span
                  style={{
                    padding: "4px 8px",
                    borderRadius: 6,
                    color: "white",
                    background: badgeColor(a.severity)
                  }}
                >
                  {a.severity}
                </span>
              </td>

              <td style={{ padding: 10 }}>
                {a.current_ndvi} → baseline {a.baseline_ndvi}
              </td>

              <td style={{ padding: 10, color: "red" }}>
                -{a.drop}
              </td>

              <td style={{ padding: 10 }}>
                ({a.lat.toFixed(4)}, {a.lon.toFixed(4)})
              </td>

              <td style={{ padding: 10 }}>
                <button
                  onClick={() => onLocate(a.lat, a.lon)}
                  style={{
                    padding: "5px 10px",
                    background: "#2e7d32",
                    color: "white",
                    border: "none",
                    borderRadius: 4
                  }}
                >
                  📍 Locate
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {alerts.length === 0 && (
        <div style={{ marginTop: 10, color: "gray" }}>
          No stress alerts detected yet.
        </div>
      )}
    </div>
  );
}
