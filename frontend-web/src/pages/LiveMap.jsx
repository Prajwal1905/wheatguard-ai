import React, { useEffect, useState } from "react";
import MapView from "../components/MapView";
import {
  getMapData,
  getNDVIStressAlerts,
  getFields,        
} from "../services/api";
import { socket } from "../services/socket";
import toast from "react-hot-toast";
import { useSearchParams } from "react-router-dom";

import NDVIStressPanel from "../components/NDVIStressPanel";

export default function LiveMap() {
  const [detections, setDetections] = useState([]);
  const [fields, setFields] = useState([]); 

  const [filters, setFilters] = useState({
    severity: "All",
    disease: "All",
  });

  const [polygonMode, setPolygonMode] = useState(false);
  const [locatePoint, setLocatePoint] = useState(null);

  useEffect(() => {
    loadAllData();

    socket.on("new_detection", (d) => {
      setDetections((prev) =>
        prev.some((x) => x.id === d.id) ? prev : [...prev, d]
      );
      toast.success(`🌾 ${d.disease} (${d.severity}) detected`);
    });

    socket.on("ndvi_stress_update", (items) => {
      const newStress = items.map((s) => ({
        id: `stress-${s.id}`,
        lat: s.lat,
        lon: s.lon,
        disease: "NDVI Stress",
        severity: s.severity,
        drop: s.drop,
        baseline: s.baseline_ndvi,
        current: s.current_ndvi,
        type: "stress",
      }));

      setDetections((prev) => {
        const nonStress = prev.filter((p) => p.type !== "stress");
        return [...nonStress, ...newStress];
      });

      toast(`🌱 NDVI Stress Updated (${items.length} locations)`);
    });

    return () => {
      socket.off("new_detection");
      socket.off("ndvi_stress_update");
    };
  }, []);

  
  const [params] = useSearchParams();
  const urlLat = params.get("lat");
  const urlLon = params.get("lon");

  useEffect(() => {
    if (urlLat && urlLon) {
      setLocatePoint({
        lat: parseFloat(urlLat),
        lon: parseFloat(urlLon),
      });
    }
  }, [urlLat, urlLon]);

  useEffect(() => {
    if (locatePoint) loadAllData();
  }, [locatePoint]);

  async function loadAllData() {
    try {
      const det = await getMapData();
      const stress = await getNDVIStressAlerts();
      const flds = await getFields(); 

      
      const stressPoints = stress.map((s) => ({
        id: `stress-${s.id}`,
        lat: s.lat,
        lon: s.lon,
        severity: s.severity,
        disease: "NDVI Stress",
        drop: s.drop,
        baseline: s.baseline_ndvi,
        current: s.current_ndvi,
        type: "stress",
      }));

      setDetections([...det, ...stressPoints]);
      setFields(flds); 
    } catch (err) {
      console.error("Map data error:", err);
    }
  }

  const filtered = detections.filter((d) => {
    const severityOk =
      filters.severity === "All" || d.severity === filters.severity;
    const diseaseOk =
      filters.disease === "All" || d.disease === filters.disease;
    return severityOk && diseaseOk;
  });

  const uniqueDiseases = ["All", ...new Set(detections.map((d) => d.disease))];

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 15 }}>
        🌍 Live Disease Map —{" "}
        <span style={{ color: "#2e7d32" }}>
          NDVI (VIIRS + MODIS + Sentinel)
        </span>
      </h2>

      
      <NDVIStressPanel
        onLocate={(lat, lon) => setLocatePoint({ lat, lon })}
      />

      
      <div
        style={{
          display: "flex",
          gap: 10,
          marginBottom: 15,
          background: "#fff",
          padding: 12,
          borderRadius: 8,
          boxShadow: "0 0 5px rgba(0,0,0,0.2)",
        }}
      >
        <select
          value={filters.severity}
          onChange={(e) =>
            setFilters({ ...filters, severity: e.target.value })
          }
        >
          <option value="All">All Severities</option>
          <option value="High">High</option>
          <option value="Medium">Medium</option>
          <option value="Low">Low</option>
          <option value="Critical">Critical</option>
          <option value="Moderate">Moderate</option>
        </select>

        <select
          value={filters.disease}
          onChange={(e) =>
            setFilters({ ...filters, disease: e.target.value })
          }
        >
          {uniqueDiseases.map((d) => (
            <option key={d} value={d}>
              {d}
            </option>
          ))}
        </select>

        <button onClick={loadAllData}> Refresh </button>

        <button
          onClick={() => setPolygonMode(!polygonMode)}
          style={{
            background: polygonMode ? "#2196F3" : "#ddd",
            color: polygonMode ? "white" : "black",
          }}
        >
          {polygonMode ? "Drawing Field…" : "Draw Field (Polygon NDVI)"}
        </button>
      </div>

      
      <MapView
        detections={filtered}
        fields={fields}          
        polygonMode={polygonMode}
        forceCenter={locatePoint}
      />
    </div>
  );
}
