import React, { useEffect, useState } from "react";
import { api } from "../services/api";

const CARDS = [
  {
    key:   "total",
    label: "Total detections",
    icon:  "ti-activity",
    color: "#1B5E20",
    bg:    "#EAF3DE",
    getValue: (s) => s?.detections?.total ?? 0,
    getSub:   (s) => `+${s?.detections?.today ?? 0} today`,
  },
  {
    key:   "high",
    label: "High / critical",
    icon:  "ti-alert-triangle",
    color: "#A32D2D",
    bg:    "#FCEBEB",
    getValue: (s) => s?.severity?.high ?? 0,
    getSub:   (s) => `${s?.alerts?.active ?? 0} active alerts`,
  },
  {
    key:   "moderate",
    label: "Moderate",
    icon:  "ti-minus-circle",
    color: "#854F0B",
    bg:    "#FAEEDA",
    getValue: (s) => s?.severity?.moderate ?? 0,
    getSub:   (s) => `${s?.detections?.this_week ?? 0} this week`,
  },
  {
    key:   "fields",
    label: "Registered fields",
    icon:  "ti-map-pin",
    color: "#185FA5",
    bg:    "#E6F1FB",
    getValue: (s) => s?.fields?.total ?? 0,
    getSub:   (s) => `${s?.ndvi_stress?.active ?? 0} NDVI stress alerts`,
  },
];

export default function StatsCards() {
  const [stats,   setStats]   = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const res = await api.get("/api/stats");
        setStats(res.data);
      } catch (e) {
        console.error("Stats load error:", e);
        setError(true);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  return (
    <div style={styles.grid}>
      {CARDS.map((c) => (
        <div key={c.key} style={styles.card}>
          <div style={{ ...styles.iconWrap, background: c.bg }}>
            <i
              className={`ti ${c.icon}`}
              style={{ fontSize: 18, color: c.color }}
              aria-hidden="true"
            />
          </div>
          <div style={styles.textWrap}>
            {loading ? (
              <div style={styles.skeleton} />
            ) : error ? (
              <div style={styles.value}>—</div>
            ) : (
              <>
                <div style={styles.value}>{c.getValue(stats).toLocaleString()}</div>
                <div style={styles.sub}>{c.getSub(stats)}</div>
              </>
            )}
            <div style={styles.label}>{c.label}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

const styles = {
  grid: {
    display: "grid",
    gridTemplateColumns: "repeat(4, 1fr)",
    gap: 12,
  },
  card: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.08)",
    borderRadius: 10,
    padding: "14px 16px",
    display: "flex",
    alignItems: "center",
    gap: 12,
  },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 8,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  textWrap: {
    flex: 1,
    minWidth: 0,
  },
  value: {
    fontSize: 22,
    fontWeight: 500,
    color: "#1a1a1a",
    lineHeight: 1.1,
  },
  sub: {
    fontSize: 11,
    color: "#1B5E20",
    marginTop: 1,
    fontWeight: 500,
  },
  label: {
    fontSize: 12,
    color: "#888",
    marginTop: 3,
  },
  skeleton: {
    height: 22,
    width: 48,
    background: "#f0f0f0",
    borderRadius: 4,
    marginBottom: 4,
  },
};


