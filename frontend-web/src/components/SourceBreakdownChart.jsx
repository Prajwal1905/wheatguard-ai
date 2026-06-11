import React, { useEffect, useState } from "react";
import { api } from "../services/api";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Cell,
} from "recharts";

const SOURCE_COLORS = {
  mobile:        "#1B5E20",
  drone:         "#1565c0",
  manual:        "#854F0B",
  "local-mobile": "#6a1b9a",
};

const DISEASE_COLORS = [
  "#1B5E20", "#1565c0", "#c62828",
  "#854F0B", "#6a1b9a", "#00838f",
];

export default function SourceBreakdownChart() {
  const [stats,   setStats]   = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(false);
  const [view,    setView]    = useState("source"); // "source" | "disease"

  useEffect(() => {
    api.get("/api/stats")
      .then((res) => { setStats(res.data); setLoading(false); })
      .catch(() => { setError(true); setLoading(false); });
  }, []);

  const sourceData = stats
    ? Object.entries(stats.sources || {}).map(([name, count]) => ({ name, count }))
    : [];

  const diseaseData = stats?.top_diseases || [];

  const activeData   = view === "source" ? sourceData   : diseaseData;
  const activeKey    = view === "source" ? "count"      : "count";
  const activeLabel  = view === "source" ? "name"       : "disease";
  const activeColors = view === "source" ? SOURCE_COLORS : null;

  const total = activeData.reduce((s, d) => s + d.count, 0);

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <i className="ti ti-chart-bar" style={styles.headerIcon} aria-hidden="true" />
          <div>
            <div style={styles.title}>
              {view === "source" ? "Detection sources" : "Top diseases"}
            </div>
            {!loading && !error && (
              <div style={styles.subtitle}>{total} total</div>
            )}
          </div>
        </div>
        <div style={styles.toggle}>
          <button
            onClick={() => setView("source")}
            style={{ ...styles.toggleBtn, ...(view === "source" ? styles.toggleActive : {}) }}
          >
            <i className="ti ti-device-mobile" style={{ fontSize: 12 }} aria-hidden="true" />
            Sources
          </button>
          <button
            onClick={() => setView("disease")}
            style={{ ...styles.toggleBtn, ...(view === "disease" ? styles.toggleActive : {}) }}
          >
            <i className="ti ti-virus" style={{ fontSize: 12 }} aria-hidden="true" />
            Diseases
          </button>
        </div>
      </div>

      <div style={styles.chartWrap}>
        {loading && (
          <div style={styles.center}>
            <i className="ti ti-loader-2" style={{ fontSize: 22, color: "#ccc" }} aria-hidden="true" />
          </div>
        )}

        {error && (
          <div style={styles.center}>
            <i className="ti ti-alert-circle" style={{ fontSize: 20, color: "#A32D2D" }} aria-hidden="true" />
            <span style={{ fontSize: 12, color: "#A32D2D", marginTop: 4 }}>Failed to load</span>
          </div>
        )}

        {!loading && !error && activeData.length === 0 && (
          <div style={styles.center}>
            <i className="ti ti-chart-off" style={{ fontSize: 22, color: "#ccc" }} aria-hidden="true" />
            <span style={{ fontSize: 12, color: "#aaa", marginTop: 4 }}>No data yet</span>
          </div>
        )}

        {!loading && !error && activeData.length > 0 && (
          <ResponsiveContainer width="100%" height={200}>
            <BarChart
              data={activeData}
              layout="vertical"
              margin={{ top: 4, right: 24, bottom: 0, left: 8 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.05)" horizontal={false} />
              <XAxis
                type="number"
                allowDecimals={false}
                tick={{ fontSize: 10, fill: "#aaa" }}
              />
              <YAxis
                type="category"
                dataKey={activeLabel}
                tick={{ fontSize: 11, fill: "#555" }}
                width={90}
                tickFormatter={(v) =>
                  v.length > 12 ? v.slice(0, 12) + "…" : v
                }
              />
              <Tooltip
                contentStyle={{
                  fontSize: 12, borderRadius: 8,
                  border: "0.5px solid rgba(0,0,0,0.1)",
                }}
                formatter={(v) => [v, "Detections"]}
              />
              <Bar dataKey={activeKey} radius={[0, 4, 4, 0]} maxBarSize={22}>
                {activeData.map((entry, i) => (
                  <Cell
                    key={i}
                    fill={
                      activeColors
                        ? (activeColors[entry.name] || "#888")
                        : DISEASE_COLORS[i % DISEASE_COLORS.length]
                    }
                  />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      
      {!loading && !error && activeData.length > 0 && (
        <div style={styles.legend}>
          {activeData.map((entry, i) => {
            const color = activeColors
              ? (activeColors[entry.name] || "#888")
              : DISEASE_COLORS[i % DISEASE_COLORS.length];
            const pct = total > 0 ? Math.round((entry.count / total) * 100) : 0;
            return (
              <div key={i} style={styles.legendItem}>
                <span style={{ ...styles.legendDot, background: color }} />
                <span style={styles.legendLabel}>
                  {entry[activeLabel]}
                </span>
                <span style={styles.legendCount}>{entry.count}</span>
                <span style={styles.legendPct}>{pct}%</span>
              </div>
            );
          })}
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
    overflow: "hidden",
  },
  header: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    padding: "12px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  headerLeft: {
    display: "flex",
    alignItems: "flex-start",
    gap: 8,
  },
  headerIcon: {
    fontSize: 15,
    color: "#1B5E20",
    marginTop: 2,
  },
  title: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
  },
  subtitle: {
    fontSize: 11,
    color: "#888",
    marginTop: 2,
  },
  toggle: {
    display: "flex",
    gap: 4,
  },
  toggleBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 4,
    fontSize: 11,
    padding: "4px 8px",
    borderRadius: 6,
    border: "0.5px solid #d0d0d0",
    background: "transparent",
    color: "#888",
    cursor: "pointer",
    fontWeight: 500,
  },
  toggleActive: {
    background: "#1B5E20",
    color: "#fff",
    borderColor: "#1B5E20",
  },
  chartWrap: {
    padding: "12px 8px 4px",
    minHeight: 160,
    display: "flex",
    flexDirection: "column",
    justifyContent: "center",
  },
  center: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    height: 160,
  },
  legend: {
    padding: "8px 16px 12px",
    display: "flex",
    flexDirection: "column",
    gap: 5,
    borderTop: "0.5px solid rgba(0,0,0,0.06)",
  },
  legendItem: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    fontSize: 12,
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: "50%",
    flexShrink: 0,
  },
  legendLabel: {
    flex: 1,
    color: "#444",
    textTransform: "capitalize",
  },
  legendCount: {
    fontWeight: 500,
    color: "#1a1a1a",
    minWidth: 24,
    textAlign: "right",
  },
  legendPct: {
    fontSize: 11,
    color: "#aaa",
    minWidth: 32,
    textAlign: "right",
  },
};
