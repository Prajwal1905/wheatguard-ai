import { io } from "socket.io-client";


const SOCKET_URL = import.meta.env.VITE_API_BASE || "http://127.0.0.1:8000";

export const socket = io(SOCKET_URL, {
  transports: ["websocket"],      
  path: "/socket.io/",            
  reconnection: true,             
  reconnectionAttempts: 5,
  reconnectionDelay: 1000,
  withCredentials: false,
  autoConnect: true,
});

socket.on("connect", () => console.log(" Connected to Socket.IO"));
socket.on("disconnect", () => console.log(" Disconnected from Socket.IO"));
socket.on("connect_error", (err) => console.error(" Socket error:", err.message));
