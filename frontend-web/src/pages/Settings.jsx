import React, { useState, useEffect } from "react";
import toast from "react-hot-toast";

export default function Settings() {
  const [theme, setTheme] = useState("light");
  const [notifications, setNotifications] = useState(true);
  const [refreshRate, setRefreshRate] = useState("30");

  useEffect(() => {
    setTheme(localStorage.getItem("theme") || "light");
    setNotifications(localStorage.getItem("notifications") !== "false");
    setRefreshRate(localStorage.getItem("refreshRate") || "30");
  }, []);

  const handleSave = () => {
    localStorage.setItem("theme", theme);
    localStorage.setItem("notifications", String(notifications));
    localStorage.setItem("refreshRate", refreshRate);
    toast.success("Settings saved");
  };

  return (
    <div style={styles.page}>
      <h1 style={styles.title}>Settings</h1>

      <Section
        icon="ti-moon"
        heading="Appearance"
        description="Choose how the interface looks"
      >
        <SettingRow label="Theme">
          <select
            value={theme}
            onChange={(e) => setTheme(e.target.value)}
            style={styles.select}
            aria-label="Theme"
          >
            <option value="light">Light</option>
            <option value="dark">Dark</option>
          </select>
        </SettingRow>
      </Section>

      <Section
        icon="ti-bell"
        heading="Notifications"
        description="Control alert and detection notifications"
      >
        <SettingRow label="Enable alerts">
          <Toggle
            checked={notifications}
            onChange={setNotifications}
            label="Enable notifications"
          />
        </SettingRow>
      </Section>

      <Section
        icon="ti-refresh"
        heading="Auto-refresh"
        description="How often the dashboard pulls new data"
      >
        <SettingRow label="Refresh interval">
          <select
            value={refreshRate}
            onChange={(e) => setRefreshRate(e.target.value)}
            style={styles.select}
            aria-label="Refresh interval"
          >
            <option value="15">Every 15 seconds</option>
            <option value="30">Every 30 seconds</option>
            <option value="60">Every 1 minute</option>
            <option value="300">Every 5 minutes</option>
          </select>
        </SettingRow>
      </Section>

      <button onClick={handleSave} style={styles.saveBtn}>
        <i className="ti ti-check" style={{ fontSize: 15 }} aria-hidden="true" />
        Save changes
      </button>
    </div>
  );
}

function Section({ icon, heading, description, children }) {
  return (
    <div style={sectionStyles.wrap}>
      <div style={sectionStyles.header}>
        <i className={`ti ${icon}`} style={sectionStyles.icon} aria-hidden="true" />
        <div>
          <div style={sectionStyles.heading}>{heading}</div>
          <div style={sectionStyles.description}>{description}</div>
        </div>
      </div>
      <div style={sectionStyles.body}>{children}</div>
    </div>
  );
}

function SettingRow({ label, children }) {
  return (
    <div style={rowStyles.row}>
      <span style={rowStyles.label}>{label}</span>
      <div>{children}</div>
    </div>
  );
}

function Toggle({ checked, onChange, label }) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      style={{
        ...toggleStyles.track,
        background: checked ? "#1B5E20" : "#d0d0d0",
      }}
    >
      <span
        style={{
          ...toggleStyles.thumb,
          transform: checked ? "translateX(18px)" : "translateX(2px)",
        }}
      />
    </button>
  );
}

const styles = {
  page: {
    padding: "24px 20px",
    maxWidth: 640,
    color: "#1a1a1a",
  },
  title: {
    fontSize: 20,
    fontWeight: 500,
    color: "#1a1a1a",
    marginBottom: 24,
  },
  select: {
    padding: "7px 10px",
    borderRadius: 7,
    border: "0.5px solid #d0d0d0",
    fontSize: 14,
    color: "#1a1a1a",
    background: "#fafafa",
    cursor: "pointer",
    outline: "none",
  },
  saveBtn: {
    marginTop: 8,
    background: "#1B5E20",
    color: "#fff",
    padding: "10px 18px",
    border: "none",
    borderRadius: 8,
    cursor: "pointer",
    fontWeight: 500,
    fontSize: 14,
    display: "inline-flex",
    alignItems: "center",
    gap: 7,
  },
};

const sectionStyles = {
  wrap: {
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.1)",
    borderRadius: 12,
    marginBottom: 16,
    overflow: "hidden",
  },
  header: {
    display: "flex",
    alignItems: "flex-start",
    gap: 12,
    padding: "14px 16px",
    borderBottom: "0.5px solid rgba(0,0,0,0.07)",
    background: "#F7F8F5",
  },
  icon: {
    fontSize: 18,
    color: "#1B5E20",
    marginTop: 1,
  },
  heading: {
    fontSize: 14,
    fontWeight: 500,
    color: "#1a1a1a",
  },
  description: {
    fontSize: 12,
    color: "#888",
    marginTop: 2,
  },
  body: {
    padding: "4px 16px",
  },
};

const rowStyles = {
  row: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "12px 0",
    borderBottom: "0.5px solid rgba(0,0,0,0.06)",
  },
  label: {
    fontSize: 14,
    color: "#333",
  },
};

const toggleStyles = {
  track: {
    width: 40,
    height: 22,
    borderRadius: 11,
    border: "none",
    cursor: "pointer",
    position: "relative",
    transition: "background 0.2s",
    padding: 0,
  },
  thumb: {
    position: "absolute",
    top: 2,
    width: 18,
    height: 18,
    background: "#fff",
    borderRadius: "50%",
    transition: "transform 0.2s",
    display: "block",
  },
};
