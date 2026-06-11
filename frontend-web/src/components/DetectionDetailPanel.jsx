import React, { useEffect, useState } from "react";
import { api } from "../services/api";

function severityStyle(sev) {
  if (sev === "High" || sev === "Critical") return { background: "#FCEBEB", color: "#A32D2D" };
  if (sev === "Moderate" || sev === "Medium") return { background: "#FAEEDA", color: "#854F0B" };
  return { background: "#EAF3DE", color: "#3B6D11" };
}

function sourceLabel(src) {
  if (src === "drone")  return { icon: "ti-drone",    label: "Drone" };
  if (src === "mobile") return { icon: "ti-device-mobile", label: "Mobile" };
  return { icon: "ti-user", label: "Manual" };
}

export default function DetectionDetailPanel({ detectionId, onClose }) {
  const [detail,  setDetail]  = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(false);

  useEffect(() => {
    if (!detectionId) return;
    setLoading(true);
    setError(false);
    setDetail(null);

    api.get(`/detections/${detectionId}`)
      .then((res) => {
        setDetail(res.data);
        setLoading(false);
      })
      .catch(() => {
        setError(true);
        setLoading(false);
      });
  }, [detectionId]);

  if (!detectionId) return null;

  const src = detail ? sourceLabel(detail.source) : null;

  return (
    <>
      
      <div style={styles.backdrop} onClick={onClose} />

      
      <div style={styles.panel}>
        
        <div style={styles.header}>
          <div style={styles.headerLeft}>
            <i className="ti ti-scan" style={styles.headerIcon} aria-hidden="true" />
            <span style={styles.headerTitle}>Detection detail</span>
          </div>
          <button style={styles.closeBtn} onClick={onClose} aria-label="Close">
            <i className="ti ti-x" style={{ fontSize: 16 }} aria-hidden="true" />
          </button>
        </div>

        <div style={styles.body}>
          {loading && (
            <div style={styles.center}>
              <i className="ti ti-loader-2" style={{ fontSize: 28, color: "#ccc" }} aria-hidden="true" />
              <div style={styles.centerText}>Loading detection…</div>
            </div>
          )}

          {error && (
            <div style={styles.center}>
              <i className="ti ti-alert-circle" style={{ fontSize: 28, color: "#A32D2D" }} aria-hidden="true" />
              <div style={{ ...styles.centerText, color: "#A32D2D" }}>Failed to load detection.</div>
            </div>
          )}

          {detail && (
            <>
              
              <div style={styles.imageWrap}>
                {detail.image_url ? (
                  <img
                    src={detail.image_url}
                    alt={`${detail.disease} crop`}
                    style={styles.image}
                    onError={(e) => { e.target.style.display = "none"; }}
                  />
                ) : (
                  <div style={styles.noImage}>
                    <i className="ti ti-photo-off" style={{ fontSize: 28, color: "#ccc" }} aria-hidden="true" />
                    <span style={styles.noImageText}>No image available</span>
                  </div>
                )}
              </div>

              
              <div style={styles.diseaseRow}>
                <div style={styles.diseaseName}>{detail.disease}</div>
                <span style={{ ...styles.badge, ...severityStyle(detail.severity) }}>
                  {detail.severity}
                </span>
              </div>

              
              <div style={styles.metaGrid}>
                <MetaField
                  icon="ti-chart-bar"
                  label="Confidence"
                  value={`${detail.confidence}%`}
                />
                <MetaField
                  icon={src.icon}
                  label="Source"
                  value={src.label}
                />
                <MetaField
                  icon="ti-map-pin"
                  label="Coordinates"
                  value={
                    detail.lat && detail.lon
                      ? `${detail.lat.toFixed(4)}, ${detail.lon.toFixed(4)}`
                      : "—"
                  }
                  mono
                />
                <MetaField
                  icon="ti-clock"
                  label="Detected"
                  value={
                    detail.timestamp
                      ? new Date(detail.timestamp).toLocaleString("en-IN", {
                          day: "2-digit", month: "short", year: "numeric",
                          hour: "2-digit", minute: "2-digit",
                        })
                      : "—"
                  }
                />
              </div>

              
              <div style={styles.confSection}>
                <div style={styles.confLabel}>
                  <span>Model confidence</span>
                  <span style={styles.confValue}>{detail.confidence}%</span>
                </div>
                <div style={styles.confBar}>
                  <div
                    style={{
                      ...styles.confFill,
                      width: `${detail.confidence}%`,
                      background:
                        detail.confidence >= 85 ? "#A32D2D" :
                        detail.confidence >= 60 ? "#854F0B" :
                        "#1B5E20",
                    }}
                  />
                </div>
              </div>

              
              {detail.remedy && (
                <div style={styles.remedySection}>
                  <div style={styles.remedyHeader}>
                    <i className="ti ti-plant-2" style={{ fontSize: 14, color: "#1B5E20" }} aria-hidden="true" />
                    <span style={styles.remedyTitle}>Recommended remedy</span>
                  </div>
                  <div style={styles.remedyBody}>
                    {detail.remedy.split("\n").map((line, i) => (
                      line.trim() ? (
                        <p key={i} style={styles.remedyLine}>{line.trim()}</p>
                      ) : null
                    ))}
                  </div>
                </div>
              )}

              
              <div style={styles.modelInfo}>
                <i className="ti ti-cpu" style={{ fontSize: 12 }} aria-hidden="true" />
                {detail.model_version || "EfficientNet-B3 ONNX"}
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}

function MetaField({ icon, label, value, mono }) {
  return (
    <div style={mf.wrap}>
      <div style={mf.label}>
        <i className={`ti ${icon}`} style={{ fontSize: 11 }} aria-hidden="true" />
        {label}
      </div>
      <div style={{ ...mf.value, ...(mono ? mf.mono : {}) }}>{value}</div>
    </div>
  );
}

const mf = {
  wrap:  { background: "#F7F8F5", borderRadius: 7, padding: "7px 10px" },
  label: { display: "flex", alignItems: "center", gap: 4, fontSize: 10, color: "#999", textTransform: "uppercase", letterSpacing: "0.03em", marginBottom: 3 },
  value: { fontSize: 13, fontWeight: 500, color: "#1a1a1a" },
  mono:  { fontFamily: "monospace", fontSize: 11, color: "#666" },
};

const styles = {
  backdrop: {
    position: "fixed",
    inset: 0,
    background: "rgba(0,0,0,0.2)",
    zIndex: 8000,
  },
  panel: {
    position: "fixed",
    top: 0,
    right: 0,
    width: 380,
    height: "100vh",
    background: "#fff",
    zIndex: 9000,
    display: "flex",
    flexDirection: "column",
    boxShadow: "-4px 0 24px rgba(0,0,0,0.12)",
  },
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "14px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.08)",
    background: "#F7F8F5",
    flexShrink: 0,
  },
  headerLeft: {
    display: "flex",
    alignItems: "center",
    gap: 8,
  },
  headerIcon: {
    fontSize: 15,
    color: "#1B5E20",
  },
  headerTitle: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
  },
  closeBtn: {
    background: "transparent",
    border: "0.5px solid rgba(0,0,0,0.12)",
    borderRadius: 6,
    padding: "4px 6px",
    cursor: "pointer",
    color: "#666",
    display: "flex",
    alignItems: "center",
  },
  body: {
    flex: 1,
    overflowY: "auto",
    padding: 16,
  },
  center: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    height: 200,
    gap: 10,
  },
  centerText: {
    fontSize: 13,
    color: "#aaa",
  },
  imageWrap: {
    width: "100%",
    height: 200,
    borderRadius: 10,
    overflow: "hidden",
    background: "#F7F8F5",
    marginBottom: 14,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    border: "0.5px solid rgba(0,0,0,0.08)",
  },
  image: {
    width: "100%",
    height: "100%",
    objectFit: "cover",
  },
  noImage: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: 6,
  },
  noImageText: {
    fontSize: 12,
    color: "#aaa",
  },
  diseaseRow: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 12,
  },
  diseaseName: {
    fontSize: 18,
    fontWeight: 500,
    color: "#1a1a1a",
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    padding: "4px 10px",
    borderRadius: 20,
    fontSize: 12,
    fontWeight: 500,
  },
  metaGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 8,
    marginBottom: 14,
  },
  confSection: {
    marginBottom: 14,
  },
  confLabel: {
    display: "flex",
    justifyContent: "space-between",
    fontSize: 12,
    color: "#888",
    marginBottom: 5,
  },
  confValue: {
    fontWeight: 500,
    color: "#1a1a1a",
  },
  confBar: {
    height: 6,
    background: "#F0F0F0",
    borderRadius: 3,
    overflow: "hidden",
  },
  confFill: {
    height: "100%",
    borderRadius: 3,
    transition: "width 0.4s ease",
  },
  remedySection: {
    background: "#F4F9F4",
    border: "0.5px solid #C8E6C9",
    borderRadius: 10,
    padding: 12,
    marginBottom: 14,
  },
  remedyHeader: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    marginBottom: 8,
  },
  remedyTitle: {
    fontSize: 13,
    fontWeight: 500,
    color: "#1B5E20",
  },
  remedyBody: {
    display: "flex",
    flexDirection: "column",
    gap: 4,
  },
  remedyLine: {
    fontSize: 12,
    color: "#333",
    lineHeight: 1.6,
    margin: 0,
  },
  modelInfo: {
    display: "flex",
    alignItems: "center",
    gap: 5,
    fontSize: 11,
    color: "#bbb",
    marginTop: 4,
  },
};
