import React, { useEffect, useState } from "react";
import { scanNDVIStress, getNDVIStressAlerts } from "../services/api";

function severityStyle(sev) {
  if (sev === "Critical") return { background: "#FCEBEB", color: "#A32D2D" };
  if (sev === "High")     return { background: "#FAEEDA", color: "#854F0B" };
  if (sev === "Moderate") return { background: "#EAF3DE", color: "#3B6D11" };
  return { background: "#E6F1FB", color: "#185FA5" };
}

export default function NDVIStressPanel({ onLocate }) {
  const [alerts, setAlerts]   = useState([]);
  const [loading, setLoading] = useState(false);
  const [expanded, setExpanded] = useState(true);

  const loadAlerts = async () => {
    try {
      const data = await getNDVIStressAlerts();
      setAlerts(data);
    } catch (e) {
      console.error("Stress alerts load error:", e);
    }
  };

  useEffect(() => { loadAlerts(); }, []);

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

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <i className="ti ti-leaf" style={styles.headerIcon} aria-hidden="true" />
          <span style={styles.title}>NDVI stress alerts</span>
          {alerts.length > 0 && (
            <span style={styles.countBadge}>{alerts.length}</span>
          )}
        </div>
        <div style={styles.headerRight}>
          <button
            onClick={runScan}
            disabled={loading}
            style={styles.scanBtn}
          >
            <i
              className={`ti ${loading ? "ti-loader-2" : "ti-scan"}`}
              style={{ fontSize: 13 }}
              aria-hidden="true"
            />
            {loading ? "Scanning…" : "Run scan"}
          </button>
          <button
            onClick={() => setExpanded(!expanded)}
            style={styles.collapseBtn}
            aria-label={expanded ? "Collapse" : "Expand"}
          >
            <i
              className={`ti ${expanded ? "ti-chevron-up" : "ti-chevron-down"}`}
              style={{ fontSize: 14 }}
              aria-hidden="true"
            />
          </button>
        </div>
      </div>

      {expanded && (
        <div style={styles.body}>
          {alerts.length === 0 ? (
            <div style={styles.empty}>
              <i className="ti ti-circle-check" style={{ fontSize: 20, color: "#3B6D11", display: "block", marginBottom: 6 }} aria-hidden="true" />
              No stress alerts detected.
            </div>
          ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  {["Severity", "Current NDVI", "Drop", "Location", ""].map((h) => (
                    <th key={h} style={styles.th}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {alerts.map((a) => (
                  <tr key={a.id} style={styles.tr}>
                    <td style={styles.td}>
                      <span style={{ ...styles.badge, ...severityStyle(a.severity) }}>
                        {a.severity}
                      </span>
                    </td>
                    <td style={styles.td}>
                      <span style={styles.ndviVal}>{a.current_ndvi}</span>
                      <span style={styles.ndviBase}> / {a.baseline_ndvi}</span>
                    </td>
                    <td style={{ ...styles.td, color: "#A32D2D", fontWeight: 500 }}>
                      -{a.drop}
                    </td>
                    <td style={{ ...styles.td, fontFamily: "monospace", fontSize: 11, color: "#666" }}>
                      {a.lat.toFixed(4)}, {a.lon.toFixed(4)}
                    </td>
                    <td style={styles.td}>
                      <button
                        onClick={() => onLocate(a.lat, a.lon)}
                        style={styles.locateBtn}
                      >
                        <i className="ti ti-map-pin" style={{ fontSize: 12 }} aria-hidden="true" />
                        Locate
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

const styles = {
  card: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.08)",
    borderRadius: 12,
    marginBottom: 16,
    overflow: "hidden",
  },
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "12px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
    background: "#F7F8F5",
  },
  headerLeft: {
    display: "flex",
    alignItems: "center",
    gap: 8,
  },
  headerIcon: {
    fontSize: 15,
    color: "#1B5E20",
  },
  title: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
  },
  countBadge: {
    background: "#1B5E20",
    color: "#fff",
    fontSize: 11,
    fontWeight: 500,
    padding: "1px 7px",
    borderRadius: 20,
  },
  headerRight: {
    display: "flex",
    alignItems: "center",
    gap: 8,
  },
  scanBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "6px 12px",
    background: "#1B5E20",
    color: "#fff",
    border: "none",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
  },
  collapseBtn: {
    background: "transparent",
    border: "0.5px solid rgba(0,0,0,0.12)",
    borderRadius: 6,
    padding: "5px 7px",
    cursor: "pointer",
    color: "#666",
    display: "flex",
    alignItems: "center",
  },
  body: {
    padding: "0",
  },
  empty: {
    textAlign: "center",
    color: "#aaa",
    fontSize: 13,
    padding: "24px 0",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
  },
  th: {
    padding: "8px 14px",
    fontSize: 11,
    fontWeight: 500,
    color: "#888",
    textAlign: "left",
    textTransform: "uppercase",
    letterSpacing: "0.03em",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
    background: "#fafafa",
  },
  tr: {
    borderBottom: "0.5px solid rgba(0,0,0,0.05)",
  },
  td: {
    padding: "10px 14px",
    fontSize: 13,
    color: "#333",
    verticalAlign: "middle",
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    padding: "2px 8px",
    borderRadius: 20,
    fontSize: 11,
    fontWeight: 500,
  },
  ndviVal: {
    fontWeight: 500,
    color: "#1a1a1a",
  },
  ndviBase: {
    fontSize: 11,
    color: "#999",
  },
  locateBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "5px 10px",
    background: "transparent",
    border: "0.5px solid #1B5E20",
    color: "#1B5E20",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
  },
};
