import axios from "axios";

const API_BASE = import.meta.env.VITE_API_BASE || "http://127.0.0.1:8000";

export const api = axios.create({
  baseURL: API_BASE,
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error?.response?.status === 401) {
      localStorage.removeItem("token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);


export const getMapData = async () => {
  const res = await api.get("/detections/map_data");
  return res.data;
};

export const getNearbyAlerts = async (lat, lon) => {
  const res = await api.get(`/alerts/nearby?lat=${lat}&lon=${lon}`);
  return res.data;
};

export async function analyzeDroneImage(formData) {
  const res = await api.post("/drone/analyze", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export const scanNDVIStress = async () => {
  const res = await api.post("/api/ndvi/stress/scan");
  return res.data;
};

export const getNDVIStressAlerts = async () => {
  const res = await api.get("/api/ndvi/stress");
  return res.data;
};
export const getNDVIStress = async () => {
  const res = await api.get("/api/ndvi/stress");
  return res.data;
};

export const getFields = async () => {
  const res = await api.get("/fields");
  return res.data;
};
