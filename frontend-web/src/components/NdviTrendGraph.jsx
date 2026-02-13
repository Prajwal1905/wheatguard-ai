import React, { useEffect, useState } from "react";
import { api } from "../services/api";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

export default function NdviTrendGraph({ lat, lon }) {
  const [history, setHistory] = useState([]);
  const [view, setView] = useState("all");
  const [error, setError] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const res = await api.get(`/api/ndvi_history?lat=${lat}&lon=${lon}`);

        if (!Array.isArray(res.data)) {
          setError(true);
          return;
        }

        const formatted = res.data.map((h) => {
          const d = new Date(h.timestamp);
          return {
            time: d.toLocaleString("en-IN", {
              hour: "2-digit",
              minute: "2-digit",
              day: "2-digit",
              month: "short",
            }),
            ndvi: h.ndvi,
          };
        });

        setHistory(formatted.reverse());
      } catch (err) {
        console.error(err);
        setError(true);
      }
    }

    load();
  }, [lat, lon]);

  if (error)
    return (
      <div style={{ fontSize: 12, color: "red" }}>
        ⚠ Error loading NDVI history
      </div>
    );

  if (!history.length)
    return <div style={{ fontSize: 12 }}>No NDVI history yet.</div>;

  
  const filtered =
    view === "7d" ? history.slice(-7) : history;

  return (
    <div style={{ width: "100%", height: 200, marginTop: 10 }}>
      <div style={{ fontSize: 12, marginBottom: 5, display: "flex", gap: 5 }}>
        <button
          onClick={() => setView("7d")}
          style={{
            fontSize: 11,
            padding: "2px 6px",
            background: view === "7d" ? "#1976d2" : "#eee",
            color: view === "7d" ? "white" : "black",
            borderRadius: 4,
            border: "none",
          }}
        >
          Last 7 Days
        </button>

        <button
          onClick={() => setView("all")}
          style={{
            fontSize: 11,
            padding: "2px 6px",
            background: view === "all" ? "#1976d2" : "#eee",
            color: view === "all" ? "white" : "black",
            borderRadius: 4,
            border: "none",
          }}
        >
          All
        </button>
      </div>

      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={filtered}>
          <CartesianGrid strokeDasharray="3 3" opacity={0.4} />
          <XAxis dataKey="time" fontSize={10} />
          <YAxis domain={[0, 1]} fontSize={10} />
          <Tooltip />
          <Legend />

          <Line
            type="monotone"
            dataKey="ndvi"
            stroke="#2e7d32"
            strokeWidth={2}
            dot={{ r: 3 }}
            name="NDVI"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
