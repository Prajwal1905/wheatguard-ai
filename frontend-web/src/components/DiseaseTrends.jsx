import React from "react";
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from "recharts";

const COLORS = ["#1B5E20", "#f57c00", "#c62828", "#1565c0", "#6a1b9a", "#00838f"];

export default function DiseaseTrends({ detections }) {
  const data = Object.entries(
    detections.reduce((acc, d) => {
      if (d.disease) acc[d.disease] = (acc[d.disease] || 0) + 1;
      return acc;
    }, {})
  ).map(([name, value]) => ({ name, value }));

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <i className="ti ti-chart-pie" style={styles.headerIcon} aria-hidden="true" />
        <span style={styles.title}>Disease distribution</span>
      </div>

      {data.length === 0 ? (
        <div style={styles.empty}>
          <i className="ti ti-plant-off" style={{ fontSize: 24, color: "#ccc", display: "block", marginBottom: 6 }} aria-hidden="true" />
          No detections yet
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={220}>
          <PieChart>
            <Pie
              data={data}
              dataKey="value"
              nameKey="name"
              outerRadius={75}
              innerRadius={30}
              paddingAngle={2}
            >
              {data.map((_, i) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip
              contentStyle={{
                fontSize: 12,
                borderRadius: 8,
                border: "0.5px solid rgba(0,0,0,0.1)",
              }}
            />
            <Legend
              wrapperStyle={{ fontSize: 12, paddingTop: 8 }}
              iconType="circle"
              iconSize={8}
            />
          </PieChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

const styles = {
  card: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.08)",
    borderRadius: 12,
    padding: "16px",
  },
  header: {
    display: "flex",
    alignItems: "center",
    gap: 7,
    marginBottom: 12,
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
  empty: {
    textAlign: "center",
    color: "#aaa",
    fontSize: 13,
    padding: "32px 0",
  },
};
