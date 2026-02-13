import React, { useState, useEffect } from "react";
import toast from "react-hot-toast";

export default function Settings() {
  const [theme, setTheme] = useState("light");
  const [notifications, setNotifications] = useState(true);
  const [refreshRate, setRefreshRate] = useState("30");

  useEffect(() => {
    setTheme(localStorage.getItem("theme") || "light");
    setNotifications(localStorage.getItem("notifications") === "true");
    setRefreshRate(localStorage.getItem("refreshRate") || "30");
  }, []);

 
  useEffect(() => {
    localStorage.setItem("theme", theme);
    localStorage.setItem("notifications", notifications);
    localStorage.setItem("refreshRate", refreshRate);
  }, [theme, notifications, refreshRate]);

  return (
    
      <div style={{ padding: "20px", width: "100%", color: "black" }}>
        <h2 style={{ fontWeight: "bold", marginBottom: 15 }}>⚙️ Settings</h2>

        
        <div style={card}>
          <h3> Theme</h3>
          <select
            value={theme}
            onChange={(e) => setTheme(e.target.value)}
            style={input}
          >
            <option value="light">☀️ Light</option>
            <option value="dark">🌙 Dark</option>
          </select>
        </div>

        
        <div style={card}>
          <h3>🔔 Notifications</h3>
          <label>
            <input
              type="checkbox"
              checked={notifications}
              onChange={(e) => setNotifications(e.target.checked)}
            />{" "}
            Enable Notifications
          </label>
        </div>

        <div style={card}>
          <h3> Auto Refresh</h3>
          <select
            value={refreshRate}
            onChange={(e) => setRefreshRate(e.target.value)}
            style={input}
          >
            <option value="15">Every 15 seconds</option>
            <option value="30">Every 30 seconds</option>
            <option value="60">Every 1 minute</option>
            <option value="300">Every 5 minutes</option>
          </select>
        </div>

        <button
          onClick={() => toast.success("Settings saved!")}
          style={{
            background: "#2e7d32",
            color: "#fff",
            padding: "10px 16px",
            border: "none",
            borderRadius: 8,
            cursor: "pointer",
            marginTop: 15,
          }}
        >
           Save
        </button>
      </div>
    
  );
}

const card = {
  background: "#fff",
  padding: "20px",
  borderRadius: "10px",
  marginBottom: "20px",
  boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
};

const input = {
  padding: "8px 12px",
  borderRadius: "6px",
  border: "1px solid #ccc",
  marginTop: "10px",
};
