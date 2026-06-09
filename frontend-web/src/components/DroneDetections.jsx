import React from "react";

function severityStyle(sev) {
  const s = sev?.toLowerCase();
  if (s === "high" || s === "critical") return { background: "#FCEBEB", color: "#A32D2D" };
  if (s === "medium" || s === "moderate") return { background: "#FAEEDA", color: "#854F0B" };
  return { background: "#EAF3DE", color: "#3B6D11" };
}

export default function DroneDetections({ lastResult, history }) {
  const detection = lastResult?.detection;
  const result    = lastResult?.result || lastResult;

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <i className="ti ti-scan" style={styles.headerIcon} aria-hidden="true" />
        <span style={styles.title}>Detection result</span>
      </div>

      {/* Latest result */}
      <div style={styles.section}>
        {result && (result.label || detection?.disease) ? (
          <div style={styles.resultBox}>
            <div style={styles.resultGrid}>
              <ResultField
                label="Disease"
                value={result.label || detection?.disease || "—"}
                highlight
              />
              <ResultField
                label="Severity"
                value={
                  <span style={{ ...styles.badge, ...severityStyle(result.severity || detection?.severity) }}>
                    {result.severity || detection?.severity || "—"}
                  </span>
                }
              />
              <ResultField
                label="Confidence"
                value={
                  result.confidence || detection?.confidence
                    ? `${parseFloat(result.confidence || detection?.confidence).toFixed(1)}%`
                    : "—"
                }
              />
              {detection && (
                <ResultField
                  label="Coordinates"
                  value={
                    detection.lat && detection.lon
                      ? `${detection.lat.toFixed(4)}, ${detection.lon.toFixed(4)}`
                      : "—"
                  }
                  mono
                />
              )}
            </div>
          </div>
        ) : (
          <div style={styles.empty}>
            <i className="ti ti-cpu-off" style={{ fontSize: 24, color: "#ccc", display: "block", marginBottom: 6 }} aria-hidden="true" />
            <div style={{ fontSize: 13, color: "#aaa" }}>No analysis run yet.</div>
            <div style={{ fontSize: 12, color: "#bbb", marginTop: 3 }}>Upload an image and click Analyze with AI.</div>
          </div>
        )}
      </div>

      {/* History table */}
      {history?.length > 0 && (
        <div style={styles.historySection}>
          <div style={styles.historyHeader}>
            <i className="ti ti-history" style={{ fontSize: 13, color: "#1B5E20" }} aria-hidden="true" />
            <span style={styles.historyTitle}>Recent detections</span>
            <span style={styles.historyCount}>{history.length}</span>
          </div>
          <table style={styles.table}>
            <thead>
              <tr>
                {["Disease", "Severity", "Confidence", "Location", "Time"].map((h) => (
                  <th key={h} style={styles.th}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {history.map((d, idx) => (
                <tr key={d.id || idx} style={styles.tr}>
                  <td style={styles.td}>{d.disease || d.disease_label || "—"}</td>
                  <td style={styles.td}>
                    <span style={{ ...styles.badge, ...severityStyle(d.severity) }}>
                      {d.severity || "—"}
                    </span>
                  </td>
                  <td style={styles.td}>
                    {d.confidence ? `${parseFloat(d.confidence).toFixed(1)}%` : "—"}
                  </td>
                  <td style={{ ...styles.td, fontFamily: "monospace", fontSize: 11, color: "#666" }}>
                    {d.lat && d.lon
                      ? `${d.lat.toFixed?.(4) ?? d.lat}, ${d.lon.toFixed?.(4) ?? d.lon}`
                      : "—"}
                  </td>
                  <td style={{ ...styles.td, fontSize: 11, color: "#aaa" }}>
                    {d.timestamp ? new Date(d.timestamp).toLocaleString("en-IN", {
                      day: "2-digit", month: "short",
                      hour: "2-digit", minute: "2-digit",
                    }) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function ResultField({ label, value, highlight, mono }) {
  return (
    <div style={rfStyles.wrap}>
      <div style={rfStyles.label}>{label}</div>
      <div style={{
        ...rfStyles.value,
        ...(highlight ? rfStyles.highlight : {}),
        ...(mono ? rfStyles.mono : {}),
      }}>
        {value}
      </div>
    </div>
  );
}

const styles = {
  card: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.08)",
    borderRadius: 12,
    overflow: "hidden",
  },
  header: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    padding: "12px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
    background: "#F7F8F5",
  },
  headerIcon: {
    fontSize: 15,
    color: "#1B5E20",
  },
  title: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
  },
  section: {
    padding: 16,
  },
  resultBox: {
    background: "#F4F9F4",
    border: "0.5px solid #C8E6C9",
    borderRadius: 10,
    padding: 14,
  },
  resultGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 10,
  },
  empty: {
    textAlign: "center",
    padding: "28px 0",
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    padding: "2px 8px",
    borderRadius: 20,
    fontSize: 11,
    fontWeight: 500,
  },
  historySection: {
    borderTop: "0.5px solid rgba(0,0,0,0.06)",
  },
  historyHeader: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    padding: "10px 16px",
    background: "#fafafa",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  historyTitle: {
    fontSize: 13,
    fontWeight: 500,
    color: "#333",
    flex: 1,
  },
  historyCount: {
    background: "#1B5E20",
    color: "#fff",
    fontSize: 11,
    fontWeight: 500,
    padding: "1px 7px",
    borderRadius: 20,
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
  },
  th: {
    padding: "8px 14px",
    fontSize: 11,
    fontWeight: 500,
    color: "#888",
    textAlign: "left",
    textTransform: "uppercase",
    letterSpacing: "0.03em",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  tr: {
    borderBottom: "0.5px solid rgba(0,0,0,0.05)",
  },
  td: {
    padding: "9px 14px",
    fontSize: 12,
    color: "#333",
    verticalAlign: "middle",
  },
};

const rfStyles = {
  wrap: {
    background: "#fff",
    borderRadius: 7,
    padding: "7px 10px",
    border: "0.5px solid rgba(0,0,0,0.06)",
  },
  label: {
    fontSize: 10,
    color: "#999",
    textTransform: "uppercase",
    letterSpacing: "0.03em",
    marginBottom: 3,
  },
  value: {
    fontSize: 13,
    color: "#333",
    fontWeight: 400,
  },
  highlight: {
    fontSize: 14,
    fontWeight: 500,
    color: "#1B5E20",
  },
  mono: {
    fontFamily: "monospace",
    fontSize: 11,
    color: "#666",
  },
};
