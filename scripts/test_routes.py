import urllib.request
import json

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

def fetch_osrm_route(stops):
    coords_str = ";".join(f"{lon},{lat}" for name, lat, lon in stops)
    url = f"http://router.project-osrm.org/route/v1/driving/{coords_str}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={"User-Agent": "InertiaApp/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        if data.get("code") == "Ok":
            return data["routes"][0]["geometry"]["coordinates"], data["routes"][0]["distance"]
        else:
            raise Exception(f"OSRM error: {data}")

c1, d1 = fetch_osrm_route(route1_stops)
print(f"Route 1: {len(c1)} points, distance {d1:.1f} meters")

c2, d2 = fetch_osrm_route(route2_stops)
print(f"Route 2: {len(c2)} points, distance {d2:.1f} meters")
