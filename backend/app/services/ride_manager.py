import uuid
import time
from typing import Optional, Dict, Any, List
from ..models import (
    CheckInRequest, CheckInResponse, EndRideRequest,
    PaymentRequest, PaymentRecord, RideHistoryItem, MonthlySpendSummary
)
from .db import (
    create_ride_session, end_ride_session, record_payment,
    get_ride_history, get_spend_summary
)
from .clustering import clustering_engine

class RideManager:
    def check_in(self, req: CheckInRequest) -> CheckInResponse:
        session_id = f"ride_{uuid.uuid4().hex[:8]}"

        # If route not explicitly given, snap to nearest
        route_id = req.route_id
        if not route_id:
            best_dist = float("inf")
            for r in clustering_engine.routes.values():
                from ..geo.snapping import snap_to_route
                _, _, dist, _, _ = snap_to_route(req.latitude, req.longitude, r.polyline)
                if dist < best_dist:
                    best_dist = dist
                    route_id = r.id

        route_id = route_id or "route_1"

        # Record in DB
        create_ride_session(session_id, req.rider_id, route_id)

        # Update rider state in clustering engine
        rider = clustering_engine.riders.get(req.rider_id)
        if rider:
            rider.is_on_shuttle = True
            rider.active_session_id = session_id
            rider.route_id = route_id

        # Trigger cluster recalculation
        clustering_engine.compute_shuttle_clusters()

        return CheckInResponse(
            session_id=session_id,
            rider_id=req.rider_id,
            route_id=route_id,
            status="CHECKED_IN",
            message="Check-in successful. Tracking co-movement on campus shuttle."
        )

    def end_ride(self, req: EndRideRequest) -> Dict[str, Any]:
        end_ride_session(req.session_id, status="COMPLETED")

        rider = clustering_engine.riders.get(req.rider_id)
        if rider:
            rider.is_on_shuttle = False
            rider.active_session_id = None

        clustering_engine.compute_shuttle_clusters()

        return {
            "session_id": req.session_id,
            "status": "COMPLETED",
            "message": "Ride completed."
        }

    def process_payment(self, req: PaymentRequest) -> Dict[str, Any]:
        payment_id = f"pay_{uuid.uuid4().hex[:8]}"
        record_payment(
            payment_id=payment_id,
            session_id=req.session_id,
            rider_id=req.rider_id,
            route_id=req.route_id,
            amount=req.amount,
            status=req.status,
            txn_ref=req.txn_ref
        )
        return {
            "payment_id": payment_id,
            "session_id": req.session_id,
            "status": "SUCCESS",
            "amount": req.amount,
            "message": "Payment logged successfully."
        }

    def get_history(self, rider_id: str) -> List[RideHistoryItem]:
        return get_ride_history(rider_id)

    def get_spend(self, rider_id: str) -> MonthlySpendSummary:
        return get_spend_summary(rider_id)

ride_manager = RideManager()
