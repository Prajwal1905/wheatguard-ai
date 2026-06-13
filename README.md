An AI-powered wheat disease detection and monitoring platform for Indian farmers.
Built for Smart India Hackathon 2025 — Selected in Top 5 Projects Nationally.

WheatGuard AI combines mobile disease detection, satellite NDVI monitoring, drone analysis,
and real-time outbreak alerts into one unified system for Indian wheat farmers.

---

## Table of Contents

- [About the Project](#about-the-project)
- [Demo Videos](#demo-videos)
- [SIH 2025 Achievement](#sih-2025-achievement)
- [Problem Statement](#problem-statement)
- [Features](#features)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Running with Docker](#running-with-docker)
- [Flutter Mobile App](#flutter-mobile-app)
- [Model Training](#model-training)
- [API Documentation](#api-documentation)
- [Disease Classes](#disease-classes)
- [Update and Deployment Workflow](#update-and-deployment-workflow)
- [Author](#author)

---

## About the Project

WheatGuard AI is a full-stack agricultural intelligence system that helps Indian wheat farmers
detect crop diseases early, monitor field health using satellite NDVI data, and receive
real-time outbreak alerts in their local language.

The system consists of three parts:

- Flutter Mobile App — for farmers to capture and detect wheat diseases offline and online
- React Admin Dashboard — for agronomists to monitor detections, alerts, maps, and drone analysis
- FastAPI Backend — AI inference, NDVI monitoring, real-time socket alerts, and database management

---

## Demo Videos

| Demo | Link |
|---|---|
| Mobile App Demo | [Watch Mobile App Demo](https://drive.google.com/drive/u/0/folders/1BtP6JX5aHjyIPh-mO1HGKTnorw-nyjvn) |
| Dashboard Demo | [Watch Dashboard Demo](https://drive.google.com/drive/u/0/folders/1BtP6JX5aHjyIPh-mO1HGKTnorw-nyjvn) |

---

## SIH 2025 Achievement

This project was built for Smart India Hackathon 2025 and was selected among the
Top 5 Projects Nationally in the agriculture and rural development category.

The project addresses a real problem faced by wheat farmers in India — late detection
of crop diseases leading to massive yield loss every year. WheatGuard AI provides
an affordable, multilingual, offline-capable solution that works even in low connectivity
rural areas.

---

## Problem Statement

| Field | Detail |
|---|---|
| Problem Statement ID | 25268 |
| Title | Early Detection of Wheat Diseases |
| Organization | Ministry of Agriculture & Farmers Welfare (MoA&FW) |
| Department | Department of Agriculture & Farmers Welfare (DoA&FW) — Crops |
| Category | Software |
| Theme | Agriculture, FoodTech & Rural Development |

### Description (as given by the Ministry)

Wheat is affected by several diseases — primarily fungal diseases like rusts, smuts,
powdery mildew, and root and head blights, but also bacterial and viral diseases such
as Black Chaff and Barley Yellow Dwarf Virus (BYDV). These pathogens cause symptoms
ranging from leaf spots and wilting to blighting of the ears and grain, leading to
significant yield losses. Major wheat diseases such as rusts, blight, and Karnal bunt
often spread rapidly, causing widespread crop damage if not detected early.

### Expected Solution

Development of AI/ML-based image recognition tools integrated with drone/satellite
data and mobile apps to provide real-time detection, mapping, and alerts to farmers.

### How WheatGuard AI Addresses This

| Expected Solution Component | WheatGuard AI Implementation |
|---|---|
| AI/ML-based image recognition | 19-class EfficientNet-B3 ONNX model, detecting all major fungal (rust, smut, blight, Karnal bunt, powdery mildew), bacterial (Black Chaff), and viral (BYDV) diseases listed in the problem statement |
| Drone data integration | Dedicated Drone Analysis page — officers survey fields, model analyzes images, admin reviews results and decides whether to alert nearby farmers |
| Satellite data integration | Live Sentinel-2 NDVI (Copernicus CDSE) with cloud masking, plus NASA VIIRS/MODIS — detects crop stress before visible symptoms appear |
| Mobile app for farmers | Flutter app — offline-capable, multilingual (English/Hindi/Marathi), voice input, AI chatbot, text-to-speech remedies |
| Real-time detection, mapping, and alerts | Socket.IO live map updates, FCM push notifications to farmers within a configurable radius, geotagged detection mapping |

---

## Features

### Mobile App (Flutter)

- Capture or upload wheat crop images
- AI disease detection — online via ONNX model, offline via TFLite
- Multilingual support — English, Hindi, Marathi
- Live disease map with nearby outbreak alerts
- Detection history with PDF export
- Field registration with GPS polygon boundary mapping
- Push notifications for nearby disease outbreaks via Firebase FCM
- AI chatbot for farmer doubts (Krishi Sevak AI)
- Text-to-speech remedy reading
- Voice input for chatbot questions
- Offline-first with automatic sync when back online
- Watermarked photos with GPS coordinates and timestamp

### Admin Dashboard (React)

- Real-time disease detection dashboard
- Live disease map with heatmap and satellite NDVI overlay
- Drone image analysis and mapping
- NDVI stress monitoring using Sentinel-2 and NASA VIIRS
- Multi-source alert management — NDVI stress, drone, and manual alerts
- Reports with CSV and PDF export
- Live WebSocket feed for new detections
- JWT-based admin authentication
- Resolve/reopen lifecycle for detections and NDVI stress alerts —
  admin can dismiss handled issues (hidden from map/alerts, kept in DB
  for history); NDVI stress alerts auto-resolve when crop health recovers
- Drone analysis uses a "review then alert" flow — admin sees the AI
  result first and explicitly decides whether to notify nearby farmers,
  rather than auto-alerting on every detection

### Backend (FastAPI)

- 19-class EfficientNet-B3 ONNX wheat disease model
- Sentinel-2 NDVI via Copernicus CDSE API
- NASA VIIRS and MODIS NDVI tile serving
- Real-time Socket.IO broadcasting
- FCM push notifications with 5km geofencing
- Scheduled daily NDVI stress scanning via APScheduler
- PostgreSQL with PostGIS database
- Supabase storage for detection images
- AI remedy generation via OpenRouter (Grok model)
- Redis-backed caching (NDVI values, 24h TTL) and rate limiting,
  with graceful fail-open if Redis is unavailable
- Bcrypt-hashed admin credentials with constant-time comparison
- Upload validation — rejects oversized or non-image files before
  they reach the ML pipeline
- Sentinel-2 NDVI requests use a 30-day lookback with least-cloud
  mosaicking and SCL-based cloud masking for accurate readings

---

## Project Structure

```
wheatguard-ai/
│
├── backend/                          # FastAPI Python backend
│   ├── app/
│   │   ├── api/                      # API route handlers
│   │   │   ├── admin_auth.py         # JWT authentication
│   │   │   ├── alerts.py             # Disease alerts
│   │   │   ├── detections.py         # Disease detection
│   │   │   ├── drone.py              # Drone image analysis
│   │   │   ├── fields.py             # Field registration
│   │   │   ├── fcm_tokens.py         # Push notifications
│   │   │   ├── nasa_ndvi.py          # NASA NDVI data
│   │   │   ├── sentinel_ndvi.py      # Sentinel-2 NDVI
│   │   │   ├── ndvi_history.py       # NDVI history tracking
│   │   │   ├── upload.py             # Image uploads
│   │   │   ├── local_sync.py         # Offline detection sync
│   │   │   └── ai_explain.py         # AI remedy and chatbot
│   │   ├── db/
│   │   │   └── database.py           # SQLAlchemy setup
│   │   ├── ml/
│   │   │   ├── model_utils.py        # ONNX inference engine
│   │   │   ├── ai_helper.py          # AI remedy generation
│   │   │   └── wheat_disease_b3.onnx # ML model (download separately)
│   │   ├── models/                   # SQLAlchemy database models
│   │   ├── middleware/               # JWT auth middleware
│   │   ├── utils/                    # Socket, FCM, Supabase, cache, rate limiter helpers
│   │   ├── main.py                   # FastAPI application entry point
│   │   └── scheduler.py              # Scheduled NDVI scan jobs
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env                          # Secret keys - not in git
│
├── frontend-web/                     # React Admin Dashboard
│   ├── src/
│   │   ├── pages/                    # Dashboard, LiveMap, Alerts, Reports, Drone
│   │   ├── components/               # MapView, StatsCards, Charts, etc.
│   │   ├── services/
│   │   │   ├── api.js                # Axios API client with auth interceptor
│   │   │   └── socket.js             # Socket.IO real-time client
│   │   └── layout/                   # AdminLayout, Sidebar, Topbar
│   ├── Dockerfile
│   ├── nginx.conf
│   └── .env                          # Not in git
│
├── frontend_mobile/
│   └── wheat_disease_clean/          # Flutter Mobile App
│       ├── lib/
│       │   ├── pages/                # All app screens
│       │   ├── services/             # API, notification, speech services
│       │   ├── utils/                # Disease names, watermark helper
│       │   └── config.dart           # Base URL configuration
│       └── pubspec.yaml
│
├── docker-compose.yml                # Full stack Docker orchestration
├── .env                              # Root env for Postgres variables
└── .gitignore
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.35, Dart 3.9 |
| Frontend | React 19, Vite, Material UI, Leaflet, Recharts |
| Backend | FastAPI, Python 3.10, SQLAlchemy, Uvicorn |
| Database | PostgreSQL 15 with PostGIS |
| Cache / Rate Limiting | Redis |
| ML Model | EfficientNet-B3 ONNX (19 disease classes) |
| Offline ML | TFLite (on-device Flutter inference) |
| AI Chatbot | OpenRouter API with Grok model |
| Satellite NDVI | Sentinel-2 via Copernicus CDSE and NASA VIIRS/MODIS |
| Image Storage | Supabase Storage |
| Realtime | Socket.IO |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Authentication | JWT (JSON Web Tokens) |
| Security | Bcrypt password hashing, JWT auth, Redis-backed rate limiting, image upload validation |
| Containerization | Docker and Docker Compose |
| Web Server | Nginx |

---

## Getting Started

### Prerequisites

- Docker Desktop installed and running
  Download: https://www.docker.com/products/docker-desktop/
- Git installed
- API keys for Sentinel, Supabase, OpenRouter, and Firebase

### Clone the Repository

```bash
git clone https://github.com/Prajwal1905/wheatguard-ai.git
cd wheatguard-ai
```

### Add the ONNX Model

The ML model file is too large for GitHub (42MB). Download it and place at:

```
backend/app/ml/wheat_disease_b3.onnx
```

Download link:
https://drive.google.com/file/d/1_9LBfR38U32R03_DwxgWtw0XsIW61PJH/view?usp=sharing

Or download directly via command line:

```bash
# Install gdown first
pip install gdown

# Download model directly to correct folder
gdown 1_9LBfR38U32R03_DwxgWtw0XsIW61PJH -O backend/app/ml/wheat_disease_b3.onnx
```

---

## Environment Variables

### Root `.env` (create at project root)

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
POSTGRES_DB=wheatguard
POSTGRES_PORT=5432
```

### `backend/.env` (create inside backend folder)

```env
# Database
DATABASE_URL=postgresql+psycopg2://postgres:your_password@db:5432/wheatguard

# Cache / Rate limiting
REDIS_URL=redis://redis:6379/0

# AI Chatbot
OPENROUTER_API_KEY=your_openrouter_key

# Sentinel-2 NDVI
SENTINEL_CLIENT_ID=your_sentinel_client_id
SENTINEL_CLIENT_SECRET=your_sentinel_secret
SENTINEL_INSTANCE_ID=your_sentinel_instance_id

# Planet (optional)
PLANET_API_KEY=your_planet_key
PLANET_USER_ID=your_planet_user_id

# Supabase Storage
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_key
SUPABASE_BUCKET=detections

# Firebase Push Notifications
FCM_SERVER_KEY=your_fcm_server_key

# Admin Authentication
ADMIN_EMAIL=admin@yourdomain.com
# Generate with: python -c "import bcrypt; print(bcrypt.hashpw(b'your_password', bcrypt.gensalt()).decode())"
ADMIN_PASSWORD_HASH=your_bcrypt_hash
# Generate with: python -c "import secrets; print(secrets.token_hex(32))"
ADMIN_SECRET=your_jwt_secret_key
```

### `frontend-web/.env` (create inside frontend-web folder)

```env
VITE_API_BASE=http://localhost:8000
```

---

## Running with Docker

```bash
# Build and start all services
docker-compose up --build

# Start in background
docker-compose up --build -d

# Stop all services
docker-compose down

# Rebuild only backend
docker-compose up --build backend

# Rebuild only frontend
docker-compose up --build frontend

# Restart backend without rebuild
docker-compose restart backend
```

### Access the Application

| Service | URL |
|---|---|
| Admin Dashboard | http://localhost |
| Backend API | http://localhost:8000 |
| API Docs Swagger | http://localhost:8000/docs |
| Database | localhost:5432 |
| Redis | localhost:6379 |

---

## Flutter Mobile App

### Setup

```bash
cd frontend_mobile/wheat_disease_clean
flutter pub get
```

### Configure Backend URL

Open `lib/config.dart` and set your backend URL:

```dart
class AppConfig {
  // For testing on phone via hotspot - use your laptop IP
  static const String baseUrl = "http://YOUR_LAPTOP_IP:8000";

  // For local emulator testing
  // static const String baseUrl = "http://10.0.2.2:8000";

  // For production server
  // static const String baseUrl = "http://YOUR_SERVER_IP:8000";
}
```

To find your laptop IP on Windows:

```bash
ipconfig
# Look for IPv4 Address under your WiFi adapter
```

### Run on Device

```bash
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

APK will be at:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Model Training

The EfficientNet-B3 model was trained on Kaggle using a custom wheat disease dataset
with 19 classes including various rust types, blights, insects, and healthy crops.

View the full training notebook on Kaggle:
https://www.kaggle.com/code/prajwalkhade/notebook8c36116641

### Training Details

| Parameter | Value |
|---|---|
| Architecture | EfficientNet-B3 |
| Input Size | 380 x 380 pixels |
| Number of Classes | 19 |
| Framework | PyTorch |
| Export Format | ONNX for backend, TFLite for mobile |
| Training Platform | Kaggle GPU T4 x2 |

### Model Files

| File | Size | Purpose |
|---|---|---|
| wheat_disease_b3.onnx | 42 MB | Backend inference via ONNX Runtime |
| wheat_disease_b3_float16.tflite | ~11 MB | Flutter offline inference |

---

## API Documentation

Once the backend is running visit:

```
http://localhost:8000/docs
```

### Key Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | /detections/predict | Predict disease from image |
| GET | /detections/map_data | Get all detections for map |
| GET | /detections/{id} | Get detection detail (remedy, image, etc.) |
| PATCH | /detections/{id}/resolve | Mark detection as resolved (admin) |
| PATCH | /detections/{id}/reopen | Reopen a resolved detection |
| DELETE | /detections/{id} | Delete a detection (device-owned, mobile) |
| GET | /alerts/ | Get all disease alerts |
| POST | /alerts/ | Create new alert |
| GET | /alerts/nearby | Get alerts within configured radius |
| PATCH | /alerts/{id}/resolve | Resolve an alert |
| PATCH | /alerts/{id}/reopen | Reopen an alert |
| POST | /drone/analyze | Analyze drone image |
| POST | /drone/detections/{id}/alert | Admin sends alert to nearby farmers for a drone detection |
| GET | /api/sentinel_ndvi_value | Get Sentinel-2 NDVI for location (cloud-masked, 30-day lookback) |
| POST | /api/sentinel_ndvi_polygon | Get average NDVI for a field polygon |
| GET | /api/ndvi/stress | Get active NDVI stress alerts |
| POST | /api/ndvi/stress/scan | Run NDVI stress scan (auto-resolves recovered locations) |
| PATCH | /api/ndvi/stress/{id}/resolve | Manually resolve an NDVI stress alert |
| GET | /api/ndvi_history | Get NDVI history for location |
| GET | /fields/ | Get all registered fields |
| POST | /fields/ | Register new field with photos |
| PUT | /fields/{id} | Update field details |
| DELETE | /fields/{id} | Delete a field |
| POST | /admin/login | Admin login returns JWT token |
| POST | /ai/chat | AI chatbot reply for farmers |
| POST | /ai/remedy | Get short remedy for disease |
| POST | /ai/explain | Get detailed AI explanation |
| POST | /fcm/register | Register device FCM token |
| POST | /upload/image | Upload image to Supabase |
| POST | /sync/local-detection | Sync offline mobile detection |

---

## Disease Classes

The model detects 19 wheat conditions:

| Class | Disease | Type |
|---|---|---|
| 1 | Aphid | Insect |
| 2 | Black Rust | Fungal |
| 3 | Blast | Fungal |
| 4 | Brown Rust | Fungal |
| 5 | Common Root Rot | Fungal |
| 6 | Fusarium Head Blight | Fungal |
| 7 | Leaf Blight | Fungal |
| 8 | Mildew | Fungal |
| 9 | Mite | Insect |
| 10 | Septoria | Fungal |
| 11 | Smut | Fungal |
| 12 | Stem fly | Insect |
| 13 | Tan spot | Fungal |
| 14 | Yellow Rust | Fungal |
| 15 | BYDV | Viral |
| 16 | Black Chaff | Bacterial |
| 17 | Karnal Bunt | Fungal |
| 18 | Powdery Mildew | Fungal |
| 19 | Healthy | — |

---

## Update and Deployment Workflow

```bash
# 1. Make your code changes in VS Code

# 2. Commit your changes
git add .
git commit -m "feat: describe your change"
git push origin main

# 3. Rebuild Docker
docker-compose up --build
```

### Partial Rebuilds (faster)

```bash
# Only backend changed
docker-compose up --build backend

# Only frontend changed
docker-compose up --build frontend

# Quick restart without rebuild
docker-compose restart backend

# Database schema changed - full restart needed
docker-compose down
docker-compose up --build
```

---

## Author

Prajwal Khade

- GitHub: https://github.com/Prajwal1905
- Email: prajwalkhade19@gmail.com
- Kaggle: https://www.kaggle.com/prajwalkhade

---

## Acknowledgements

- Smart India Hackathon 2025 — Top 5 Selection
- Copernicus Data Space Ecosystem for Sentinel-2 satellite data
- NASA EARTHDATA for VIIRS and MODIS NDVI
- OpenRouter for AI chatbot API access
- Supabase for image storage
- Firebase for push notification infrastructure

---

This project was built to help Indian wheat farmers protect their crops using
artificial intelligence, satellite technology, and real-time monitoring 
making advanced agricultural tools accessible to every farmer.
