import React, { useEffect, useState } from "react";
import { getMapData } from "../services/api";

import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  PieChart, Pie, Cell, Legend,
} from "recharts";

import Papa from "papaparse";
import { saveAs } from "file-saver";
import jsPDF from "jspdf";
import html2canvas from "html2canvas";

const COLORS = ["#1B5E20", "#f57c00", "#c62828", "#1565c0", "#6a1b9a"];

export default function Reports() {
  const [detections, setDetections] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => { fetchReports(); }, []);

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

  const pieData = Object.entries(diseaseCount).map(([name, value]) => ({ name, value }));

  const trend = detections.reduce((acc, d) => {
    const date = new Date(d.timestamp).toLocaleDateString("en-IN", {
      month: "short", day: "2-digit",
    });
    acc[date] = (acc[date] || 0) + 1;
    return acc;
  }, {});

  const trendData = Object.entries(trend).map(([date, count]) => ({ date, count }));

  return (
    <div style={styles.page}>
      <div style={styles.pageHeader}>
        <div>
          <h1 style={styles.title}>Reports & analytics</h1>
          <p style={styles.subtitle}>Detection trends and disease distribution</p>
        </div>
        <div style={styles.actions}>
          <button onClick={fetchReports} disabled={loading} style={styles.btnGhost}>
            <i className="ti ti-refresh" style={{ fontSize: 14 }} aria-hidden="true" />
            {loading ? "Loading…" : "Refresh"}
          </button>
          <button onClick={exportCSV} style={styles.btnGhost}>
            <i className="ti ti-table-export" style={{ fontSize: 14 }} aria-hidden="true" />
            Export CSV
          </button>
          <button onClick={exportPDF} style={styles.btnPrimary}>
            <i className="ti ti-file-type-pdf" style={{ fontSize: 14 }} aria-hidden="true" />
            Export PDF
          </button>
        </div>
      </div>

      <div id="report-section" style={styles.grid}>
        <div style={styles.card}>
          <h2 style={styles.cardTitle}>
            <i className="ti ti-chart-pie" style={styles.cardIcon} aria-hidden="true" />
            Disease distribution
          </h2>
          <PieChart width={340} height={280}>
            <Pie data={pieData} dataKey="value" nameKey="name" outerRadius={95}>
              {pieData.map((_, i) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Pie>
            <Legend wrapperStyle={{ fontSize: 12 }} />
            <Tooltip />
          </PieChart>
        </div>

        <div style={styles.card}>
          <h2 style={styles.cardTitle}>
            <i className="ti ti-chart-line" style={styles.cardIcon} aria-hidden="true" />
            Daily detection trend
          </h2>
          <LineChart width={380} height={280} data={trendData}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
            <XAxis dataKey="date" tick={{ fontSize: 11 }} />
            <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
            <Tooltip />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            <Line type="monotone" dataKey="count" stroke="#1B5E20" strokeWidth={2} dot={false} />
          </LineChart>
        </div>
      </div>
    </div>
  );
}

const styles = {
  page: {
    padding: "24px 20px",
    color: "#1a1a1a",
  },
  pageHeader: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12,
  },
  title: {
    fontSize: 20,
    fontWeight: 500,
    color: "#1a1a1a",
    margin: 0,
  },
  subtitle: {
    fontSize: 13,
    color: "#888",
    marginTop: 3,
  },
  actions: {
    display: "flex",
    gap: 8,
  },
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
  grid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 20,
  },
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
  cardIcon: {
    fontSize: 15,
    color: "#1B5E20",
  },
};
