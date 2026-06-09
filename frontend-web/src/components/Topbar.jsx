import React, { useState } from "react";
import { useLocation } from "react-router-dom";

const PAGE_TITLES = {
  "/":        "Overview",
  "/map":     "Live map",
  "/alerts":  "Alerts",
  "/drone":   "Drone analysis",
  "/reports": "Reports",
  "/settings":"Settings",
};

export default function Topbar() {
  const location = useLocation();
  const [showMenu, setShowMenu] = useState(false);

  const title = PAGE_TITLES[location.pathname] || "WheatGuard";

  const logout = () => {
    localStorage.removeItem("token");
    window.location.href = "/login";
  };

  return (
    <header style={styles.bar}>
      <span style={styles.title}>{title}</span>

      <div style={styles.actions}>
        <div style={styles.badge}>
          <i className="ti ti-wifi" style={{ fontSize: 13 }} aria-hidden="true" />
          Live
        </div>

        <div style={{ position: "relative" }}>
          <button
            style={styles.iconBtn}
            onClick={() => setShowMenu(!showMenu)}
            aria-label="Account menu"
          >
            <div style={styles.avatar}>A</div>
          </button>

          {showMenu && (
            <div style={styles.dropdown}>
              <div style={styles.dropdownUser}>
                <div style={styles.dropdownName}>Admin</div>
                <div style={styles.dropdownEmail}>admin@wheatguard.com</div>
              </div>
              <div style={styles.dropdownDivider} />
              <button style={styles.dropdownItem} onClick={logout}>
                <i className="ti ti-logout" style={{ fontSize: 14 }} aria-hidden="true" />
                Sign out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

const styles = {
  bar: {
    height: 56,
    background: "#fff",
    borderBottom: "0.5px solid rgba(0,0,0,0.08)",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "0 20px",
    flexShrink: 0,
    zIndex: 100,
  },
  title: {
    fontSize: 15,
    fontWeight: 500,
    color: "#1a1a1a",
  },
  actions: {
    display: "flex",
    alignItems: "center",
    gap: 12,
  },
  badge: {
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    background: "#EAF3DE",
    color: "#3B6D11",
    fontSize: 12,
    fontWeight: 500,
    padding: "4px 10px",
    borderRadius: 20,
  },
  iconBtn: {
    background: "transparent",
    border: "none",
    cursor: "pointer",
    padding: 0,
    display: "flex",
    alignItems: "center",
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: "50%",
    background: "#1B5E20",
    color: "#fff",
    fontSize: 13,
    fontWeight: 500,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
  },
  dropdown: {
    position: "absolute",
    right: 0,
    top: 40,
    background: "#fff",
    border: "0.5px solid rgba(0,0,0,0.1)",
    borderRadius: 10,
    boxShadow: "0 4px 16px rgba(0,0,0,0.1)",
    width: 200,
    zIndex: 999,
    overflow: "hidden",
  },
  dropdownUser: {
    padding: "12px 14px 10px",
  },
  dropdownName: {
    fontSize: 13,
    fontWeight: 500,
    color: "#1a1a1a",
  },
  dropdownEmail: {
    fontSize: 11,
    color: "#888",
    marginTop: 2,
  },
  dropdownDivider: {
    height: "0.5px",
    background: "rgba(0,0,0,0.08)",
  },
  dropdownItem: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    width: "100%",
    padding: "10px 14px",
    background: "transparent",
    border: "none",
    cursor: "pointer",
    fontSize: 13,
    color: "#c62828",
    textAlign: "left",
  },
};
