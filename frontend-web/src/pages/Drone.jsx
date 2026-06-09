import React, { useEffect, useState } from "react";
import DroneUpload from "../components/DroneUpload";
import DronePreview from "../components/DronePreview";
import DroneDetections from "../components/DroneDetections";
import { analyzeDroneImage } from "../services/api";

export default function Drone() {
  const [file, setFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [location, setLocation] = useState({ lat: "", lon: "" });
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState("");
  const [lastResult, setLastResult] = useState(null);
  const [history, setHistory] = useState([]);

  useEffect(() => {
    if (!file) { setPreviewUrl(null); return; }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const handleUseMyLocation = () => {
    if (!navigator.geolocation) {
      setError("Geolocation is not supported in this browser.");
      return;
    }
    setError("");
    navigator.geolocation.getCurrentPosition(
      (pos) => setLocation({
        lat: pos.coords.latitude.toFixed(6),
        lon: pos.coords.longitude.toFixed(6),
      }),
      () => setError("Unable to fetch your location.")
    );
  };

  const handleClear = () => {
    setFile(null);
    setPreviewUrl(null);
    setLastResult(null);
    setError("");
  };

  const handleAnalyze = async () => {
    if (!file) { setError("Please select an image first."); return; }
    if (!location.lat || !location.lon) { setError("Please provide field coordinates."); return; }

    setError("");
    setIsAnalyzing(true);
    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("lat", location.lat);
      formData.append("lon", location.lon);
      const data = await analyzeDroneImage(formData);
      setLastResult(data);
      if (data?.detection) setHistory((prev) => [data.detection, ...prev]);
    } catch (e) {
      console.error(e);
      setError("Analysis failed. Please try again.");
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <div style={styles.page}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>
            <i className="ti ti-drone" style={styles.titleIcon} aria-hidden="true" />
            Drone analysis
          </h1>
          <p style={styles.subtitle}>Upload field images to detect disease and map hotspots</p>
        </div>
      </div>

      {error && (
        <div style={styles.errorBox}>
          <i className="ti ti-alert-circle" style={{ fontSize: 14 }} aria-hidden="true" />
          {error}
        </div>
      )}

      <div style={styles.grid}>
        <div>
          <DroneUpload
            file={file}
            setFile={setFile}
            location={location}
            setLocation={setLocation}
            onUseMyLocation={handleUseMyLocation}
          />
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <DronePreview
            file={file}
            previewUrl={previewUrl}
            location={location}
            onAnalyze={handleAnalyze}
            onClear={handleClear}
            isAnalyzing={isAnalyzing}
          />
          <DroneDetections lastResult={lastResult} history={history} />
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
  header: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    marginBottom: 20,
  },
  title: {
    fontSize: 20,
    fontWeight: 500,
    color: "#1a1a1a",
    display: "flex",
    alignItems: "center",
    gap: 8,
    margin: 0,
  },
  titleIcon: {
    fontSize: 20,
    color: "#1B5E20",
  },
  subtitle: {
    fontSize: 13,
    color: "#888",
    marginTop: 4,
    marginLeft: 28,
  },
  errorBox: {
    background: "#FCEBEB",
    color: "#A32D2D",
    border: "0.5px solid #F7C1C1",
    borderRadius: 8,
    padding: "9px 13px",
    fontSize: 13,
    marginBottom: 16,
    display: "flex",
    alignItems: "center",
    gap: 7,
  },
  grid: {
    display: "grid",
    gridTemplateColumns: "1fr 2fr",
    gap: 20,
  },
};
