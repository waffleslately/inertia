# ⚡ Inertia — VIT Vellore Campus Shuttle Tracker

> **Crowd-Sourced Shuttle Tracking for VIT Vellore**  
> No dedicated GPS hardware on shuttles. Inertia detects real-time shuttle positions, speeds, crowd density, and arrival ETAs by clustering co-moving students' phones along known campus routes.

---

## 🚀 Key Features

### 📱 Flutter Mobile App
- **Live Campus Map**: Custom animated shuttle markers that interpolate smoothly between GPS/WebSocket updates (no jump-snapping) with rotatable vehicle bearings.
- **Pulsing Crowd Radius**: Dynamic breathing aura around each shuttle reflecting passenger density:
  - 🟢 **Low** (1-2 riders)
  - 🟡 **Medium** (3-6 riders)
  - 🔴 **Crowded** (7+ riders)
- **"I'm on the Shuttle" Morphing Check-in**:
  - Idle: Floating Electric Cyan pill (`I'm on the Shuttle`).
  - Checking In: Morphs into animated spinner syncing route snapping.
  - Active Ride: Expands into full tracking status banner (`On Route 1 • Next: SJT in 3 min`).
- **Adaptive Battery GPS**: High-frequency sampling (2s) when in motion; automatically drops to low-frequency sampling (15s) when stationary at stops to preserve student phone battery.
- **Geofence Guardian**: Stops tracking immediately if a student leaves the VIT Vellore campus bounds (`12.9640°N - 12.9785°N, 79.1510°E - 79.1675°E`).
- **Swipe-Up Ride Details Sheet**: View stops timeline, speed, crowd gauge, and fare without leaving or obstructing the live map.
- **Destination Arrival & UPI Payment**:
  - Triggers when approaching destination stop with heavy haptic feedback.
  - Prefilled ₹20 payment via standard UPI Deep Link (`upi://pay?pa=vitshuttle@okaxis&am=20.00&cu=INR`).
  - Animated glowing checkmark confirmation.
- **"My Spend" Analytics**:
  - Animated bar & trend curve chart that draws in smoothly on screen load.
  - Monthly total spend (e.g. ₹300), ride count (15 rides), and comparison metric (`+66.7% vs last month`).
  - Transaction receipts ledger with VPA and timestamps.
- **Ride History**: Past trips list with route badges, duration, timestamps, and payment statuses.

### ⚙️ FastAPI Clustering Backend
- **Haversine & Cross-Track Snapping**: Snaps incoming raw GPS pings onto high-fidelity VIT campus road polylines.
- **Spatiotemporal Clustering**: Groups riders within a 45-meter radius moving in the same direction along route segments into single `Shuttle` objects.
- **Stationary Auto-End**: Auto-completes rides if a rider stays stationary for > 2.5 minutes at a campus stop without payment.
- **Ephemeral Privacy Buffer**: Raw individual GPS pings are discarded after a 30-second rolling window — zero student identity exposure.
- **Real-Time WebSockets**: Instant updates broadcasted to mobile clients (`/ws/shuttles`) and telemetry dashboards (`/ws/debug`).

---

## 🗺️ Campus Routes (VIT Vellore)

1. **Route 1: Main Loop (TT - SJT - MH)**
   - *Stops*: Main Gate ↔ Technology Tower (TT) ↔ Silver Jubilee Tower (SJT) ↔ Men's Hostel (Q/MB Block) ↔ Foodys & Sports Arena.
   - *Color*: `#00E5FF` (Electric Cyan)
2. **Route 2: Academic & LH Express**
   - *Stops*: Ladies Hostel (PRB) ↔ Central Library ↔ SMV / Anna Auditorium ↔ Technology Tower (TT) ↔ Outdoor Stadium.
   - *Color*: `#3B82F6` (Electric Blue)

---

## 🛠️ Quickstart: Run Locally

### 1. Start the FastAPI Backend
```bash
cd backend
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```
- API Docs: [http://localhost:8000/docs](http://localhost:8000/docs)
- Live Debug Dashboard: [http://localhost:8000/dashboard](http://localhost:8000/dashboard)

### 2. Open the Live Telemetry Dashboard
Open [http://localhost:8000/dashboard](http://localhost:8000/dashboard) in any browser to observe the live VIT Vellore campus map, active routes, stops, and real-time clustered shuttles.

### 3. Run the Virtual Rider GPS Simulator
In a separate terminal, launch the simulator to generate 18-30 virtual VIT students co-moving on shuttles along campus routes:
```bash
python simulator/simulator.py --url http://127.0.0.1:8000 --interval 1.5
```
Watch the telemetry dashboard update immediately with live shuttle clusters, speed, crowd density, and ETA!

### 4. Run the Flutter Mobile App
```bash
cd app
flutter pub get
flutter run
```
*(Supports Android, iOS, and Chrome Web `flutter run -d chrome`)*

---

## 🧪 Running Backend Unit Tests
```bash
cd backend
python -m tests.test_clustering
```
Verifies Haversine accuracy, campus geofencing, co-movement clustering, and spend aggregation.

---

## 🔒 Configuration & Environment Variables (`backend/.env`)

```ini
HOST=0.0.0.0
PORT=8000
CLUSTER_RADIUS_METERS=45.0
HEADING_TOLERANCE_DEGREES=40.0
MIN_RIDERS_PER_SHUTTLE=2
AUTO_END_IDLE_SECONDS=150.0
LOCATION_EXPIRY_SECONDS=30.0
UPI_VPA=vitshuttle@okaxis
SHUTTLE_FARE_INR=20.0
CAMPUS_NAME=VIT Vellore
GEOFENCE_LAT_MIN=12.9640
GEOFENCE_LAT_MAX=12.9785
GEOFENCE_LNG_MIN=79.1510
GEOFENCE_LNG_MAX=79.1675
```
