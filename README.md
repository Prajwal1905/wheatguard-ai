WheatGuard AI — Smart Crop Disease Monitoring & Alert System

Full-Stack AI-Powered Agricultural Monitoring Platform

WheatGuard AI is an end-to-end intelligent crop monitoring system that detects wheat diseases using deep learning, maps outbreaks geographically, monitors crop stress using satellite NDVI data, and sends real-time alerts to farmers.

The system works both online and offline and supports multi-language farmers (English, Hindi, Marathi).

Key Features
AI Disease Detection
EfficientNet-B3 CNN model (19 disease classes)
On-device detection using TensorFlow Lite (offline capable)
Server-side ONNX inference for high accuracy
Confidence & severity classification

Smart Field Mapping
Register farm with GPS boundary polygon
Satellite NDVI crop health monitoring
Stress detection & history tracking
Interactive outbreak heatmap

Real-Time Alert System
FCM push notifications
Geo-based disease outbreak alerts
Alert history tracking
Admin monitoring dashboard

Offline-First Mobile App
Local detection sync when internet returns
Image watermark with GPS + timestamp
Works in low connectivity rural areas

Admin Surveillance Dashboard
Live detection feed
Drone image analysis
NDVI analytics charts
Outbreak monitoring map

Tech Stack

AI / ML
PyTorch (training)
ONNX Runtime (server inference)
TensorFlow Lite (mobile inference)
OpenCV / PIL

Backend
FastAPI
PostgreSQL
SQLAlchemy
WebSockets
FCM Notifications

Mobile App
Flutter
Offline sync system
GPS & camera integration
Multi-language support

Web Dashboard
React (Vite)
Realtime monitoring UI

System Architecture
Mobile App → FastAPI Backend → PostgreSQL → AI Model → Alerts → Dashboard

How To Run
Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

Mobile App
cd frontend_mobile/wheat_disease_clean
flutter pub get
flutter run

Web Dashboard
cd frontend-web
npm install
npm run dev

Author
Prajwal Khade
AI + Full Stack Developer

Project Purpose (SIH GRAND FINALIST PROJECT)
Built to assist farmers in early disease detection and reduce crop loss using AI + satellite monitoring.