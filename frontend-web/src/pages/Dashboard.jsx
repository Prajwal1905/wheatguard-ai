import React, { useEffect, useState } from "react";
import { getMapData } from "../services/api";
import { socket } from "../services/socket";

import MapView from "../components/MapView";
import StatsCards from "../components/StatsCards";
import LiveFeedPanel from "../components/LiveFeedPanel";
import DiseaseTrends from "../components/DiseaseTrends";
import toast from "react-hot-toast";

export default function Dashboard() {
  const [detections, setDetections] = useState([]);
  const [lastUpdated, setLastUpdated] = useState(null);

 
  const [filters, setFilters] = useState({
    severity: "All",
    disease: "All",
    ndvi: "All",
  });

  
  const [ndviDate, setNdviDate] = useState("2024-11-14");

  useEffect(() => {
    fetchData();

    socket.on("new_detection", (data) => {
      setDetections((prev) => {
        if (prev.some((d) => d.id === data.id)) return prev;
        return [...prev, data];
      });

      toast.success(`🌾 New detection: ${data.disease} (${data.severity})`);

      if (data.severity === "High") {
        toast.error(
          `🚨 Critical hotspot detected near (${data.lat.toFixed(
            3
          )}, ${data.lon.toFixed(3)})`
        );
      }
    });

    return () => socket.off("new_detection");
  }, []);

  async function fetchData() {
    try {
      const data = await getMapData();
      setDetections(data);
      setLastUpdated(new Date().toLocaleString());
    } catch (e) {
      console.error("Error fetching map data:", e);
    }
  }

  const uniqueDiseases = [
    ...new Set(detections.map((d) => d.disease).filter(Boolean)),
  ];

  
  const filteredDetections = detections.filter((d) => {
    const sevMatch =
      filters.severity === "All" || d.severity === filters.severity;

    const disMatch =
      filters.disease === "All" || d.disease === filters.disease;

    const ndviMatch =
      filters.ndvi === "All" ||
      (d.ndvi_category && d.ndvi_category === filters.ndvi);

    return sevMatch && disMatch && ndviMatch;
  });

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "2fr 1fr",
        gap: "20px",
        padding: "10px",
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <h2 style={{color:"black"}}> Dashboard Overview</h2>
          <button
            onClick={fetchData}
            style={{
              background: "#1565c0",
              color: "#fff",
              padding: "6px 12px",
              borderRadius: "6px",
              border: "none",
              cursor: "pointer",
            }}
          >
            🔄 Refresh
          </button>
        </div>

        {lastUpdated && (
          <div style={{ fontSize: 13, color: "#333" }}>
            ⏱ Last updated: <b>{lastUpdated}</b>
          </div>
        )}

        <div style={{ display: "flex", gap: "10px" }}>
          
          <select
            value={filters.severity}
            onChange={(e) =>
              setFilters({ ...filters, severity: e.target.value })
            }
            style={selectStyle}
          >
            <option value="All">All Severities</option>
            <option value="High">High</option>
            <option value="Medium">Medium</option>
            <option value="Low">Low</option>
          </select>

          <select
            value={filters.disease}
            onChange={(e) =>
              setFilters({ ...filters, disease: e.target.value })
            }
            style={selectStyle}
          >
            <option value="All">All Diseases</option>
            {uniqueDiseases.map((d) => (
              <option key={d}>{d}</option>
            ))}
          </select>

          <select
            value={filters.ndvi}
            onChange={(e) =>
              setFilters({ ...filters, ndvi: e.target.value })
            }
            style={selectStyle}
          >
            <option value="All">NDVI: All</option>
            <option value="Healthy">Healthy</option>
            <option value="Moderate">Moderate</option>
            <option value="Stressed">Stressed</option>
            <option value="Critical">Critical</option>
          </select>

          
          <input
            type="date"
            value={ndviDate}
            onChange={(e) => setNdviDate(e.target.value)}
            style={selectStyle}
          />
        </div>

        <StatsCards detections={filteredDetections} />

        <div
          style={{
            flex: 1,
            minHeight: "420px",
            borderRadius: "10px",
            overflow: "hidden",
            background: "#f4f4f4",
            boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
          }}
        >
          <MapView
            detections={filteredDetections}
            ndviDate={ndviDate}   
            polygonMode={false}   
          />
        </div>
      </div>

      
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "20px",
          color: "black",
        }}
      >
        <DiseaseTrends detections={filteredDetections} />
        <LiveFeedPanel detections={filteredDetections} />
      </div>
    </div>
  );
}

const selectStyle = {
  padding: "8px 10px",
  borderRadius: "6px",
  border: "1px solid #bbb",
  fontSize: "14px",
};
