import React, { useEffect, useState } from "react";
import DroneUpload from "../components/DroneUpload";
import DronePreview from "../components/DronePreview";
import DroneDetections from "../components/DroneDetections";
import { analyzeDroneImage } from "../services/api"; 

export default function Drone() {
  const [file, setFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(null);

  const [location, setLocation] = useState({
    lat: "",
    lon: "",
  });

  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState("");
  const [lastResult, setLastResult] = useState(null);
  const [history, setHistory] = useState([]);

  
  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const handleUseMyLocation = () => {
    if (!navigator.geolocation) {
      setError("Geolocation not supported in this browser.");
      return;
    }
    setError("");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLocation({
          lat: pos.coords.latitude.toFixed(6),
          lon: pos.coords.longitude.toFixed(6),
        });
      },
      () => {
        setError("Unable to fetch your location.");
      }
    );
  };

  const handleClear = () => {
    setFile(null);
    setPreviewUrl(null);
    setLastResult(null);
    setError("");
  };

  const handleAnalyze = async () => {
    if (!file) {
      setError("Please select an image first.");
      return;
    }
    if (!location.lat || !location.lon) {
      setError("Please provide field location (lat & lon).");
      return;
    }

    setError("");
    setIsAnalyzing(true);

    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("lat", location.lat);
      formData.append("lon", location.lon);

      const data = await analyzeDroneImage(formData);

      setLastResult(data);
      
      if (data?.detection) {
        setHistory((prev) => [data.detection, ...prev]);
      }
    } catch (e) {
      console.error(e);
      setError("Failed to analyze image. Please try again.");
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <div className="p-4 md:p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h1 style={{color:"black"}}>
          🛩 Drone Analysis
        </h1>

        <span style={{ color:"black"

        }} >
          Upload simulated drone images &amp; map detections
        </span>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-2 rounded-md">
          {error}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        
        <div className="lg:col-span-1">
          <DroneUpload
            file={file}
            setFile={setFile}
            location={location}
            setLocation={setLocation}
            onUseMyLocation={handleUseMyLocation}
          />
        </div>

        <div className="lg:col-span-2 space-y-4">
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
