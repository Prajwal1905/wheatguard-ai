// src/pages/Reports.jsx
import React, { useEffect, useState } from "react";

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
} from "recharts";

import Papa from "papaparse";
import { saveAs } from "file-saver";
import jsPDF from "jspdf";
import html2canvas from "html2canvas";


const card = {
  background: "#fff",
  padding: "20px",
  borderRadius: "10px",
  boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
};

const btn = {
  background: "#1565c0",
  color: "white",
  padding: "8px 14px",
  borderRadius: "6px",
  border: "none",
  cursor: "pointer",
};

const colors = ["#4caf50", "#ff9800", "#f44336", "#2196f3", "#9c27b0"];

export default function Reports() {
  const [detections, setDetections] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchReports();
  }, []);

  async function fetchReports() {
    setLoading(true);

    try {
      const data = await getMapData();
      setDetections(data);
    } catch (err) {
      console.error("Error loading reports:", err);
    } finally {
      setLoading(false);
    }
  }

  
  function exportCSV() {
    const csv = Papa.unparse(detections);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    saveAs(blob, "WheatGuard_Report.csv");
  }

  
  async function exportPDF() {
    const element = document.getElementById("report-section");

    const canvas = await html2canvas(element, { scale: 2 });
    const img = canvas.toDataURL("image/png");

    const pdf = new jsPDF("p", "mm", "a4");
    const width = pdf.internal.pageSize.getWidth();
    const height = (canvas.height * width) / canvas.width;

    pdf.addImage(img, "PNG", 0, 0, width, height);
    pdf.save("WheatGuard_Report.pdf");
  }


  const diseaseCount = detections.reduce((acc, d) => {
    acc[d.disease] = (acc[d.disease] || 0) + 1;
    return acc;
  }, {});

  const pieData = Object.entries(diseaseCount).map(([name, value]) => ({
    name,
    value,
  }));

  const trend = detections.reduce((acc, d) => {
    const date = new Date(d.timestamp).toLocaleDateString("en-IN", {
      month: "short",
      day: "2-digit",
    });
    acc[date] = (acc[date] || 0) + 1;
    return acc;
  }, {});

  const trendData = Object.entries(trend).map(([date, count]) => ({
    date,
    count,
  }));

  return (
    
      <div style={{ padding: "20px", width: "100%" }}>
        <h2 style={{ fontWeight: "bold", marginBottom: 15 }}>
          📊 Reports & Analytics
        </h2>

        {/* Action Buttons */}
        <div style={{ display: "flex", gap: "10px", marginBottom: "20px" }}>
          <button onClick={fetchReports} disabled={loading} style={btn}>
            🔄 {loading ? "Refreshing..." : "Refresh"}
          </button>

          <button onClick={exportCSV} style={btn}>
            ⬇️ Export CSV
          </button>

          <button onClick={exportPDF} style={btn}>
            📄 Export PDF
          </button>
        </div>

        
        <div id="report-section">
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr",
              gap: "20px",
            }}
          >
            
            <div style={card}>
              <h3>Disease Distribution</h3>
              <PieChart width={350} height={300}>
                <Pie
                  data={pieData}
                  dataKey="value"
                  nameKey="name"
                  outerRadius={100}
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={colors[i % colors.length]} />
                  ))}
                </Pie>
                <Legend />
                <Tooltip />
              </PieChart>
            </div>

            
            <div style={card}>
              <h3>Daily Detection Trend</h3>
              <LineChart width={400} height={300} data={trendData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="count" stroke="#2e7d32" />
              </LineChart>
            </div>
          </div>
        </div>
      </div>
    
  );
}
