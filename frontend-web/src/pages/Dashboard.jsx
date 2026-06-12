import React, { useEffect, useState } from "react";
import { getMapData } from "../services/api";
import { socket } from "../services/socket";

import MapView from "../components/MapView";
import StatsCards from "../components/StatsCards";
import LiveFeedPanel from "../components/LiveFeedPanel";
import DiseaseTrends from "../components/DiseaseTrends";
import DailyTrendChart from "../components/DailyTrendChart";
import toast from "react-hot-toast";

export default function Dashboard() {
  const [detections, setDetections] = useState([]);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [loading, setLoading] = useState(false);

  const [filters, setFilters] = useState({
    severity: "All",
    disease:  "All",
    ndvi:     "All",
  });

  // Default to today's date in YYYY-MM-DD format
  const today = new Date().toISOString().split("T")[0];
  const [ndviDate, setNdviDate] = useState(today);

  useEffect(() => {
    fetchData();

    socket.on("new_detection", (data) => {
      setDetections((prev) => {
        if (prev.some((d) => d.id === data.id)) return prev;
        return [...prev, data];
      });
      toast.success(`New detection: ${data.disease} (${data.severity})`);
      if (data.severity === "High") {
        toast.error(`Critical hotspot near (${data.lat.toFixed(3)}, ${data.lon.toFixed(3)})`);
      }
    });

    return () => socket.off("new_detection");
  }, []);

  async function fetchData() {
    setLoading(true);
    try {
      const data = await getMapData();
      setDetections(data);
      setLastUpdated(new Date().toLocaleString());
    } catch (e) {
      console.error("Error fetching map data:", e);
    } finally {
      setLoading(false);
    }
  }

  const uniqueDiseases = [...new Set(detections.map((d) => d.disease).filter(Boolean))];

  const filteredDetections = detections.filter((d) => {
    const sevMatch  = filters.severity === "All" || d.severity === filters.severity;
    const disMatch  = filters.disease  === "All" || d.disease  === filters.disease;
    const ndviMatch = filters.ndvi     === "All" || (d.ndvi_category && d.ndvi_category === filters.ndvi);
    return sevMatch && disMatch && ndviMatch;
  });

  return (
    <div style={styles.layout}>
      {/* Left column */}
      <div style={styles.main}>
        <div style={styles.pageHeader}>
          <div>
            <h1 style={styles.title}>Overview</h1>
            {lastUpdated && (
              <p style={styles.lastUpdated}>
                <i className="ti ti-clock" style={{ fontSize: 12 }} aria-hidden="true" />
                Updated {lastUpdated}
              </p>
            )}
          </div>
          <button onClick={fetchData} disabled={loading} style={styles.refreshBtn}>
            <i className={`ti ${loading ? "ti-loader-2" : "ti-refresh"}`} style={{ fontSize: 14 }} aria-hidden="true" />
            {loading ? "Refreshing…" : "Refresh"}
          </button>
        </div>

        {/* Stat cards — fetch their own data from /api/stats */}
        <StatsCards />

        {/* Filter bar */}
        <div style={styles.filterBar}>
          <FilterSelect
            value={filters.severity}
            onChange={(v) => setFilters({ ...filters, severity: v })}
            icon="ti-alert-triangle"
            label="Severity"
            options={[
              { value: "All",      label: "All severities" },
              { value: "High",     label: "High" },
              { value: "Medium",   label: "Medium" },
              { value: "Low",      label: "Low" },
            ]}
          />
          <FilterSelect
            value={filters.disease}
            onChange={(v) => setFilters({ ...filters, disease: v })}
            icon="ti-virus"
            label="Disease"
            options={[
              { value: "All", label: "All diseases" },
              ...uniqueDiseases.map((d) => ({ value: d, label: d })),
            ]}
          />
          <FilterSelect
            value={filters.ndvi}
            onChange={(v) => setFilters({ ...filters, ndvi: v })}
            icon="ti-leaf"
            label="NDVI"
            options={[
              { value: "All",      label: "NDVI: all" },
              { value: "Healthy",  label: "Healthy" },
              { value: "Moderate", label: "Moderate" },
              { value: "Stressed", label: "Stressed" },
              { value: "Critical", label: "Critical" },
            ]}
          />
          <input
            type="date"
            value={ndviDate}
            onChange={(e) => setNdviDate(e.target.value)}
            style={styles.dateInput}
            aria-label="NDVI date"
          />
        </div>

        {/* Map */}
        <div style={styles.mapWrap}>
          <MapView
            detections={filteredDetections}
            ndviDate={ndviDate}
            polygonMode={false}
          />
        </div>
      </div>

      {/* Right sidebar */}
      <div style={styles.sidebar}>
        <DailyTrendChart />
        <DiseaseTrends detections={filteredDetections} />
        <LiveFeedPanel detections={filteredDetections} />
      </div>
    </div>
  );
}

function FilterSelect({ value, onChange, icon, label, options }) {
  return (
    <div style={filterStyles.wrap}>
      <i className={`ti ${icon}`} style={filterStyles.icon} aria-hidden="true" />
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        style={filterStyles.select}
        aria-label={label}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </div>
  );
}

const styles = {
  layout:     { display: "grid", gridTemplateColumns: "2fr 1fr", gap: 20, padding: 20, color: "#1a1a1a" },
  main:       { display: "flex", flexDirection: "column", gap: 16 },
  sidebar:    { display: "flex", flexDirection: "column", gap: 16 },
  pageHeader: { display: "flex", alignItems: "flex-start", justifyContent: "space-between" },
  title:      { fontSize: 20, fontWeight: 500, color: "#1a1a1a", margin: 0 },
  lastUpdated:{ fontSize: 12, color: "#999", marginTop: 4, display: "flex", alignItems: "center", gap: 4 },
  refreshBtn: { display: "inline-flex", alignItems: "center", gap: 6, padding: "7px 13px", background: "transparent", border: "0.5px solid #d0d0d0", borderRadius: 7, fontSize: 13, fontWeight: 500, color: "#444", cursor: "pointer" },
  filterBar:  { display: "flex", gap: 8, flexWrap: "wrap" },
  dateInput:  { padding: "7px 10px", borderRadius: 7, border: "0.5px solid #d0d0d0", fontSize: 13, color: "#333", background: "#fafafa", outline: "none", cursor: "pointer" },
  mapWrap:    { flex: 1, minHeight: 420, borderRadius: 12, overflow: "hidden", border: "0.5px solid rgba(0,0,0,0.08)" },
};

const filterStyles = {
  wrap:   { display: "flex", alignItems: "center", gap: 6, background: "#fafafa", border: "0.5px solid #d0d0d0", borderRadius: 7, padding: "0 8px" },
  icon:   { fontSize: 14, color: "#999" },
  select: { border: "none", background: "transparent", padding: "7px 4px", fontSize: 13, color: "#333", cursor: "pointer", outline: "none" },
};
