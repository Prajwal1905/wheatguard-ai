import React, { useState } from "react";
import axios from "axios";
import { Navigate } from "react-router-dom";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [logoError, setLogoError] = useState(false);

  const token = localStorage.getItem("token");
  if (token) return <Navigate to="/" replace />;

  const login = async () => {
    setLoading(true);
    setError("");
    try {
      const res = await axios.post(`${API_BASE}/admin/login`, { email, password });
      localStorage.setItem("token", res.data.token);
      window.location.href = "/";
    } catch (err) {
      setError("Invalid email or password.");
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") login();
  };

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        <div style={styles.logoWrap}>
          {!logoError ? (
            <img
              src="/logo.png"
              alt="WheatGuard"
              style={styles.logoImg}
              onError={() => setLogoError(true)}
            />
          ) : (
            <div style={styles.logoIcon}>
              <i className="ti ti-plant-2" style={{ color: "#fff", fontSize: 22 }} aria-hidden="true" />
            </div>
          )}
          <h1 style={styles.appName}>WheatGuard</h1>
          <p style={styles.appSub}>Admin portal</p>
        </div>

        {error && (
          <div style={styles.errorBox}>
            <i className="ti ti-alert-circle" style={{ fontSize: 14 }} aria-hidden="true" />
            {error}
          </div>
        )}

        <div style={styles.fieldWrap}>
          <label style={styles.label} htmlFor="login-email">Email address</label>
          <div style={styles.inputRow}>
            <i className="ti ti-mail" style={styles.inputIcon} aria-hidden="true" />
            <input
              id="login-email"
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={handleKeyDown}
              style={styles.input}
              autoComplete="username"
            />
          </div>
        </div>

        <div style={styles.fieldWrap}>
          <label style={styles.label} htmlFor="login-password">Password</label>
          <div style={styles.inputRow}>
            <i className="ti ti-lock" style={styles.inputIcon} aria-hidden="true" />
            <input
              id="login-password"
              type="password"
              placeholder="Your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={handleKeyDown}
              style={styles.input}
              autoComplete="current-password"
            />
          </div>
        </div>

        <button onClick={login} disabled={loading} style={styles.btn}>
          {loading ? (
            <>
              <i className="ti ti-loader-2" style={{ fontSize: 15 }} aria-hidden="true" />
              Signing in…
            </>
          ) : (
            <>
              <i className="ti ti-login" style={{ fontSize: 15 }} aria-hidden="true" />
              Sign in
            </>
          )}
        </button>
      </div>
    </div>
  );
}

const styles = {
  page: {
    height: "100vh",
    width: "100vw",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    background: "#F7F8F5",
  },
  card: {
    background: "#fff",
    padding: "36px 32px",
    borderRadius: 14,
    width: 360,
    border: "0.5px solid rgba(0,0,0,0.1)",
    boxShadow: "0 2px 12px rgba(0,0,0,0.06)",
  },
  logoWrap: {
    textAlign: "center",
    marginBottom: 28,
  },
  logoImg: {
    width: 56,
    height: 56,
    borderRadius: 12,
    objectFit: "cover",
    marginBottom: 10,
  },
  logoIcon: {
    width: 56,
    height: 56,
    background: "#1B5E20",
    borderRadius: 12,
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 10,
  },
  appName: {
    fontSize: 18,
    fontWeight: 500,
    color: "#1a1a1a",
    margin: 0,
  },
  appSub: {
    fontSize: 13,
    color: "#888",
    margin: "3px 0 0",
  },
  errorBox: {
    background: "#FCEBEB",
    color: "#A32D2D",
    borderRadius: 8,
    padding: "9px 12px",
    fontSize: 13,
    marginBottom: 16,
    display: "flex",
    alignItems: "center",
    gap: 7,
    border: "0.5px solid #F7C1C1",
  },
  fieldWrap: { marginBottom: 14 },
  label: {
    display: "block",
    fontSize: 13,
    fontWeight: 500,
    color: "#444",
    marginBottom: 5,
  },
  inputRow: {
    display: "flex",
    alignItems: "center",
    border: "0.5px solid #d0d0d0",
    borderRadius: 8,
    padding: "0 12px",
    background: "#fafafa",
  },
  inputIcon: { fontSize: 16, color: "#999", marginRight: 8 },
  input: {
    flex: 1,
    border: "none",
    background: "transparent",
    padding: "11px 0",
    fontSize: 14,
    color: "#1a1a1a",
    outline: "none",
  },
  btn: {
    width: "100%",
    padding: "11px 0",
    marginTop: 6,
    background: "#1B5E20",
    color: "#fff",
    border: "none",
    borderRadius: 8,
    cursor: "pointer",
    fontWeight: 500,
    fontSize: 15,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 7,
  },
};
