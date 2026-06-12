import React, { useEffect, useState, useMemo } from "react";
import SourceBreakdownChart from "../components/SourceBreakdownChart";
import { getMapData } from "../services/api";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  Legend,
  ResponsiveContainer,
} from "recharts";

import Papa from "papaparse";
import { saveAs } from "file-saver";
import jsPDF from "jspdf";
import html2canvas from "html2canvas";

const COLORS = [
  "#1B5E20",
  "#f57c00",
  "#c62828",
  "#1565c0",
  "#6a1b9a",
  "#00838f",
];

export default function Reports() {
  const [detections, setDetections] = useState([]);
  const [loading, setLoading] = useState(false);

  // Filters
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [disease, setDisease] = useState("All");
  const [severity, setSeverity] = useState("All");

  useEffect(() => {
    fetchReports();
  }, []);

  async function fetchReports() {
    setLoading(true);
    try {
      const data = await getMapData(true);
      setDetections(data);
    } catch (err) {
      console.error("Error loading reports:", err);
    } finally {
      setLoading(false);
    }
  }

  // Unique disease list for filter dropdown
  const uniqueDiseases = useMemo(
    () => ["All", ...new Set(detections.map((d) => d.disease).filter(Boolean))],
    [detections],
  );

  // Apply filters
  const filtered = useMemo(() => {
    return detections.filter((d) => {
      const ts = new Date(d.timestamp);

      if (dateFrom && ts < new Date(dateFrom)) return false;
      if (dateTo && ts > new Date(dateTo + "T23:59:59")) return false;
      if (disease !== "All" && d.disease !== disease) return false;
      if (severity !== "All" && d.severity !== severity) return false;

      return true;
    });
  }, [detections, dateFrom, dateTo, disease, severity]);

  const activeFilters =
    (dateFrom ? 1 : 0) +
    (dateTo ? 1 : 0) +
    (disease !== "All" ? 1 : 0) +
    (severity !== "All" ? 1 : 0);

  const resolvedCount = filtered.filter((d) => d.is_resolved).length;

  function clearFilters() {
    setDateFrom("");
    setDateTo("");
    setDisease("All");
    setSeverity("All");
  }

  // CSV export filtered data only
  function exportCSV() {
    if (!filtered.length) return;
    const csv = Papa.unparse(filtered);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    saveAs(
      blob,
      `WheatGuard_Report_${new Date().toISOString().slice(0, 10)}.csv`,
    );
  }

  // PDF export charts section
  async function exportPDF() {
    const element = document.getElementById("report-charts");
    const canvas = await html2canvas(element, { scale: 2 });
    const img = canvas.toDataURL("image/png");
    const pdf = new jsPDF("p", "mm", "a4");
    const width = pdf.internal.pageSize.getWidth();
    const height = (canvas.height * width) / canvas.width;
    pdf.addImage(img, "PNG", 0, 0, width, height);
    pdf.save(`WheatGuard_Report_${new Date().toISOString().slice(0, 10)}.pdf`);
  }

  // Chart data — computed from filtered
  const diseaseCount = filtered.reduce((acc, d) => {
    if (d.disease) acc[d.disease] = (acc[d.disease] || 0) + 1;
    return acc;
  }, {});
  const pieData = Object.entries(diseaseCount).map(([name, value]) => ({
    name,
    value,
  }));

  const trend = filtered.reduce((acc, d) => {
    const date = new Date(d.timestamp).toLocaleDateString("en-IN", {
      month: "short",
      day: "2-digit",
    });
    acc[date] = (acc[date] || 0) + 1;
    return acc;
  }, {});
  const trendData = Object.entries(trend)
    .map(([date, count]) => ({ date, count }))
    .slice(-14); // last 14 days

  const severityCount = filtered.reduce((acc, d) => {
    if (d.severity) acc[d.severity] = (acc[d.severity] || 0) + 1;
    return acc;
  }, {});

  return (
    <div style={styles.page}>
      <div style={styles.pageHeader}>
        <div>
          <h1 style={styles.title}>Reports & analytics</h1>
          <p style={styles.subtitle}>
            {filtered.length} detection{filtered.length !== 1 ? "s" : ""}
            {activeFilters > 0
              ? ` (${activeFilters} filter${activeFilters > 1 ? "s" : ""} active)`
              : ""}
            {resolvedCount > 0 ? ` · ${resolvedCount} resolved` : ""}
          </p>
        </div>
        <div style={styles.actions}>
          <button
            onClick={fetchReports}
            disabled={loading}
            style={styles.btnGhost}
          >
            <i
              className="ti ti-refresh"
              style={{ fontSize: 14 }}
              aria-hidden="true"
            />
            {loading ? "Loading…" : "Refresh"}
          </button>
          <button
            onClick={exportCSV}
            disabled={!filtered.length}
            style={styles.btnGhost}
          >
            <i
              className="ti ti-table-export"
              style={{ fontSize: 14 }}
              aria-hidden="true"
            />
            Export CSV
          </button>
          <button
            onClick={exportPDF}
            disabled={!filtered.length}
            style={styles.btnPrimary}
          >
            <i
              className="ti ti-file-type-pdf"
              style={{ fontSize: 14 }}
              aria-hidden="true"
            />
            Export PDF
          </button>
        </div>
      </div>

      <div style={styles.filterBar}>
        <div style={styles.filterGroup}>
          <label style={styles.filterLabel} htmlFor="date-from">
            From
          </label>
          <input
            id="date-from"
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            style={styles.filterInput}
          />
        </div>
        <div style={styles.filterGroup}>
          <label style={styles.filterLabel} htmlFor="date-to">
            To
          </label>
          <input
            id="date-to"
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            style={styles.filterInput}
          />
        </div>
        <div style={styles.filterGroup}>
          <label style={styles.filterLabel} htmlFor="filter-disease">
            Disease
          </label>
          <select
            id="filter-disease"
            value={disease}
            onChange={(e) => setDisease(e.target.value)}
            style={styles.filterInput}
          >
            {uniqueDiseases.map((d) => (
              <option key={d} value={d}>
                {d === "All" ? "All diseases" : d}
              </option>
            ))}
          </select>
        </div>
        <div style={styles.filterGroup}>
          <label style={styles.filterLabel} htmlFor="filter-severity">
            Severity
          </label>
          <select
            id="filter-severity"
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
            style={styles.filterInput}
          >
            {["All", "High", "Moderate", "Low"].map((s) => (
              <option key={s} value={s}>
                {s === "All" ? "All severities" : s}
              </option>
            ))}
          </select>
        </div>
        {activeFilters > 0 && (
          <button onClick={clearFilters} style={styles.clearBtn}>
            <i
              className="ti ti-x"
              style={{ fontSize: 13 }}
              aria-hidden="true"
            />
            Clear filters
          </button>
        )}
      </div>

      <div style={styles.statRow}>
        {Object.entries(severityCount).map(([sev, count]) => (
          <div
            key={sev}
            style={{ ...styles.statPill, ...severityPillStyle(sev) }}
          >
            {sev}: <strong>{count}</strong>
          </div>
        ))}
        {filtered.length > 0 && (
          <div style={styles.statPill}>
            Sources:{" "}
            {[...new Set(filtered.map((d) => d.source).filter(Boolean))].join(
              ", ",
            ) || "—"}
          </div>
        )}
      </div>

      {filtered.length === 0 ? (
        <div style={styles.empty}>
          <i
            className="ti ti-chart-off"
            style={{
              fontSize: 32,
              color: "#ccc",
              display: "block",
              marginBottom: 8,
            }}
            aria-hidden="true"
          />
          No data matches the current filters.
        </div>
      ) : (
        <div id="report-charts" style={styles.grid}>
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>
              <i
                className="ti ti-chart-pie"
                style={styles.cardIcon}
                aria-hidden="true"
              />
              Disease distribution
            </h2>
            <ResponsiveContainer width="100%" height={260}>
              <PieChart>
                <Pie
                  data={pieData}
                  dataKey="value"
                  nameKey="name"
                  outerRadius={90}
                  innerRadius={35}
                  paddingAngle={2}
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Legend
                  wrapperStyle={{ fontSize: 12 }}
                  iconType="circle"
                  iconSize={8}
                />
                <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div style={styles.card}>
            <h2 style={styles.cardTitle}>
              <i
                className="ti ti-chart-line"
                style={styles.cardIcon}
                aria-hidden="true"
              />
              Daily detection trend
            </h2>
            <ResponsiveContainer width="100%" height={260}>
              <LineChart
                data={trendData}
                margin={{ top: 4, right: 4, bottom: 0, left: -16 }}
              >
                <CartesianGrid
                  strokeDasharray="3 3"
                  stroke="rgba(0,0,0,0.06)"
                />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
                <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Line
                  type="monotone"
                  dataKey="count"
                  stroke="#1B5E20"
                  strokeWidth={2}
                  dot={false}
                  name="Detections"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      <div style={{ marginTop: 20 }}>
        <SourceBreakdownChart />
      </div>
    </div>
  );
}

function severityPillStyle(sev) {
  if (sev === "High") return { background: "#FCEBEB", color: "#A32D2D" };
  if (sev === "Moderate") return { background: "#FAEEDA", color: "#854F0B" };
  return { background: "#EAF3DE", color: "#3B6D11" };
}

const styles = {
  page: { padding: "24px 20px", color: "#1a1a1a" },
  pageHeader: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    marginBottom: 20,
    flexWrap: "wrap",
    gap: 12,
  },
  title: { fontSize: 20, fontWeight: 500, color: "#1a1a1a", margin: 0 },
  subtitle: { fontSize: 13, color: "#888", marginTop: 3 },
  actions: { display: "flex", gap: 8, flexWrap: "wrap" },
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
  btnPrimary: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    padding: "7px 12px",
    background: "#1B5E20",
    border: "none",
    borderRadius: 7,
    fontSize: 13,
    fontWeight: 500,
    color: "#fff",
    cursor: "pointer",
  },
  filterBar: {
    display: "flex",
    gap: 12,
    flexWrap: "wrap",
    alignItems: "flex-end",
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.08)",
    borderRadius: 10,
    padding: "12px 16px",
    marginBottom: 16,
  },
  filterGroup: { display: "flex", flexDirection: "column", gap: 4 },
  filterLabel: {
    fontSize: 11,
    fontWeight: 500,
    color: "#888",
    textTransform: "uppercase",
    letterSpacing: "0.03em",
  },
  filterInput: {
    padding: "7px 10px",
    borderRadius: 7,
    border: "0.5px solid #d0d0d0",
    fontSize: 13,
    color: "#333",
    background: "#fafafa",
    outline: "none",
    cursor: "pointer",
  },
  clearBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "7px 10px",
    background: "#FCEBEB",
    border: "0.5px solid #F7C1C1",
    color: "#A32D2D",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
    alignSelf: "flex-end",
  },
  statRow: { display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 16 },
  statPill: {
    padding: "4px 12px",
    borderRadius: 20,
    fontSize: 12,
    background: "#F1EFE8",
    color: "#555",
  },
  grid: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 },
  card: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.1)",
    borderRadius: 12,
    padding: "16px 20px",
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
    marginBottom: 14,
    display: "flex",
    alignItems: "center",
    gap: 7,
  },
  cardIcon: { fontSize: 15, color: "#1B5E20" },
  empty: {
    textAlign: "center",
    padding: "64px 20px",
    color: "#aaa",
    fontSize: 14,
  },
};
