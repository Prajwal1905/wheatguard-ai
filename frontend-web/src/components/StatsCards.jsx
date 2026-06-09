import React from "react";

export default function StatsCards({ detections }) {
  const total  = detections.length;
  const high   = detections.filter((d) => d.severity === "High" || d.severity === "Critical").length;
  const medium = detections.filter((d) => d.severity === "Medium" || d.severity === "Moderate").length;
  const low    = detections.filter((d) => d.severity === "Low").length;

  const cards = [
    { label: "Total detections", value: total,  icon: "ti-activity",       color: "#1B5E20", bg: "#EAF3DE" },
    { label: "High / critical",  value: high,   icon: "ti-alert-triangle", color: "#A32D2D", bg: "#FCEBEB" },
    { label: "Medium",           value: medium, icon: "ti-minus-circle",   color: "#854F0B", bg: "#FAEEDA" },
    { label: "Low",              value: low,    icon: "ti-check-circle",   color: "#185FA5", bg: "#E6F1FB" },
  ];

  return (
    <div style={styles.grid}>
      {cards.map((c) => (
        <div key={c.label} style={styles.card}>
          <div style={{ ...styles.iconWrap, background: c.bg }}>
            <i className={`ti ${c.icon}`} style={{ fontSize: 18, color: c.color }} aria-hidden="true" />
          </div>
          <div>
            <div style={styles.value}>{c.value}</div>
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
  value: {
    fontSize: 22,
    fontWeight: 500,
    color: "#1a1a1a",
    lineHeight: 1.1,
  },
  label: {
    fontSize: 12,
    color: "#888",
    marginTop: 2,
  },
};

