import React, { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";

const NAV_ITEMS = [
  { text: "Dashboard",      icon: "ti-layout-dashboard", path: "/" },
  { text: "Live map",       icon: "ti-map-2",            path: "/map" },
  { text: "Alerts",         icon: "ti-bell",             path: "/alerts" },
  { text: "Drone analysis", icon: "ti-drone",            path: "/drone" },
  { text: "Reports",        icon: "ti-chart-bar",        path: "/reports" },
  { text: "Settings",       icon: "ti-settings",         path: "/settings" },
];

export default function Sidebar() {
  const navigate  = useNavigate();
  const location  = useLocation();
  const [hovered, setHovered] = useState(null);

  return (
    <aside style={styles.sidebar}>
      <div style={styles.brand}>
        <img
          src="/logo.png"
          alt="WheatGuard logo"
          style={styles.logoImg}
          onError={(e) => {
            // fallback to icon if image fails to load
            e.target.style.display = "none";
            e.target.nextSibling.style.display = "flex";
          }}
        />
        <div style={{ ...styles.logoIcon, display: "none" }}>
          <i className="ti ti-plant-2" style={{ color: "#fff", fontSize: 18 }} aria-hidden="true" />
        </div>
        <span style={styles.brandName}>WheatGuard</span>
      </div>

      <div style={styles.divider} />

      <nav style={styles.nav}>
        {NAV_ITEMS.map((item) => {
          const active = location.pathname === item.path ||
            (item.path !== "/" && location.pathname.startsWith(item.path));
          return (
            <button
              key={item.path}
              onClick={() => navigate(item.path)}
              onMouseEnter={() => setHovered(item.path)}
              onMouseLeave={() => setHovered(null)}
              style={{
                ...styles.navItem,
                ...(active ? styles.navItemActive : {}),
                ...(hovered === item.path && !active ? styles.navItemHover : {}),
              }}
              aria-current={active ? "page" : undefined}
            >
              <i
                className={`ti ${item.icon}`}
                style={{ fontSize: 17, flexShrink: 0 }}
                aria-hidden="true"
              />
              <span style={styles.navLabel}>{item.text}</span>
            </button>
          );
        })}
      </nav>

      <div style={styles.footer}>
        <div style={styles.footerText}>
          <i className="ti ti-shield-check" style={{ fontSize: 13, marginRight: 5 }} aria-hidden="true" />
          Admin portal
        </div>
      </div>
    </aside>
  );
}

const styles = {
  sidebar: {
    width: 220,
    flexShrink: 0,
    background: "#1B5E20",
    display: "flex",
    flexDirection: "column",
    height: "100vh",
    overflow: "hidden",
  },
  brand: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    padding: "20px 16px 18px",
  },
  logoImg: {
    width: 32,
    height: 32,
    borderRadius: 8,
    objectFit: "cover",
    flexShrink: 0,
  },
  logoIcon: {
    width: 32,
    height: 32,
    background: "rgba(255,255,255,0.15)",
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  brandName: {
    fontSize: 15,
    fontWeight: 500,
    color: "#fff",
    letterSpacing: "0.01em",
  },
  divider: {
    height: "0.5px",
    background: "rgba(255,255,255,0.12)",
    margin: "0 16px 10px",
  },
  nav: {
    flex: 1,
    display: "flex",
    flexDirection: "column",
    gap: 2,
    padding: "0 8px",
    overflowY: "auto",
  },
  navItem: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    padding: "9px 12px",
    borderRadius: 8,
    border: "none",
    background: "transparent",
    color: "rgba(255,255,255,0.7)",
    cursor: "pointer",
    textAlign: "left",
    fontSize: 13,
    fontWeight: 400,
    transition: "background 0.15s, color 0.15s",
    width: "100%",
  },
  navItemActive: {
    background: "rgba(255,255,255,0.18)",
    color: "#fff",
    fontWeight: 500,
  },
  navItemHover: {
    background: "rgba(255,255,255,0.08)",
    color: "rgba(255,255,255,0.9)",
  },
  navLabel: { fontSize: 13 },
  footer: {
    padding: "12px 16px",
    borderTop: "0.5px solid rgba(255,255,255,0.1)",
  },
  footerText: {
    fontSize: 11,
    color: "rgba(255,255,255,0.45)",
    display: "flex",
    alignItems: "center",
  },
};
