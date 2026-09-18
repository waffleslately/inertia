import time
import json
import logging
from typing import Dict, List, Optional, Tuple, Any
from ..config import settings
from ..models import LocationPing, Shuttle, Route
from ..geo.snapping import (
    haversine_distance,
    compute_bearing,
    is_inside_geofence,
    snap_to_route,
    find_next_stop_and_eta,
)
from .db import end_ride_session

logger = logging.getLogger("inertia.clustering")

class RiderState:
    def __init__(self, ping: LocationPing, route_id: str, snapped_lat: float, snapped_lng: float, seg_idx: int, ratio: float):
        self.rider_id = ping.rider_id
        self.raw_lat = ping.latitude
        self.raw_lng = ping.longitude
        self.snapped_lat = snapped_lat
        self.snapped_lng = snapped_lng
        self.speed_mps = ping.speed_mps
        self.heading = ping.heading
        self.is_on_shuttle = ping.is_on_shuttle
        self.route_id = route_id
        self.seg_idx = seg_idx
        self.seg_ratio = ratio
        self.last_updated = ping.timestamp
        self.stationary_since: Optional[float] = ping.timestamp if ping.speed_mps < 1.0 else None
        self.active_session_id: Optional[str] = None

class ClusteringEngine:
    def __init__(self):
        self.routes: Dict[str, Route] = {}
        self.riders: Dict[str, RiderState] = {}
        self.shuttles: Dict[str, Shuttle] = {}
        self.load_routes()

    def load_routes(self):
        routes_file = settings.DATA_DIR / "routes.json"
        if routes_file.exists():
            with open(routes_file, "r") as f:
                data = json.load(f)
                for r in data.get("routes", []):
                    self.routes[r["id"]] = Route(**r)
                logger.info(f"Loaded {len(self.routes)} campus routes.")

    def ingest_ping(self, ping: LocationPing) -> Optional[Dict[str, Any]]:
        """
        Ingests rider GPS ping, checks campus geofence, snaps to route,
        updates rider state, and purges stale ephemeral pings.
        """
        # 1. Geofence check
        if not is_inside_geofence(
            ping.latitude, ping.longitude,
            settings.GEOFENCE_LAT_MIN, settings.GEOFENCE_LAT_MAX,
            settings.GEOFENCE_LNG_MIN, settings.GEOFENCE_LNG_MAX
        ):
            logger.debug(f"Ping from {ping.rider_id} dropped: Outside campus geofence.")
            return None

        # 2. Snap to best route
        best_route_id = ping.route_hint
        best_dist = float("inf")
        best_snap = (ping.latitude, ping.longitude, 0.0, 0, 0.0)

        routes_to_test = [self.routes[best_route_id]] if best_route_id in self.routes else list(self.routes.values())

        for r in routes_to_test:
            s_lat, s_lng, dist, seg_idx, ratio = snap_to_route(ping.latitude, ping.longitude, r.polyline)
            if dist < best_dist:
                best_dist = dist
                best_route_id = r.id
                best_snap = (s_lat, s_lng, dist, seg_idx, ratio)

        # Discard if too far off campus roads (>80 meters from any route)
        if best_dist > 80.0 and not ping.is_on_shuttle:
            return None

        snapped_lat, snapped_lng, _, seg_idx, ratio = best_snap

        # 3. Update rider state
        existing = self.riders.get(ping.rider_id)
        stationary_since = None
        if existing:
            if ping.speed_mps < 1.0:
                stationary_since = existing.stationary_since or ping.timestamp
            else:
                stationary_since = None
        elif ping.speed_mps < 1.0:
            stationary_since = ping.timestamp

        state = RiderState(
            ping=ping,
            route_id=best_route_id or "route_1",
            snapped_lat=snapped_lat,
            snapped_lng=snapped_lng,
            seg_idx=seg_idx,
            ratio=ratio
        )
        state.stationary_since = stationary_since
        if existing and existing.active_session_id:
            state.active_session_id = existing.active_session_id

        self.riders[ping.rider_id] = state

        # 4. Check auto-end for stationary rider
        self._check_rider_auto_end(state)

        # 5. Purge expired pings (Privacy preserving: max 30 seconds age)
        self.purge_expired_pings()

        # 6. Recompute clusters
        self.compute_shuttle_clusters()

        return {
            "rider_id": ping.rider_id,
            "route_id": state.route_id,
            "snapped_lat": state.snapped_lat,
            "snapped_lng": state.snapped_lng,
            "is_on_shuttle": state.is_on_shuttle
        }

    def _check_rider_auto_end(self, state: RiderState):
        """Auto-ends ride if stationary for > AUTO_END_IDLE_SECONDS near a stop."""
        if state.stationary_since and state.active_session_id:
            idle_duration = time.time() - state.stationary_since
            if idle_duration >= settings.AUTO_END_IDLE_SECONDS:
                logger.info(f"Auto-ending idle ride for rider {state.rider_id} (idle {idle_duration:.0f}s)")
                end_ride_session(state.active_session_id, status="AUTO_ENDED")
                state.active_session_id = None
                state.is_on_shuttle = False

    def purge_expired_pings(self):
        """Purges raw location records older than LOCATION_EXPIRY_SECONDS (privacy guarantee)."""
        now = time.time()
        expired_ids = [
            rid for rid, r in self.riders.items()
            if (now - r.last_updated) > settings.LOCATION_EXPIRY_SECONDS
        ]
        for rid in expired_ids:
            del self.riders[rid]

    def compute_shuttle_clusters(self) -> List[Shuttle]:
        """
        Groups co-moving riders into shuttle objects.
        Riders within CLUSTER_RADIUS_METERS moving along the same route form a cluster.
        """
        now = time.time()
        active_shuttles: List[Shuttle] = []

        # Group riders by route
        route_riders: Dict[str, List[RiderState]] = {}
        for r in self.riders.values():
            route_riders.setdefault(r.route_id, []).append(r)

        for route_id, riders in route_riders.items():
            route = self.routes.get(route_id)
            if not route:
                continue

            # Greedy spatial clustering along route
            clusters: List[List[RiderState]] = []
            visited = set()

            for i, r1 in enumerate(riders):
                if r1.rider_id in visited:
                    continue

                cluster = [r1]
                visited.add(r1.rider_id)

                for j, r2 in enumerate(riders):
                    if r2.rider_id in visited:
                        continue

                    # Distance between snapped positions
                    dist = haversine_distance(
                        r1.snapped_lat, r1.snapped_lng,
                        r2.snapped_lat, r2.snapped_lng
                    )

                    if dist <= settings.CLUSTER_RADIUS_METERS:
                        # If moving, verify heading alignment
                        if r1.speed_mps > 1.5 and r2.speed_mps > 1.5:
                            heading_diff = abs(r1.heading - r2.heading)
                            if heading_diff > 180.0:
                                heading_diff = 360.0 - heading_diff
                            if heading_diff <= settings.HEADING_TOLERANCE_DEGREES:
                                cluster.append(r2)
                                visited.add(r2.rider_id)
                        else:
                            cluster.append(r2)
                            visited.add(r2.rider_id)

                clusters.append(cluster)

            # Convert valid clusters to Shuttle objects
            for c_idx, cluster in enumerate(clusters):
                # Filter: either meets minimum rider count OR has at least 1 verified checked-in rider
                has_checkin = any(r.is_on_shuttle for r in cluster)
                if len(cluster) >= settings.MIN_RIDERS_PER_SHUTTLE or has_checkin:
                    # Centroid of cluster
                    avg_lat = sum(r.raw_lat for r in cluster) / len(cluster)
                    avg_lng = sum(r.raw_lng for r in cluster) / len(cluster)
                    avg_speed = (sum(r.speed_mps for r in cluster) / len(cluster)) * 3.6  # km/h

                    # Snap centroid to route
                    snapped_lat, snapped_lng, _, seg_idx, _ = snap_to_route(avg_lat, avg_lng, route.polyline)

                    # Compute forward bearing along polyline segment
                    if seg_idx < len(route.polyline) - 1:
                        p1 = route.polyline[seg_idx]
                        p2 = route.polyline[seg_idx + 1]
                        bearing = compute_bearing(p1[0], p1[1], p2[0], p2[1])
                    else:
                        bearing = 0.0

                    # Crowd categorization
                    rider_count = len(cluster)
                    if rider_count <= 2:
                        crowd_cat = "Low"
                        crowd_ratio = 0.35
                    elif rider_count <= 6:
                        crowd_cat = "Medium"
                        crowd_ratio = 0.70
                    else:
                        crowd_cat = "Crowded"
                        crowd_ratio = 1.0

                    # Next stop and ETA
                    stops_dict = [s.dict() if hasattr(s, 'dict') else s.model_dump() for s in route.stops]
                    next_stop_id, next_stop_name, eta_sec = find_next_stop_and_eta(
                        snapped_lat, snapped_lng, seg_idx, route.polyline, stops_dict,
                        speed_mps=max(avg_speed / 3.6, 3.5)
                    )

                    shuttle_id = f"shuttle_{route_id}_{c_idx + 1}"
                    shuttle = Shuttle(
                        shuttle_id=shuttle_id,
                        route_id=route_id,
                        latitude=avg_lat,
                        longitude=avg_lng,
                        snapped_lat=snapped_lat,
                        snapped_lng=snapped_lng,
                        speed_kmh=round(avg_speed, 1),
                        bearing=round(bearing, 1),
                        rider_count=rider_count,
                        crowd_category=crowd_cat,
                        crowd_ratio=crowd_ratio,
                        next_stop_id=next_stop_id,
                        next_stop_name=next_stop_name,
                        eta_seconds=eta_sec,
                        last_updated=now
                    )
                    active_shuttles.append(shuttle)

        # Update cached shuttles
        self.shuttles = {s.shuttle_id: s for s in active_shuttles}
        return active_shuttles

    def get_shuttles(self) -> List[Shuttle]:
        return list(self.shuttles.values())

    def get_raw_debug_pings(self) -> List[Dict[str, Any]]:
        """Returns anonymized pings for the debug dashboard."""
        return [
            {
                "rider_id": f"rider_{r.rider_id[:4]}",  # Anonymized prefix
                "lat": r.raw_lat,
                "lng": r.raw_lng,
                "snapped_lat": r.snapped_lat,
                "snapped_lng": r.snapped_lng,
                "speed": round(r.speed_mps * 3.6, 1),
                "is_on_shuttle": r.is_on_shuttle,
                "route_id": r.route_id
            }
            for r in self.riders.values()
        ]

clustering_engine = ClusteringEngine()
