import React from "react";

export default function LiveFeedPanel({ detections }) {
  const latest = [...detections].reverse().slice(0, 10);
  return (
    <div style={{ background: "#fff", padding: "20px", borderRadius: "10px", marginTop: "20px", height: "300px", overflowY: "auto" }}>
      <h3> Live Detection Feed</h3>
      {latest.map((d, i) => (
        <div key={i} style={{ marginBottom: "10px", borderBottom: "1px solid #ddd", paddingBottom: "6px" }}>
          <b>{d.disease}</b> ({d.severity})  
          <br />
          <small>{new Date(d.timestamp).toLocaleString()}</small>
        </div>
      ))}
    </div>
  );
}
