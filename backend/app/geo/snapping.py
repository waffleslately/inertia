import math
from typing import List, Tuple, Optional, Dict, Any

EARTH_RADIUS_METERS = 6371000.0

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two points in meters."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_METERS * c

def compute_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates forward azimuth / bearing from point 1 to point 2 in degrees (0-360)."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_lambda = math.radians(lon2 - lon1)

    y = math.sin(delta_lambda) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(delta_lambda)
    initial_bearing = math.atan2(y, x)
    compass_bearing = (math.degrees(initial_bearing) + 360.0) % 360.0
    return compass_bearing

def is_inside_geofence(lat: float, lon: float, lat_min: float, lat_max: float, lon_min: float, lon_max: float) -> bool:
    """Checks if coordinates fall inside the VIT Vellore campus bounding box."""
    return (lat_min <= lat <= lat_max) and (lon_min <= lon <= lon_max)

def project_point_onto_segment(
    plat: float, plon: float,
    alat: float, alon: float,
    blat: float, blon: float
) -> Tuple[float, float, float, float]:
    """
    Projects point P onto line segment AB.
    Returns: (snapped_lat, snapped_lon, distance_meters, segment_ratio_t)
    """
    # Flat-earth approximation for local campus scale (~1km)
    mid_lat = math.radians((alat + blat) / 2.0)
    kx = math.cos(mid_lat) * 111320.0
    ky = 110540.0

    ax, ay = alon * kx, alat * ky
    bx, by = blon * kx, blat * ky
    px, py = plon * kx, plat * ky

    dx = bx - ax
    dy = by - ay
    seg_len_sq = dx * dx + dy * dy

    if seg_len_sq == 0.0:
        dist = math.hypot(px - ax, py - ay)
        return alat, alon, dist, 0.0

    t = ((px - ax) * dx + (py - ay) * dy) / seg_len_sq
    t_clamped = max(0.0, min(1.0, t))

    proj_x = ax + t_clamped * dx
    proj_y = ay + t_clamped * dy

    dist = math.hypot(px - proj_x, py - proj_y)
    snapped_lat = proj_y / ky
    snapped_lon = proj_x / kx

    return snapped_lat, snapped_lon, dist, t_clamped

def snap_to_route(
    lat: float, lon: float, polyline: List[List[float]]
) -> Tuple[float, float, float, int, float]:
    """
    Snaps GPS coordinate to the nearest segment on the route polyline.
    Returns: (snapped_lat, snapped_lon, min_distance_meters, segment_index, segment_ratio)
    """
    if not polyline or len(polyline) < 2:
        return lat, lon, 0.0, 0, 0.0

    best_dist = float("inf")
    best_lat, best_lon = lat, lon
    best_seg_idx = 0
    best_ratio = 0.0

    for i in range(len(polyline) - 1):
        a_lat, a_lon = polyline[i]
        b_lat, b_lon = polyline[i + 1]

        s_lat, s_lon, dist, ratio = project_point_onto_segment(
            lat, lon, a_lat, a_lon, b_lat, b_lon
        )
        if dist < best_dist:
            best_dist = dist
            best_lat, best_lon = s_lat, s_lon
            best_seg_idx = i
            best_ratio = ratio

    return best_lat, best_lon, best_dist, best_seg_idx, best_ratio

def find_next_stop_and_eta(
    snapped_lat: float,
    snapped_lon: float,
    segment_idx: int,
    polyline: List[List[float]],
    stops: List[Dict[str, Any]],
    speed_mps: float = 4.5  # default ~16 km/h campus speed
) -> Tuple[Optional[str], Optional[str], Optional[int]]:
    """
    Finds the upcoming stop ahead along the polyline path and calculates ETA in seconds.
    """
    if not stops or not polyline:
        return None, None, None

    # Find the stop that is immediately ahead along the polyline
    # Precompute nearest segment index for each stop
    best_stop = None
    min_forward_dist = float("inf")

    # Minimum speed threshold for ETA calculation
    effective_speed = max(speed_mps, 2.5)  # min 9 km/h for sensible ETA

    for stop in stops:
        s_lat = stop["latitude"]
        s_lon = stop["longitude"]
        _, _, _, stop_seg_idx, _ = snap_to_route(s_lat, s_lon, polyline)

        # Distance along route from current position to stop
        if stop_seg_idx >= segment_idx:
            dist = haversine_distance(snapped_lat, snapped_lon, s_lat, s_lon)
            if dist < min_forward_dist and dist > 15.0:  # More than 15m ahead
                min_forward_dist = dist
                best_stop = stop

    if not best_stop and stops:
        # Loop back to first stop
        best_stop = stops[0]
        min_forward_dist = haversine_distance(
            snapped_lat, snapped_lon, best_stop["latitude"], best_stop["longitude"]
        )

    if best_stop:
        eta_sec = int(min_forward_dist / effective_speed)
        return best_stop["id"], best_stop["name"], max(eta_sec, 20)

    return None, None, None
