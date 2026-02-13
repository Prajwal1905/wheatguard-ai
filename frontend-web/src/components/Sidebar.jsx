import React from "react";
import { Drawer, List, ListItem, ListItemIcon, ListItemText } from "@mui/material";
import DashboardIcon from "@mui/icons-material/Dashboard";
import MapIcon from "@mui/icons-material/Map";
import AssessmentIcon from "@mui/icons-material/Assessment";
import SettingsIcon from "@mui/icons-material/Settings";
import FlightIcon from "@mui/icons-material/Flight"; // ✨ NEW
import { useNavigate, useLocation } from "react-router-dom";
import { icon } from "leaflet";
import NotificationsIcon from "@mui/icons-material/Notifications"

const menuItems = [
  { text: "Dashboard", icon: <DashboardIcon />, path: "/" },
  { text: "Live Map", icon: <MapIcon />, path: "/map" },
  { text : "Alerts" , icon: <NotificationsIcon />, path: "/alerts" },
  { text: "Drone Analysis", icon: <FlightIcon />, path: "/drone" }, 
  { text: "Reports", icon: <AssessmentIcon />, path: "/reports" },
  { text: "Settings", icon: <SettingsIcon />, path: "/settings" },
];

export default function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: 220,
        flexShrink: 0,
        "& .MuiDrawer-paper": {
          width: 220,
          boxSizing: "border-box",
          backgroundColor: "#1b5e20",
          color: "white",
        },
      }}
    >
      <h2 style={{ padding: "16px", textAlign: "center" }}>🌾 WheatGuard</h2>
      <List>
        {menuItems.map((item) => (
          <ListItem
            button
            key={item.text}
            onClick={() => navigate(item.path)}
            sx={{
              backgroundColor:
                location.pathname === item.path
                  ? "rgba(255,255,255,0.15)"
                  : "transparent",
            }}
          >
            <ListItemIcon sx={{ color: "white" }}>{item.icon}</ListItemIcon>
            <ListItemText primary={item.text} />
          </ListItem>
        ))}
      </List>
    </Drawer>
  );
}
