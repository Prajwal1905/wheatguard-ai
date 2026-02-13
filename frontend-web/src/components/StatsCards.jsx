import React from "react";
import { Card, CardContent, Typography } from "@mui/material";

export default function StatsCards({ detections }) {
  const total = detections.length;
  const high = detections.filter(d => d.severity === "High").length;
  const medium = detections.filter(d => d.severity === "Medium").length;
  const low = detections.filter(d => d.severity === "Low").length;

  return (
    <div style={{ display: "flex", gap: "16px", marginBottom: "20px" }}>
      <Card><CardContent><Typography variant="h6">Total Reports: {total}</Typography></CardContent></Card>
      <Card><CardContent><Typography variant="h6" color="red">High: {high}</Typography></CardContent></Card>
      <Card><CardContent><Typography variant="h6" color="orange">Medium: {medium}</Typography></CardContent></Card>
      <Card><CardContent><Typography variant="h6" color="green">Low: {low}</Typography></CardContent></Card>
    </div>
  );
}
