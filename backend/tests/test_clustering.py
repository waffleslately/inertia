import time
from app.config import settings
from app.geo.snapping import (
    haversine_distance, compute_bearing, is_inside_geofence,
    snap_to_route, project_point_onto_segment
)
from app.models import LocationPing
from app.services.clustering import ClusteringEngine
from app.services.db import init_db, get_spend_summary, record_payment

def test_haversine():
    # Distance between VIT Main Gate (~12.9698, 79.1559) and TT (~12.9712, 79.1585) is ~320m
    d = haversine_distance(12.9698, 79.1559, 12.9712, 79.1585)
    assert 280.0 < d < 360.0, f"Unexpected distance: {d}"
    print(f"Haversine test passed: {d:.1f}m")

def test_geofence():
    # Inside campus
    assert is_inside_geofence(
        12.9715, 79.1585,
        settings.GEOFENCE_LAT_MIN, settings.GEOFENCE_LAT_MAX,
        settings.GEOFENCE_LNG_MIN, settings.GEOFENCE_LNG_MAX
    )
    # Outside campus (Chennai)
    assert not is_inside_geofence(
        13.0827, 80.2707,
        settings.GEOFENCE_LAT_MIN, settings.GEOFENCE_LAT_MAX,
        settings.GEOFENCE_LNG_MIN, settings.GEOFENCE_LNG_MAX
    )
    print("Geofence test passed")

def test_clustering_co_moving():
    engine = ClusteringEngine()
    now = time.time()

    # Two simulated riders right next to each other on Route 1 near TT moving east at 15 km/h (4.16 m/s)
    ping1 = LocationPing(
        rider_id="rider_test_1",
        latitude=12.97120,
        longitude=79.15850,
        speed_mps=4.16,
        heading=75.0,
        timestamp=now,
        is_on_shuttle=True,
        route_hint="route_1"
    )
    ping2 = LocationPing(
        rider_id="rider_test_2",
        latitude=12.97125,
        longitude=79.15855,
        speed_mps=4.16,
        heading=75.0,
        timestamp=now,
        is_on_shuttle=False,
        route_hint="route_1"
    )

    res1 = engine.ingest_ping(ping1)
    res2 = engine.ingest_ping(ping2)
    assert res1 is not None, "Ping 1 was not ingested"
    assert res2 is not None, "Ping 2 was not ingested"

    shuttles = engine.compute_shuttle_clusters()
    assert len(shuttles) >= 1, "Expected at least 1 clustered shuttle object"
    shuttle = shuttles[0]
    assert shuttle.rider_count >= 2, f"Expected 2 riders in cluster, got {shuttle.rider_count}"
    assert shuttle.route_id == "route_1"
    assert shuttle.speed_kmh > 0
    print(f"Clustering test passed: Clustered {shuttle.rider_count} riders into {shuttle.shuttle_id}, speed={shuttle.speed_kmh}km/h, next stop={shuttle.next_stop_name}")

def test_spend_summary():
    init_db()
    spend = get_spend_summary("demo_rider")
    assert spend.total_spend > 0, "Expected non-zero spend for demo rider"
    assert spend.ride_count > 0, "Expected non-zero ride count"
    print(f"Spend summary test passed: {spend.month_name} total=Rs.{spend.total_spend}, rides={spend.ride_count}, vs last month={spend.percentage_change}%")

if __name__ == "__main__":
    print("Running Inertia Backend Tests...")
    test_haversine()
    test_geofence()
    test_clustering_co_moving()
    test_spend_summary()
    print("ALL TESTS PASSED SUCCESSFULLY!")
