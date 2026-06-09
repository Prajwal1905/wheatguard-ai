import React, { useRef } from "react";

export default function DroneUpload({ file, setFile, location, setLocation, onUseMyLocation }) {
  const inputRef = useRef(null);

  const handleFileChange = (e) => {
    const f = e.target.files?.[0];
    if (f) setFile(f);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    const f = e.dataTransfer.files?.[0];
    if (f && f.type.startsWith("image/")) setFile(f);
  };

  return (
    <div style={styles.card}>
      <div style={styles.header}>
        <i className="ti ti-cloud-upload" style={styles.headerIcon} aria-hidden="true" />
        <div>
          <div style={styles.title}>Upload image</div>
          <div style={styles.subtitle}>Simulated drone capture</div>
        </div>
      </div>

      {/* Drop zone */}
      <div
        style={{
          ...styles.dropZone,
          ...(file ? styles.dropZoneActive : {}),
        }}
        onClick={() => inputRef.current?.click()}
        onDrop={handleDrop}
        onDragOver={(e) => e.preventDefault()}
        role="button"
        tabIndex={0}
        aria-label="Upload drone image"
        onKeyDown={(e) => e.key === "Enter" && inputRef.current?.click()}
      >
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          style={{ display: "none" }}
        />
        {file ? (
          <div style={styles.fileSelected}>
            <i className="ti ti-photo-check" style={{ fontSize: 22, color: "#1B5E20" }} aria-hidden="true" />
            <span style={styles.fileName}>{file.name}</span>
            <span style={styles.fileSize}>
              {(file.size / 1024).toFixed(0)} KB
            </span>
          </div>
        ) : (
          <div style={styles.dropPlaceholder}>
            <i className="ti ti-upload" style={{ fontSize: 22, color: "#aaa" }} aria-hidden="true" />
            <span style={styles.dropText}>Drop image or click to browse</span>
            <span style={styles.dropHint}>PNG, JPG up to 20 MB</span>
          </div>
        )}
      </div>

      {/* Location */}
      <div style={styles.section}>
        <div style={styles.sectionLabel}>
          <i className="ti ti-map-pin" style={{ fontSize: 13, color: "#1B5E20" }} aria-hidden="true" />
          Field coordinates
        </div>
        <div style={styles.coordRow}>
          <div style={styles.coordField}>
            <label style={styles.coordLabel} htmlFor="drone-lat">Latitude</label>
            <input
              id="drone-lat"
              type="number"
              step="0.000001"
              placeholder="20.5937"
              value={location.lat}
              onChange={(e) => setLocation((p) => ({ ...p, lat: e.target.value }))}
              style={styles.input}
            />
          </div>
          <div style={styles.coordField}>
            <label style={styles.coordLabel} htmlFor="drone-lon">Longitude</label>
            <input
              id="drone-lon"
              type="number"
              step="0.000001"
              placeholder="78.9629"
              value={location.lon}
              onChange={(e) => setLocation((p) => ({ ...p, lon: e.target.value }))}
              style={styles.input}
            />
          </div>
        </div>
        <button onClick={onUseMyLocation} style={styles.locationBtn}>
          <i className="ti ti-location" style={{ fontSize: 13 }} aria-hidden="true" />
          Use my current location
        </button>
      </div>

      <div style={styles.tip}>
        <i className="ti ti-info-circle" style={{ fontSize: 12, flexShrink: 0 }} aria-hidden="true" />
        In production, GPS coordinates come from drone telemetry. For testing, enter manually or use browser location.
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
    gap: 10,
    padding: "14px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
    background: "#F7F8F5",
  },
  headerIcon: {
    fontSize: 18,
    color: "#1B5E20",
  },
  title: {
    fontSize: 14,
    fontWeight: 500,
    color: "#1a1a1a",
  },
  subtitle: {
    fontSize: 11,
    color: "#888",
    marginTop: 1,
  },
  dropZone: {
    margin: 14,
    border: "1.5px dashed #d0d0d0",
    borderRadius: 10,
    padding: "20px 12px",
    cursor: "pointer",
    textAlign: "center",
    background: "#fafafa",
    transition: "border-color 0.15s",
  },
  dropZoneActive: {
    borderColor: "#1B5E20",
    background: "#F4F9F4",
  },
  dropPlaceholder: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: 6,
  },
  dropText: {
    fontSize: 13,
    color: "#555",
    fontWeight: 500,
  },
  dropHint: {
    fontSize: 11,
    color: "#aaa",
  },
  fileSelected: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: 4,
  },
  fileName: {
    fontSize: 12,
    fontWeight: 500,
    color: "#1a1a1a",
    wordBreak: "break-all",
  },
  fileSize: {
    fontSize: 11,
    color: "#aaa",
  },
  section: {
    padding: "0 14px 14px",
  },
  sectionLabel: {
    display: "flex",
    alignItems: "center",
    gap: 5,
    fontSize: 12,
    fontWeight: 500,
    color: "#444",
    marginBottom: 8,
  },
  coordRow: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 8,
  },
  coordField: {
    display: "flex",
    flexDirection: "column",
    gap: 3,
  },
  coordLabel: {
    fontSize: 11,
    color: "#888",
  },
  input: {
    padding: "7px 10px",
    borderRadius: 7,
    border: "0.5px solid #d0d0d0",
    fontSize: 13,
    color: "#1a1a1a",
    background: "#fafafa",
    outline: "none",
    width: "100%",
    boxSizing: "border-box",
  },
  locationBtn: {
    marginTop: 8,
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    padding: "6px 10px",
    background: "transparent",
    border: "0.5px solid #1B5E20",
    color: "#1B5E20",
    borderRadius: 7,
    fontSize: 12,
    fontWeight: 500,
    cursor: "pointer",
  },
  tip: {
    display: "flex",
    alignItems: "flex-start",
    gap: 6,
    margin: "0 14px 14px",
    padding: "8px 10px",
    background: "#F7F8F5",
    borderRadius: 7,
    fontSize: 11,
    color: "#888",
    lineHeight: 1.5,
  },
};
