import React from "react";

function severityStyle(sev) {
  if (sev === "High" || sev === "Critical")
    return { background: "#FCEBEB", color: "#A32D2D" };
  if (sev === "Medium" || sev === "Moderate")
    return { background: "#FAEEDA", color: "#854F0B" };
  return { background: "#EAF3DE", color: "#3B6D11" };
}

export default function LiveFeedPanel({ detections }) {
  const latest = [...detections].reverse().slice(0, 10);

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <i className="ti ti-live-view" style={styles.headerIcon} aria-hidden="true" />
          <span style={styles.title}>Live feed</span>
        </div>
        <div style={styles.liveDot} title="Live" />
      </div>

      <div style={styles.list}>
        {latest.length === 0 ? (
          <div style={styles.empty}>
            <i className="ti ti-radar" style={{ fontSize: 24, color: "#ccc", display: "block", marginBottom: 6 }} aria-hidden="true" />
            Waiting for detections…
          </div>
        ) : (
          latest.map((d, i) => (
            <div key={d.id || i} style={styles.item}>
              <div style={styles.itemLeft}>
                <div style={styles.disease}>{d.disease || "Unknown"}</div>
                <div style={styles.time}>
                  {d.timestamp
                    ? new Date(d.timestamp).toLocaleString("en-IN", {
                        hour: "2-digit",
                        minute: "2-digit",
                        day: "2-digit",
                        month: "short",
                      })
                    : "—"}
                </div>
              </div>
              <span style={{ ...styles.badge, ...severityStyle(d.severity) }}>
                {d.severity}
              </span>
            </div>
          ))
        )}
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
    justifyContent: "space-between",
    padding: "12px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  headerLeft: {
    display: "flex",
    alignItems: "center",
    gap: 7,
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
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: "50%",
    background: "#3B6D11",
    boxShadow: "0 0 0 2px #EAF3DE",
    animation: "pulse 2s infinite",
  },
  list: {
    maxHeight: 280,
    overflowY: "auto",
  },
  item: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "10px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.05)",
  },
  itemLeft: {
    flex: 1,
    minWidth: 0,
  },
  disease: {
    fontSize: 13,
    fontWeight: 500,
    color: "#1a1a1a",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  time: {
    fontSize: 11,
    color: "#aaa",
    marginTop: 2,
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    padding: "2px 8px",
    borderRadius: 20,
    fontSize: 11,
    fontWeight: 500,
    flexShrink: 0,
    marginLeft: 8,
  },
  empty: {
    textAlign: "center",
    color: "#aaa",
    fontSize: 13,
    padding: "32px 0",
  },
};

