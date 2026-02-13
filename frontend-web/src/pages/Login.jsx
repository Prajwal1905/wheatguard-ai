import React, { useState } from "react";
import axios from "axios";
import { Navigate } from "react-router-dom";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const token = localStorage.getItem("token");


  if (token) return <Navigate to="/" replace />;

  const login = async () => {
    try {
      const res = await axios.post(`${API_BASE}/admin/login`, { email, password });
      localStorage.setItem("token", res.data.token);
      window.location.href = "/";
    
    // eslint-disable-next-line no-unused-vars
    } catch (err) {
      setError("Invalid credentials");
    }
  };

  return (
    <div
      style={{
        height: "100vh",
        width: "100vw",
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        background: "#e8f5e9",
        margin: 0,
        padding: 0,
      }}
    >
      <div
        style={{
          background: "#fff",
          padding: 30,
          borderRadius: 12,
          width: 350,
          boxShadow: "0 4px 10px rgba(0,0,0,0.15)",
        }}
      >
        <h2 style={{ color: "black", textAlign: "center", marginBottom: 20 }}>Admin Login</h2>

        {error && <p style={{ color: "red", textAlign: "center" }}>{error}</p>}

        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          style={{
            width: "100%",
            padding: 12,
            marginTop: 10,
            borderRadius: 6,
            border: "1px solid #ccc",
          }}
        />

        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          style={{
            width: "100%",
            padding: 12,
            marginTop: 10,
            borderRadius: 6,
            border: "1px solid #ccc",
          }}
        />

        <button
          onClick={login}
          style={{
            width: "100%",
            padding: 12,
            marginTop: 20,
            background: "#2e7d32",
            color: "#fff",
            border: "none",
            borderRadius: 8,
            cursor: "pointer",
            fontWeight: 600,
            fontSize: 16,
          }}
        >
          Login
        </button>
      </div>
    </div>
  );
}
