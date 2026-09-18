import time
import json
import urllib.request
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.edge.options import Options

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_IMAGE = BASE_DIR / "dashboard_screenshot.png"
ARTIFACT_IMAGE = Path(r"C:\Users\ASUS\.gemini\antigravity\brain\f77fdd50-c8d2-47f1-9f10-f45ba95dd044\dashboard_screenshot.png")

# First inject 3 active clusters of pings to the backend so live shuttles are immediately detected!
routes_file = BASE_DIR / "backend" / "data" / "routes.json"
with open(routes_file, "r") as f:
    routes_data = json.load(f)

r1 = routes_data["routes"][0]["polyline"]
r2 = routes_data["routes"][1]["polyline"]

now = time.time()
test_pings = []

# Cluster 1 on Route 1 (near Stop 7 / Stop 8) - 8 riders
for i in range(8):
    pt = r1[70]
    test_pings.append({
        "rider_id": f"rider_a_{i+1}",
        "latitude": pt[0] + (i * 0.00002),
        "longitude": pt[1] + (i * 0.00002),
        "speed_mps": 4.5,
        "heading": 85.0,
        "timestamp": now,
        "is_on_shuttle": True,
        "route_hint": "route_1"
    })

# Cluster 2 on Route 1 (near Stop 11 / Men's Hostel) - 5 riders
for i in range(5):
    pt = r1[180]
    test_pings.append({
        "rider_id": f"rider_b_{i+1}",
        "latitude": pt[0] + (i * 0.00002),
        "longitude": pt[1] + (i * 0.00002),
        "speed_mps": 4.8,
        "heading": 70.0,
        "timestamp": now,
        "is_on_shuttle": True,
        "route_hint": "route_1"
    })

# Cluster 3 on Route 2 (near Ladies Hostel / SMV) - 6 riders
for i in range(6):
    pt = r2[35]
    test_pings.append({
        "rider_id": f"rider_c_{i+1}",
        "latitude": pt[0] + (i * 0.00002),
        "longitude": pt[1] + (i * 0.00002),
        "speed_mps": 4.2,
        "heading": 240.0,
        "timestamp": now,
        "is_on_shuttle": True,
        "route_hint": "route_2"
    })

print(f"Injecting {len(test_pings)} test pings for live cluster detection...")
for p in test_pings:
    try:
        req = urllib.request.Request(
            "http://127.0.0.1:8000/api/v1/ping",
            data=json.dumps(p).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=1.0) as resp:
            pass
    except Exception as e:
        print("Ping error:", e)

print("Opening headless Edge browser...")
options = Options()
options.add_argument('--headless')
options.add_argument('--disable-gpu')
options.add_argument('--window-size=1480,920')
options.add_argument('--disable-application-cache')

driver = webdriver.Edge(options=options)
try:
    url = f"http://127.0.0.1:8000/dashboard?t={int(now)}"
    print(f"Navigating to {url}...")
    driver.get(url)
    time.sleep(4)
    driver.save_screenshot(str(OUTPUT_IMAGE))
    driver.save_screenshot(str(ARTIFACT_IMAGE))
    print(f"Screenshot successfully saved to {OUTPUT_IMAGE} and {ARTIFACT_IMAGE}")
finally:
    driver.quit()
