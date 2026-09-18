from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

class LocationPing(BaseModel):
    rider_id: str
    latitude: float
    longitude: float
    speed_mps: float = 0.0  # meters per second
    heading: float = 0.0    # 0 - 360 degrees
    timestamp: float = Field(default_factory=lambda: datetime.utcnow().timestamp())
    is_on_shuttle: bool = False
    route_hint: Optional[str] = None

class Stop(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    sequence: int

class Route(BaseModel):
    id: str
    name: str
    short_name: str
    color: str
    fare: float = 20.0
    stops: List[Stop]
    polyline: List[List[float]]  # [[lat, lng], ...]

class Shuttle(BaseModel):
    shuttle_id: str
    route_id: str
    latitude: float
    longitude: float
    snapped_lat: float
    snapped_lng: float
    speed_kmh: float
    bearing: float
    rider_count: int
    crowd_category: str  # "Low" (<3), "Medium" (3-7), "Crowded" (>7)
    crowd_ratio: float   # 0.0 to 1.0 (for pulsing radius calculation)
    next_stop_id: Optional[str] = None
    next_stop_name: Optional[str] = None
    eta_seconds: Optional[int] = None
    last_updated: float

class CheckInRequest(BaseModel):
    rider_id: str
    route_id: Optional[str] = None
    latitude: float
    longitude: float

class CheckInResponse(BaseModel):
    session_id: str
    rider_id: str
    route_id: str
    status: str
    message: str

class EndRideRequest(BaseModel):
    session_id: str
    rider_id: str
    reason: Optional[str] = "rider_action"

class PaymentRequest(BaseModel):
    session_id: Optional[str] = None
    rider_id: str
    route_id: str
    amount: float = 20.0
    txn_ref: Optional[str] = None
    status: str = "COMPLETED"

class PaymentRecord(BaseModel):
    payment_id: str
    session_id: Optional[str]
    rider_id: str
    route_id: str
    amount: float
    timestamp: float
    status: str
    vpa: str

class RideHistoryItem(BaseModel):
    session_id: str
    rider_id: str
    route_id: str
    route_name: str
    start_time: float
    end_time: Optional[float]
    status: str
    fare: float
    paid: bool

class MonthlySpendSummary(BaseModel):
    month_name: str
    total_spend: float
    ride_count: int
    last_month_spend: float
    percentage_change: float
    daily_spend: List[Dict[str, Any]]
