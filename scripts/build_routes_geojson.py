import os
import json
import math
import urllib.request
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Route 1: Men's Hostel Route
raw_route1_stops = [
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

# Route 2: Ladies Hostel Route
# Named stops for markers and transit schedule
raw_route2_stops = [
    ("PRP", 12.972678, 79.167190),
    ("Stop 2", 12.971867, 79.163765),
    ("Stop 3", 12.970796, 79.163225),
    ("Stop 4", 12.970404, 79.162577),
    ("Stop 5", 12.968976, 79.160465),
    ("Ladies Hostel", 12.968613, 79.159280),
    ("SMV", 12.968732, 79.158345),
    ("Main Gate", 12.968517, 79.156206)
]

# Route 2 waypoints with intermediate bend at top-left corner of building block (12.971756, 79.163195)
# to force road-following L-shape (west along top road, south along left edge) instead of diagonal cut
route2_routing_waypoints = [
    ("PRP", 12.972678, 79.167190),
    ("Stop 2", 12.971867, 79.163765),
    ("Road Bend (Stop 2-3)", 12.971756, 79.163195),
    ("Stop 3", 12.970796, 79.163225),
    ("Stop 4", 12.970404, 79.162577),
    ("Stop 5", 12.968976, 79.160465),
    ("Ladies Hostel", 12.968613, 79.159280),
    ("SMV", 12.968732, 79.158345),
    ("Main Gate", 12.968517, 79.156206)
]

def haversine(lat1, lon1, lat2, lon2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def query_osrm(profile, lon1, lat1, lon2, lat2):
    url = f"http://router.project-osrm.org/route/v1/{profile}/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={"User-Agent": "InertiaApp/1.0"})
    with urllib.request.urlopen(req, timeout=8) as resp:
        data = json.loads(resp.read().decode())
        if data.get("code") == "Ok":
            route = data["routes"][0]
            return route["geometry"]["coordinates"], route["distance"]
    return None, None

def route_segment(s1_name, lat1, lon1, s2_name, lat2, lon2):
    straight_dist = haversine(lat1, lon1, lat2, lon2)
    
    # 1. Try driving route first
    driving_coords, driving_dist = query_osrm("driving", lon1, lat1, lon2, lat2)
    
    # Check if <= 2x straight-line distance
    if driving_dist and (driving_dist / max(straight_dist, 1.0) <= 2.0):
        print(f"  [OK: driving] {s1_name} -> {s2_name}: {driving_dist:.1f}m (straight: {straight_dist:.1f}m, {driving_dist/straight_dist:.2f}x)")
        return driving_coords, driving_dist
        
    # 1b. Check reverse driving (campus paths frequently have one-way tags in OSM)
    rev_driving_coords, rev_driving_dist = query_osrm("driving", lon2, lat2, lon1, lat1)
    if rev_driving_dist and (rev_driving_dist / max(straight_dist, 1.0) <= 2.0):
        print(f"  [RESOLVED: reverse driving] {s1_name} -> {s2_name}: {rev_driving_dist:.1f}m (straight: {straight_dist:.1f}m, {rev_driving_dist/straight_dist:.2f}x)")
        return list(reversed(rev_driving_coords)), rev_driving_dist

    print(f"  >>> [FLAGGED SEGMENT > 2x] {s1_name} -> {s2_name}: driving distance {driving_dist}m > 2x straight-line {straight_dist:.1f}m")
    
    # 2. Try walking mode for this segment
    print(f"      Attempting mode=walking for {s1_name} -> {s2_name}...")
    walking_coords, walking_dist = query_osrm("walking", lon1, lat1, lon2, lat2)
    
    if walking_dist and (walking_dist / max(straight_dist, 1.0) <= 2.0):
        print(f"      [RESOLVED: walking] {s1_name} -> {s2_name}: {walking_dist:.1f}m (ratio: {walking_dist/straight_dist:.2f}x)")
        return walking_coords, walking_dist
        
    # 2b. Check reverse walking
    rev_walking_coords, rev_walking_dist = query_osrm("walking", lon2, lat2, lon1, lat1)
    if rev_walking_dist and (rev_walking_dist / max(straight_dist, 1.0) <= 2.0):
        print(f"      [RESOLVED: reverse walking] {s1_name} -> {s2_name}: {rev_walking_dist:.1f}m (ratio: {rev_walking_dist/straight_dist:.2f}x)")
        return list(reversed(rev_walking_coords)), rev_walking_dist

    # 3. If still wrong (>2x), hardcode direct line between the two known coords
    print(f"      >>> [FALLBACK: DIRECT LINE] {s1_name} -> {s2_name}: walking still {walking_dist}m (>2x). Using direct line shortcut ({straight_dist:.1f}m).")
    direct_coords = [
        [lon1, lat1],
        [lon1 + 0.33 * (lon2 - lon1), lat1 + 0.33 * (lat2 - lat1)],
        [lon1 + 0.66 * (lon2 - lon1), lat1 + 0.66 * (lat2 - lat1)],
        [lon2, lat2]
    ]
    return direct_coords, straight_dist

def generate_route_polyline(stops):
    total_polyline = []
    total_dist = 0.0
    
    for i in range(len(stops) - 1):
        s1_name, lat1, lon1 = stops[i]
        s2_name, lat2, lon2 = stops[i+1]
        
        seg_coords, seg_dist = route_segment(s1_name, lat1, lon1, s2_name, lat2, lon2)
        total_dist += seg_dist
        
        if not total_polyline:
            total_polyline.extend(seg_coords)
        else:
            # Avoid duplicate vertex
            total_polyline.extend(seg_coords[1:])
            
    return total_polyline, total_dist

def verify_and_correct_sign(stops):
    corrected = []
    for name, lat, lon in stops:
        neg_lat = -abs(lat)
        corrected.append((name, neg_lat, lon))
    return corrected

def create_geojson(route_name, stops_corrected, polyline_coords, distance_m, color="#00E5FF"):
    geojson_polyline = [[coord[0], -abs(coord[1])] for coord in polyline_coords]

    features = [
        {
            "type": "Feature",
            "properties": {
                "name": route_name,
                "type": "route_path",
                "stroke": color,
                "stroke-width": 4,
                "distance_meters": round(distance_m, 1)
            },
            "geometry": {
                "type": "LineString",
                "coordinates": geojson_polyline
            }
        }
    ]

    for idx, (name, neg_lat, lon) in enumerate(stops_corrected, start=1):
        features.append({
            "type": "Feature",
            "properties": {
                "name": name,
                "stop_id": f"stop_{idx}",
                "sequence": idx,
                "route": route_name
            },
            "geometry": {
                "type": "Point",
                "coordinates": [lon, neg_lat]
            }
        })

    return {
        "type": "FeatureCollection",
        "name": route_name,
        "features": features
    }

def update_app_routes(r1_stops, coords1, r2_stops, coords2):
    routes_file = BASE_DIR / "backend" / "data" / "routes.json"
    data = {
        "campus": {
            "name": "VIT Vellore",
            "center": [12.9712, 79.1605],
            "geofence": [
                [12.9640, 79.1510],
                [12.9650, 79.1685],
                [12.9785, 79.1685],
                [12.9780, 79.1515],
                [12.9640, 79.1510]
            ]
        },
        "routes": [
            {
                "id": "route_1",
                "name": "Route 1: Men's Hostel Route",
                "short_name": "R1 Men's Hostel",
                "color": "#00E5FF",
                "fare": 20.0,
                "stops": [
                    {
                        "id": f"stop_1_{idx}",
                        "name": name,
                        "latitude": abs(neg_lat),
                        "longitude": lon,
                        "sequence": idx
                    }
                    for idx, (name, neg_lat, lon) in enumerate(r1_stops, 1)
                ],
                "polyline": [[abs(pt[1]), pt[0]] for pt in coords1]
            },
            {
                "id": "route_2",
                "name": "Route 2: Ladies Hostel Route",
                "short_name": "R2 Ladies Hostel",
                "color": "#3B82F6",
                "fare": 20.0,
                "stops": [
                    {
                        "id": f"stop_2_{idx}",
                        "name": name,
                        "latitude": abs(neg_lat),
                        "longitude": lon,
                        "sequence": idx
                    }
                    for idx, (name, neg_lat, lon) in enumerate(r2_stops, 1)
                ],
                "polyline": [[abs(pt[1]), pt[0]] for pt in coords2]
            }
        ]
    }
    with open(routes_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"Updated {routes_file} with corrected road polylines.")

def main():
    print("=== Generating Route 1: Men's Hostel Route with Segment Checking ===")
    coords1, dist1 = generate_route_polyline(raw_route1_stops)
    r1_corrected = verify_and_correct_sign(raw_route1_stops)
    geojson1 = create_geojson("Men's Hostel Route", r1_corrected, coords1, dist1, color="#00E5FF")

    out1_root = BASE_DIR / "menshostel_route.geojson"
    out1_data = BASE_DIR / "backend" / "data" / "menshostel_route.geojson"
    with open(out1_root, "w", encoding="utf-8") as f:
        json.dump(geojson1, f, indent=2)
    with open(out1_data, "w", encoding="utf-8") as f:
        json.dump(geojson1, f, indent=2)
    print(f"Saved {out1_root} ({len(coords1)} points, {dist1:.1f}m)")

    print("\n=== Generating Route 2: Ladies Hostel Route with Segment Checking ===")
    coords2, dist2 = generate_route_polyline(route2_routing_waypoints)
    r2_corrected = verify_and_correct_sign(raw_route2_stops)
    geojson2 = create_geojson("Ladies Hostel Route", r2_corrected, coords2, dist2, color="#3B82F6")

    out2_root = BASE_DIR / "ladieshostel_route.geojson"
    out2_data = BASE_DIR / "backend" / "data" / "ladieshostel_route.geojson"
    with open(out2_root, "w", encoding="utf-8") as f:
        json.dump(geojson2, f, indent=2)
    with open(out2_data, "w", encoding="utf-8") as f:
        json.dump(geojson2, f, indent=2)
    print(f"Saved {out2_root} ({len(coords2)} points, {dist2:.1f}m)")

    update_app_routes(r1_corrected, coords1, r2_corrected, coords2)

if __name__ == "__main__":
    main()
