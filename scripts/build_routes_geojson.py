import os
import json
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

def verify_and_correct_sign(stops):
    """
    Verifies that all latitudes are negative as instructed.
    If positive, treats as typo and corrects to negative.
    Returns: List of (name, neg_lat, lon)
    """
    corrected = []
    for name, lat, lon in stops:
        neg_lat = -abs(lat)
        corrected.append((name, neg_lat, lon))
    return corrected

def fetch_road_polyline(stops):
    """
    Fetches the road-following polyline using OSRM (with Google Directions API fallback/support).
    Uses positive coordinates for real-world road network graph matching on VIT Vellore campus.
    """
    api_key = os.environ.get("GOOGLE_MAPS_API_KEY")
    if api_key:
        try:
            origin = f"{abs(stops[0][1])},{stops[0][2]}"
            dest = f"{abs(stops[-1][1])},{stops[-1][2]}"
            wp = "|".join(f"{abs(s[1])},{s[2]}" for s in stops[1:-1])
            url = f"https://maps.googleapis.com/maps/api/directions/json?origin={origin}&destination={dest}&waypoints={wp}&key={api_key}"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode())
                if data.get("status") == "OK":
                    import polyline
                    enc = data["routes"][0]["overview_polyline"]["points"]
                    decoded = polyline.decode(enc)
                    return [[pt[1], pt[0]] for pt in decoded], data["routes"][0]["legs"]
        except Exception as e:
            print(f"Google Directions API fallback to OSRM: {e}")

    # OSRM Overpass/OSM Fallback (coordinates in lon, lat)
    coords_str = ";".join(f"{lon},{abs(lat)}" for name, lat, lon in stops)
    url = f"http://router.project-osrm.org/route/v1/driving/{coords_str}?overview=full&geometries=geojson"
    req = urllib.request.Request(url, headers={"User-Agent": "InertiaApp/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        if data.get("code") == "Ok":
            route = data["routes"][0]
            # Coordinates returned as [lon, positive_lat]
            return route["geometry"]["coordinates"], route["distance"]
        else:
            raise RuntimeError(f"OSRM Routing failed: {data}")

def create_geojson(route_name, stops_corrected, polyline_coords, distance_m, color="#00E5FF"):
    """
    Builds a GeoJSON FeatureCollection with:
    - LineString for the path with negative latitudes
    - Named Point feature for each stop with negative latitude
    """
    # In GeoJSON: [longitude, latitude]
    # Convert polyline latitudes to negative as per user instruction
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

def main():
    print("Processing Route 1: Men's Hostel Route...")
    r1_corrected = verify_and_correct_sign(raw_route1_stops)
    coords1, dist1 = fetch_road_polyline(r1_corrected)
    geojson1 = create_geojson("Men's Hostel Route", r1_corrected, coords1, dist1, color="#00E5FF")

    out1_root = BASE_DIR / "menshostel_route.geojson"
    out1_data = BASE_DIR / "backend" / "data" / "menshostel_route.geojson"
    with open(out1_root, "w", encoding="utf-8") as f:
        json.dump(geojson1, f, indent=2)
    with open(out1_data, "w", encoding="utf-8") as f:
        json.dump(geojson1, f, indent=2)
    print(f"Saved {out1_root} ({len(coords1)} points, {dist1:.1f}m)")

    print("\nProcessing Route 2: Ladies Hostel Route...")
    r2_corrected = verify_and_correct_sign(raw_route2_stops)
    coords2, dist2 = fetch_road_polyline(r2_corrected)
    geojson2 = create_geojson("Ladies Hostel Route", r2_corrected, coords2, dist2, color="#3B82F6")

    out2_root = BASE_DIR / "ladieshostel_route.geojson"
    out2_data = BASE_DIR / "backend" / "data" / "ladieshostel_route.geojson"
    with open(out2_root, "w", encoding="utf-8") as f:
        json.dump(geojson2, f, indent=2)
    with open(out2_data, "w", encoding="utf-8") as f:
        json.dump(geojson2, f, indent=2)
    print(f"Saved {out2_root} ({len(coords2)} points, {dist2:.1f}m)")

    # Also update backend/data/routes.json for live app execution
    update_app_routes(r1_corrected, coords1, r2_corrected, coords2)

def update_app_routes(r1_stops, coords1, r2_stops, coords2):
    routes_file = BASE_DIR / "backend" / "data" / "routes.json"
    data = {
        "campus": {
            "name": "VIT Vellore",
            "center": [12.9715, 79.1585],
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
    print(f"Updated {routes_file} with new campus route polylines and stops.")

if __name__ == "__main__":
    main()
