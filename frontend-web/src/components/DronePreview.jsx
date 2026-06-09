import React from "react";

export default function DronePreview({
  file,
  previewUrl,
  location,
  onAnalyze,
  onClear,
  isAnalyzing,
}) {
  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <i className="ti ti-photo-scan" style={styles.headerIcon} aria-hidden="true" />
        <div style={styles.headerTitle}>Image preview</div>
      </div>

      <div style={styles.body}>
        {/* Preview image */}
        <div style={styles.previewBox}>
          {previewUrl ? (
            <img src={previewUrl} alt="Drone preview" style={styles.previewImg} />
          ) : (
            <div style={styles.previewEmpty}>
              <i className="ti ti-photo-off" style={{ fontSize: 28, color: "#ccc", display: "block", marginBottom: 6 }} aria-hidden="true" />
              <span style={styles.previewEmptyText}>No image selected</span>
            </div>
          )}
        </div>

        {/* Meta */}
        <div style={styles.meta}>
          <div style={styles.metaGrid}>
            <MetaField label="Latitude"  value={location.lat || "—"} icon="ti-map-pin" />
            <MetaField label="Longitude" value={location.lon || "—"} icon="ti-map-pin" />
            <MetaField label="File"      value={file ? file.name : "—"} icon="ti-file-image" />
            <MetaField
              label="Size"
              value={file ? `${(file.size / 1024).toFixed(0)} KB` : "—"}
              icon="ti-database"
            />
          </div>

          <p style={styles.hint}>
            The image and coordinates are sent to the AI model. Results appear below and are plotted on the live map.
          </p>

          <div style={styles.actions}>
            <button
              onClick={onAnalyze}
              disabled={isAnalyzing || !file}
              style={{
                ...styles.analyzeBtn,
                ...(isAnalyzing || !file ? styles.analyzeBtnDisabled : {}),
              }}
            >
              <i
                className={`ti ${isAnalyzing ? "ti-loader-2" : "ti-cpu"}`}
                style={{ fontSize: 14 }}
                aria-hidden="true"
              />
              {isAnalyzing ? "Analyzing…" : "Analyze with AI"}
            </button>

            {file && (
              <button onClick={onClear} style={styles.clearBtn}>
                <i className="ti ti-x" style={{ fontSize: 13 }} aria-hidden="true" />
                Clear
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function MetaField({ label, value, icon }) {
  return (
    <div style={metaStyles.field}>
      <div style={metaStyles.label}>
        <i className={`ti ${icon}`} style={{ fontSize: 11 }} aria-hidden="true" />
        {label}
      </div>
      <div style={metaStyles.value}>{value}</div>
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
    fontSize: 16,
    color: "#1B5E20",
  },
  headerTitle: {
    fontSize: 14,
    fontWeight: 500,
    color: "#333",
  },
  body: {
    display: "flex",
    gap: 16,
    padding: 16,
  },
  previewBox: {
    width: 160,
    height: 160,
    flexShrink: 0,
    borderRadius: 8,
    overflow: "hidden",
    border: "0.5px solid rgba(0,0,0,0.08)",
    background: "#F7F8F5",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
  },
  previewImg: {
    width: "100%",
    height: "100%",
    objectFit: "cover",
  },
  previewEmpty: {
    textAlign: "center",
  },
  previewEmptyText: {
    fontSize: 11,
    color: "#aaa",
  },
  meta: {
    flex: 1,
    display: "flex",
    flexDirection: "column",
    gap: 12,
  },
  metaGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 8,
  },
  hint: {
    fontSize: 12,
    color: "#888",
    lineHeight: 1.5,
    margin: 0,
  },
  actions: {
    display: "flex",
    gap: 8,
    alignItems: "center",
    marginTop: "auto",
  },
  analyzeBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    padding: "8px 16px",
    background: "#1B5E20",
    color: "#fff",
    border: "none",
    borderRadius: 8,
    fontSize: 13,
    fontWeight: 500,
    cursor: "pointer",
  },
  analyzeBtnDisabled: {
    background: "#a5d6a7",
    cursor: "not-allowed",
  },
  clearBtn: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "7px 12px",
    background: "transparent",
    border: "0.5px solid #d0d0d0",
    color: "#666",
    borderRadius: 8,
    fontSize: 13,
    cursor: "pointer",
  },
};

const metaStyles = {
  field: {
    background: "#F7F8F5",
    borderRadius: 7,
    padding: "7px 10px",
  },
  label: {
    display: "flex",
    alignItems: "center",
    gap: 4,
    fontSize: 10,
    color: "#999",
    marginBottom: 2,
    textTransform: "uppercase",
    letterSpacing: "0.03em",
  },
  value: {
    fontSize: 12,
    fontWeight: 500,
    color: "#1a1a1a",
    wordBreak: "break-all",
  },
};
