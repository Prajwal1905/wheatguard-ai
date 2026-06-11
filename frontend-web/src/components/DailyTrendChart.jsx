import React, { useEffect, useState } from "react";
import { api } from "../services/api";
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer,
} from "recharts";

export default function DailyTrendChart() {
  const [data,    setData]    = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(false);
  const [range,   setRange]   = useState(14); // 7 or 14 days

  useEffect(() => {
    async function load() {
      setLoading(true);
      setError(false);
      try {
        const res = await api.get("/api/stats");
        const trend = res.data?.daily_trend || [];
        setData(trend);
      } catch {
        setError(true);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const displayed = data.slice(-range);

  const total = displayed.reduce((sum, d) => sum + d.count, 0);
  const peak  = displayed.length
    ? displayed.reduce((max, d) => (d.count > max.count ? d : max), displayed[0])
    : null;

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <i className="ti ti-chart-area" style={styles.headerIcon} aria-hidden="true" />
          <div>
            <div style={styles.title}>Detection trend</div>
            {!loading && !error && displayed.length > 0 && (
              <div style={styles.subtitle}>
                {total} detection{total !== 1 ? "s" : ""} in last {range} days
                {peak && peak.count > 0 && ` — peak: ${peak.count} on ${peak.date}`}
              </div>
            )}
          </div>
        </div>
        <div style={styles.rangeToggle}>
          {[7, 14].map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              style={{ ...styles.rangeBtn, ...(range === r ? styles.rangeBtnActive : {}) }}
            >
              {r}d
            </button>
          ))}
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
            <i className="ti ti-alert-circle" style={{ fontSize: 22, color: "#A32D2D" }} aria-hidden="true" />
            <span style={{ fontSize: 12, color: "#A32D2D", marginTop: 4 }}>Failed to load trend</span>
          </div>
        )}

        {!loading && !error && displayed.length === 0 && (
          <div style={styles.center}>
            <i className="ti ti-chart-off" style={{ fontSize: 22, color: "#ccc" }} aria-hidden="true" />
            <span style={{ fontSize: 12, color: "#aaa", marginTop: 4 }}>No detection data yet</span>
          </div>
        )}

        {!loading && !error && displayed.length > 0 && (
          <ResponsiveContainer width="100%" height={160}>
            <AreaChart data={displayed} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
              <defs>
                <linearGradient id="trendGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#1B5E20" stopOpacity={0.15} />
                  <stop offset="95%" stopColor="#1B5E20" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.05)" />
              <XAxis
                dataKey="date"
                tick={{ fontSize: 10, fill: "#aaa" }}
                tickFormatter={(v) => v.slice(5)} // show MM-DD only
              />
              <YAxis
                allowDecimals={false}
                tick={{ fontSize: 10, fill: "#aaa" }}
                width={28}
              />
              <Tooltip
                contentStyle={{
                  fontSize: 12, borderRadius: 8,
                  border: "0.5px solid rgba(0,0,0,0.1)",
                  boxShadow: "0 2px 8px rgba(0,0,0,0.08)",
                }}
                formatter={(v) => [v, "Detections"]}
                labelFormatter={(l) => `Date: ${l}`}
              />
              <Area
                type="monotone"
                dataKey="count"
                stroke="#1B5E20"
                strokeWidth={2}
                fill="url(#trendGradient)"
                dot={{ r: 3, fill: "#1B5E20", strokeWidth: 0 }}
                activeDot={{ r: 5 }}
                name="Detections"
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
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
  rangeToggle: {
    display: "flex",
    gap: 4,
  },
  rangeBtn: {
    fontSize: 11,
    padding: "3px 8px",
    borderRadius: 5,
    border: "0.5px solid #d0d0d0",
    background: "transparent",
    color: "#888",
    cursor: "pointer",
    fontWeight: 500,
  },
  rangeBtnActive: {
    background: "#1B5E20",
    color: "#fff",
    borderColor: "#1B5E20",
  },
  chartWrap: {
    padding: "12px 8px 8px",
    minHeight: 180,
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
};
