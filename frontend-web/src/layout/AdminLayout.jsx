import React from "react";
import { Outlet } from "react-router-dom";   // ← REQUIRED
import Sidebar from "../components/Sidebar";
import Topbar from "../components/Topbar";

export default function AdminLayout() {
  return (
    <div style={{ display: "flex", height: "100vh", width: "100vw" }}>
      <Sidebar />

      <div style={{ flexGrow: 1, display: "flex", flexDirection: "column" }}>
        <Topbar />

        <div
          style={{
            flex: 1,
            padding: "20px",
            overflow: "auto",
            background: "#f4f6f8",
          }}
        >
          <div
            style={{
              background: "#fff",
              borderRadius: "10px",
              padding: "20px",
              boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
            }}
          >
            <Outlet /> 
          </div>
        </div>
      </div>
    </div>
  );
}
