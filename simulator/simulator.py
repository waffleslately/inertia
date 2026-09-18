import time
import math
import json
import random
import urllib.request
import urllib.error
import argparse
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
ROUTES_FILE = BASE_DIR / "backend" / "data" / "routes.json"

def haversine(lat1, lon1, lat2, lon2):
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def compute_bearing(lat1, lon1, lat2, lon2):
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dlambda = math.radians(lon2 - lon1)
    y = math.sin(dlambda) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlambda)
    return (math.degrees(math.atan2(y, x)) + 360) % 360

class VirtualShuttleGroup:
    def __init__(self, group_id: str, route_id: str, polyline: list, rider_count: int = 5, speed_kmh: float = 18.0):
        self.group_id = group_id
        self.route_id = route_id
        self.polyline = polyline
        self.rider_count = rider_count
        self.speed_mps = speed_kmh / 3.6
        self.current_seg_idx = 0
        self.seg_progress_m = 0.0
        self.stop_dwell_time = 0.0
        self.riders = [f"rider_{group_id}_{i+1}" for i in range(rider_count)]

        # Initial position
        p1 = polyline[0]
        self.current_lat = p1[0]
        self.current_lng = p1[1]
        self.heading = 0.0

    def step(self, dt: float):
        if self.stop_dwell_time > 0:
            self.stop_dwell_time -= dt
            return

        p1 = self.polyline[self.current_seg_idx]
        p2 = self.polyline[(self.current_seg_idx + 1) % len(self.polyline)]
        seg_dist = haversine(p1[0], p1[1], p2[0], p2[1])

        self.seg_progress_m += self.speed_mps * dt
        self.heading = compute_bearing(p1[0], p1[1], p2[0], p2[1])

        if self.seg_progress_m >= seg_dist:
            # Advance to next segment
            self.seg_progress_m = 0.0
            self.current_seg_idx = (self.current_seg_idx + 1) % (len(self.polyline) - 1)
            # Occasional pause at campus stops
            if random.random() < 0.35:
                self.stop_dwell_time = random.uniform(8.0, 16.0)

        # Interpolate position
        ratio = max(0.0, min(1.0, self.seg_progress_m / max(seg_dist, 1.0)))
        self.current_lat = p1[0] + ratio * (p2[0] - p1[0])
        self.current_lng = p1[1] + ratio * (p2[1] - p1[1])

    def generate_pings(self) -> list:
        pings = []
        now = time.time()
        is_stationary = self.stop_dwell_time > 0
        speed = 0.0 if is_stationary else self.speed_mps

        for i, rider_id in enumerate(self.riders):
            # Realistic GPS jitter (around 2-6 meters)
            jitter_lat = (random.random() - 0.5) * 0.00004
            jitter_lng = (random.random() - 0.5) * 0.00004
            pings.append({
                "rider_id": rider_id,
                "latitude": self.current_lat + jitter_lat,
                "longitude": self.current_lng + jitter_lng,
                "speed_mps": speed + (0.0 if is_stationary else (random.random() - 0.5) * 0.4),
                "heading": self.heading + (random.random() - 0.5) * 8.0,
                "timestamp": now,
                "is_on_shuttle": True,
                "route_hint": self.route_id
            })
        return pings

def run_simulation(backend_url: str = "http://127.0.0.1:8000", duration_seconds: int = 300, interval: float = 1.5):
    print(f"Loading routes from {ROUTES_FILE}...")
    with open(ROUTES_FILE, "r") as f:
        data = json.load(f)

    routes = {r["id"]: r for r in data["routes"]}
    print(f"Loaded routes: {list(routes.keys())}")

    # Create 3 virtual shuttle groups
    shuttles = [
        # Shuttle 1 on Route 1 (Main Loop) - 6 co-moving riders
        VirtualShuttleGroup("shuttle_alpha", "route_1", routes["route_1"]["polyline"], rider_count=6, speed_kmh=18.0),
        # Shuttle 2 on Route 1 (Main Loop, spaced half route away) - 4 riders
        VirtualShuttleGroup("shuttle_beta", "route_1", routes["route_1"]["polyline"][len(routes["route_1"]["polyline"])//2:] + routes["route_1"]["polyline"][:len(routes["route_1"]["polyline"])//2], rider_count=4, speed_kmh=17.0),
        # Shuttle 3 on Route 2 (Academic Express) - 8 riders
        VirtualShuttleGroup("shuttle_gamma", "route_2", routes["route_2"]["polyline"], rider_count=8, speed_kmh=16.0),
    ]

    print(f"Starting Inertia GPS Simulation...")
    print(f"Streaming {sum(s.rider_count for s in shuttles)} virtual riders across {len(shuttles)} shuttles to {backend_url}")
    print("Press Ctrl+C to stop.")

    start_time = time.time()
    ping_count = 0

    try:
        while time.time() - start_time < duration_seconds:
            for s in shuttles:
                s.step(interval)
                pings = s.generate_pings()
                for p in pings:
                    try:
                        req_data = json.dumps(p).encode('utf-8')
                        req = urllib.request.Request(
                            f"{backend_url}/api/v1/ping",
                            data=req_data,
                            headers={'Content-Type': 'application/json'},
                            method='POST'
                        )
                        with urllib.request.urlopen(req, timeout=1.5) as resp:
                            pass
                        ping_count += 1
                    except Exception:
                        pass

            print(f"[{time.strftime('%H:%M:%S')}] Ingested {ping_count} pings | Active Shuttles: {len(shuttles)}", end="\r")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nSimulation stopped by user.")
    print(f"\nSimulation completed. Total pings sent: {ping_count}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Inertia VIT Shuttle GPS Simulator")
    parser.add_argument("--url", default="http://127.0.0.1:8000", help="FastAPI backend URL")
    parser.add_argument("--duration", type=int, default=3600, help="Duration in seconds")
    parser.add_argument("--interval", type=float, default=1.5, help="Ping interval in seconds")
    args = parser.parse_args()

    run_simulation(backend_url=args.url, duration_seconds=args.duration, interval=args.interval)
