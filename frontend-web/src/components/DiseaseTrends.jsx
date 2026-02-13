import React from "react";
import { PieChart, Pie, Cell, Tooltip, Legend } from "recharts";

export default function DiseaseTrends({ detections }) {
  const data = Object.entries(
    detections.reduce((acc, d) => {
      acc[d.disease] = (acc[d.disease] || 0) + 1;
      return acc;
    }, {})
  ).map(([name, value]) => ({ name, value }));

  const colors = ["#4caf50", "#ff9800", "#f44336", "#2196f3", "#9c27b0"];

  return (
    <div style={{ background: "#fff", padding: "20px", borderRadius: "10px", boxShadow: "0 2px 6px rgba(0,0,0,0.1)" }}>
      <h3>Disease Distribution</h3>
      <PieChart width={300} height={250}>
        <Pie data={data} dataKey="value" nameKey="name" outerRadius={80}>
          {data.map((_, i) => <Cell key={i} fill={colors[i % colors.length]} />)}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </div>
  );
}
