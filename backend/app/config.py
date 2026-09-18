import os
from pathlib import Path
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True

    # Clustering and tracking
    CLUSTER_RADIUS_METERS: float = 45.0
    HEADING_TOLERANCE_DEGREES: float = 40.0
    MIN_RIDERS_PER_SHUTTLE: int = 2
    AUTO_END_IDLE_SECONDS: float = 150.0
    LOCATION_EXPIRY_SECONDS: float = 30.0

    # Maps Configuration
    GOOGLE_MAPS_API_KEY: str = ""

    # Payment details
    UPI_VPA: str = "vitshuttle@okaxis"
    SHUTTLE_FARE_INR: float = 20.0
    MERCHANT_NAME: str = "VIT Campus Shuttle"

    # Geofence bounding box for VIT Vellore campus
    GEOFENCE_LAT_MIN: float = 12.9640
    GEOFENCE_LAT_MAX: float = 12.9785
    GEOFENCE_LNG_MIN: float = 79.1510
    GEOFENCE_LNG_MAX: float = 79.1675

    DATA_DIR: Path = Path(__file__).resolve().parent.parent / "data"

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()
