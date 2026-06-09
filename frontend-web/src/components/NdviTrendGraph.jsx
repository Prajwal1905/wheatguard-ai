import React, { useEffect, useState } from "react";
import { api } from "../services/api";
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer,
} from "recharts";

export default function NdviTrendGraph({ lat, lon }) {
  const [history, setHistory] = useState([]);
  const [view, setView]       = useState("all");
  const [status, setStatus]   = useState("loading"); // loading | ok | error | empty

  useEffect(() => {
    async function load() {
      setStatus("loading");
      try {
        const res = await api.get(`/api/ndvi_history?lat=${lat}&lon=${lon}`);
        if (!Array.isArray(res.data) || res.data.length === 0) {
          setStatus("empty");
          return;
        }
        const formatted = res.data
          .map((h) => ({
            time: new Date(h.timestamp).toLocaleDateString("en-IN", {
              day: "2-digit",
              month: "short",
            }),
            ndvi: parseFloat(h.ndvi?.toFixed(3)),
          }))
          .reverse();
        setHistory(formatted);
        setStatus("ok");
      } catch {
        setStatus("error");
      }
    }
    load();
  }, [lat, lon]);

  if (status === "loading") return <div style={styles.msg}>Loading NDVI history…</div>;
  if (status === "error")   return <div style={{ ...styles.msg, color: "#A32D2D" }}>Failed to load NDVI history.</div>;
  if (status === "empty")   return <div style={styles.msg}>No NDVI history available for this location.</div>;

  const filtered = view === "7d" ? history.slice(-7) : history;

  return (
    <div style={styles.wrap}>
      <div style={styles.toolbar}>
        <span style={styles.label}>NDVI trend</span>
        <div style={styles.toggleGroup}>
          {["7d", "all"].map((v) => (
            <button
              key={v}
              onClick={() => setView(v)}
              style={{
                ...styles.toggleBtn,
                ...(view === v ? styles.toggleActive : {}),
              }}
            >
              {v === "7d" ? "7 days" : "All"}
            </button>
          ))}
        </div>
      </div>

      <ResponsiveContainer width="100%" height={160}>
        <LineChart data={filtered} margin={{ top: 4, right: 4, bottom: 0, left: -16 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
          <XAxis dataKey="time" tick={{ fontSize: 10, fill: "#999" }} />
          <YAxis domain={[0, 1]} tick={{ fontSize: 10, fill: "#999" }} />
          <Tooltip
            contentStyle={{ fontSize: 11, borderRadius: 6, border: "0.5px solid rgba(0,0,0,0.1)" }}
            formatter={(v) => [v, "NDVI"]}
          />
          <Line
            type="monotone"
            dataKey="ndvi"
            stroke="#1B5E20"
            strokeWidth={2}
            dot={{ r: 2, fill: "#1B5E20" }}
            activeDot={{ r: 4 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

const styles = {
  wrap: {
    marginTop: 10,
    padding: "10px 0 0",
    borderTop: "0.5px solid rgba(0,0,0,0.08)",
  },
  toolbar: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 8,
  },
  label: {
    fontSize: 12,
    fontWeight: 500,
    color: "#444",
  },
  toggleGroup: {
    display: "flex",
    gap: 4,
  },
  toggleBtn: {
    fontSize: 10,
    padding: "2px 8px",
    borderRadius: 4,
    border: "0.5px solid #d0d0d0",
    background: "transparent",
    color: "#666",
    cursor: "pointer",
  },
  toggleActive: {
    background: "#1B5E20",
    color: "#fff",
    borderColor: "#1B5E20",
  },
  msg: {
    fontSize: 11,
    color: "#aaa",
    padding: "10px 0",
    textAlign: "center",
  },
};
