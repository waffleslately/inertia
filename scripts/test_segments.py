import urllib.request
import json
import math

def haversine(lat1, lon1, lat2, lon2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

route1_stops = [
    ("Main Gate", 12.968497, 79.156119),
    ("Library", 12.968785, 79.156892),
    ("SMV", 12.968795, 79.157792),
    ("Greenos", 12.969762, 79.158502),
    ("Tunnel", 12.970904, 79.158335),
    ("Stop 6", 12.972033, 79.157103),
    ("Stop 7", 12.972786, 79.156682),
    ("Stop 8", 12.972731, 79.158334),
    ("Stop 9", 12.972605, 79.160879),
    ("Stop 10", 12.972070, 79.161842),
    ("Stop 11", 12.973076, 79.163859),
    ("Stop 12", 12.973511, 79.164487),
    ("Men's Hostel", 12.973860, 79.165624)
]

print("=== Checking Route 1 Segments ===")
for i in range(len(route1_stops) - 1):
    s1, lat1, lon1 = route1_stops[i]
    s2, lat2, lon2 = route1_stops[i+1]
    straight = haversine(lat1, lon1, lat2, lon2)
    url = f"http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={"User-Agent": "Inertia/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode())
        dist = data["routes"][0]["distance"]
        ratio = dist / straight
        flag = ">>> FLAGGED (>2x)" if ratio > 2.0 else "OK"
        print(f"{s1} -> {s2}: straight={straight:.1f}m, driving={dist:.1f}m (ratio={ratio:.2f}x) {flag}")

route2_stops = [
    ("PRP", 12.972678, 79.167190),
    ("Stop 2", 12.971867, 79.163765),
    ("Stop 3", 12.970796, 79.163225),
    ("Stop 4", 12.970404, 79.162577),
    ("Stop 5", 12.968976, 79.160465),
    ("Ladies Hostel", 12.968613, 79.159280),
    ("SMV", 12.968732, 79.158345),
    ("Main Gate", 12.968517, 79.156206)
]

print("\n=== Checking Route 2 Segments ===")
for i in range(len(route2_stops) - 1):
    s1, lat1, lon1 = route2_stops[i]
    s2, lat2, lon2 = route2_stops[i+1]
    straight = haversine(lat1, lon1, lat2, lon2)
    url = f"http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={"User-Agent": "Inertia/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode())
        dist = data["routes"][0]["distance"]
        ratio = dist / straight
        flag = ">>> FLAGGED (>2x)" if ratio > 2.0 else "OK"
        print(f"{s1} -> {s2}: straight={straight:.1f}m, driving={dist:.1f}m (ratio={ratio:.2f}x) {flag}")
