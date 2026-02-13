import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import Dashboard from "./pages/Dashboard";
import LiveMap from "./pages/LiveMap";
import Reports from "./pages/Reports";
import Settings from "./pages/Settings";
import Login from "./pages/Login";
import RequireAuth from "./components/RequireAuth";
import Alerts from "./pages/Alerts";

import AdminLayout from "./layout/AdminLayout";
import { Toaster } from "react-hot-toast";
import "./index.css";
import Drone from "./pages/Drone";


ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <Toaster position="bottom-right" />

      <Routes>
        
        <Route path="/login" element={<Login />} />

        
        <Route
          path="/"
          element={
            <RequireAuth>
              <AdminLayout />
            </RequireAuth>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="map" element={<LiveMap />} />
          <Route path="drone" element={<Drone />} />
          <Route path="alerts" element={<Alerts />} />
          <Route path="reports" element={<Reports />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
);

