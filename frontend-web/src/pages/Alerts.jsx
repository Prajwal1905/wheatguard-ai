import React, { useEffect, useState } from "react";
import { getNDVIStressAlerts, getMapData } from "../services/api";
import { useNavigate } from "react-router-dom";

const TABS = [
  { key: "stress", label: "NDVI stress", icon: "ti-leaf" },
  { key: "drone",  label: "Drone",       icon: "ti-drone" },
  { key: "manual", label: "Manual",      icon: "ti-alert-triangle" },
];

const SEVERITIES = ["All", "Critical", "High", "Moderate", "Low"];

export default function Alerts() {
  const navigate = useNavigate();
  const [tab, setTab] = useState("stress");
  const [severityFilter, setSeverityFilter] = useState("All");
  const [stressAlerts, setStressAlerts] = useState([]);
  const [droneAlerts, setDroneAlerts] = useState([]);
  const [manualAlerts, setManualAlerts] = useState([]);

  useEffect(() => { loadAlerts(); }, []);

  async function loadAlerts() {
    try {
      const stress = await getNDVIStressAlerts();
      setStressAlerts(stress);
      const mapData = await getMapData();
      setDroneAlerts(mapData.filter((x) => x.source === "drone"));
      setManualAlerts(mapData.filter((x) => x.source === "manual"));
    } catch (err) {
      console.error(err);
    }
  }

  function applyFilter(list) {
    return severityFilter === "All" ? list : list.filter((a) => a.severity === severityFilter);
  }

  function viewOnMap(lat, lon) {
    navigate(`/map?lat=${lat}&lon=${lon}`);
  }

  const activeList = tab === "stress" ? stressAlerts : tab === "drone" ? droneAlerts : manualAlerts;
  const filtered = applyFilter(activeList);

  return (
    <div style={styles.page}>
      <div style={styles.pageHeader}>
        <div>
          <h1 style={styles.title}>Alerts</h1>
          <p style={styles.subtitle}>Field detections and stress events</p>
        </div>
        <select
          value={severityFilter}
          onChange={(e) => setSeverityFilter(e.target.value)}
          style={styles.select}
          aria-label="Filter by severity"
        >
          {SEVERITIES.map((s) => (
            <option key={s} value={s}>{s === "All" ? "All severities" : s}</option>
          ))}
        </select>
      </div>

      <div style={styles.tabBar} role="tablist">
        {TABS.map((t) => (
          <button
            key={t.key}
            role="tab"
            aria-selected={tab === t.key}
            onClick={() => setTab(t.key)}
            style={tab === t.key ? { ...styles.tab, ...styles.tabActive } : styles.tab}
          >
            <i className={`ti ${t.icon}`} style={{ fontSize: 14 }} aria-hidden="true" />
            {t.label}
          </button>
        ))}
      </div>

      <div style={styles.tableWrap}>
        {filtered.length === 0 ? (
          <div style={styles.empty}>
            <i className="ti ti-inbox" style={{ fontSize: 28, color: "#ccc", display: "block", marginBottom: 8 }} aria-hidden="true" />
            No alerts match this filter.
          </div>
        ) : (
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>Location</th>
                <th style={styles.th}>Details</th>
                <th style={styles.th}>Severity</th>
                <th style={styles.th} aria-label="Actions"></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr key={a.id} style={styles.tr}>
                  <td style={styles.td}>
                    <span style={styles.coords}>
                      {a.lat.toFixed(4)}, {a.lon.toFixed(4)}
                    </span>
                  </td>
                  <td style={styles.td}>
                    {tab === "stress" && (
                      <span>
                        Drop <strong>{a.drop}</strong> &mdash; {a.baseline_ndvi} → {a.current_ndvi}
                      </span>
                    )}
                    {tab === "drone" && (
                      <span><strong>{a.disease}</strong></span>
                    )}
                    {tab === "manual" && (
                      <span><strong>{a.disease}</strong> — {a.message}</span>
                    )}
                  </td>
                  <td style={styles.td}>
                    <span style={{ ...styles.badge, ...severityStyle(a.severity) }}>
                      {a.severity}
                    </span>
                  </td>
                  <td style={styles.td}>
                    <button
                      style={styles.viewBtn}
                      onClick={() => viewOnMap(a.lat, a.lon)}
                      aria-label={`View location ${a.lat.toFixed(4)}, ${a.lon.toFixed(4)} on map`}
                    >
                      <i className="ti ti-map-pin" style={{ fontSize: 13 }} aria-hidden="true" />
                      View
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

function severityStyle(sev) {
  if (sev === "Critical") return { background: "#FCEBEB", color: "#A32D2D" };
  if (sev === "High")     return { background: "#FAEEDA", color: "#854F0B" };
  if (sev === "Moderate") return { background: "#EAF3DE", color: "#3B6D11" };
  if (sev === "Low")      return { background: "#E6F1FB", color: "#185FA5" };
  return { background: "#F1EFE8", color: "#5F5E5A" };
}

const styles = {
  page: {
    padding: "24px 20px",
    color: "#1a1a1a",
  },
  pageHeader: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    marginBottom: 20,
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
  select: {
    padding: "7px 10px",
    borderRadius: 7,
    border: "0.5px solid #d0d0d0",
    fontSize: 13,
    color: "#333",
    background: "#fafafa",
    cursor: "pointer",
    outline: "none",
  },
  tabBar: {
    display: "flex",
    gap: 6,
    marginBottom: 16,
  },
  tab: {
    padding: "7px 14px",
    background: "transparent",
    border: "0.5px solid #d0d0d0",
    borderRadius: 7,
    fontSize: 13,
    fontWeight: 500,
    color: "#666",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    gap: 6,
    transition: "all 0.15s",
  },
  tabActive: {
    background: "#1B5E20",
    color: "#fff",
    borderColor: "#1B5E20",
  },
  tableWrap: {
    background: "#fff",
    borderRadius: 12,
    border: "0.5px solid rgba(0,0,0,0.1)",
    overflow: "hidden",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
  },
  th: {
    padding: "10px 14px",
    background: "#F7F8F5",
    textAlign: "left",
    fontSize: 12,
    fontWeight: 500,
    color: "#888",
    borderBottom: "0.5px solid rgba(0,0,0,0.08)",
    letterSpacing: "0.03em",
    textTransform: "uppercase",
  },
  tr: {
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  td: {
    padding: "11px 14px",
    fontSize: 13,
    color: "#333",
    verticalAlign: "middle",
  },
  coords: {
    fontFamily: "monospace",
    fontSize: 12,
    color: "#666",
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    padding: "3px 9px",
    borderRadius: 20,
    fontSize: 12,
    fontWeight: 500,
  },
  viewBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "5px 11px",
    background: "transparent",
    border: "0.5px solid #1B5E20",
    color: "#1B5E20",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
  },
  empty: {
    padding: "48px 20px",
    textAlign: "center",
    color: "#aaa",
    fontSize: 14,
  },
};
