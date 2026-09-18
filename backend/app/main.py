import asyncio
import json
import logging
from pathlib import Path
from typing import List, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from .config import settings
from .models import (
    LocationPing, CheckInRequest, CheckInResponse,
    EndRideRequest, PaymentRequest, Shuttle
)
from .services.db import init_db
from .services.clustering import clustering_engine
from .services.ride_manager import ride_manager

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("inertia.api")

app = FastAPI(
    title="Inertia VIT Shuttle Tracking API",
    description="Crowd-sourced campus shuttle tracking backend for VIT Vellore",
    version="1.0.0"
)

# CORS configuration for Flutter web/mobile & local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for debug dashboard
STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# WebSocket Connection Managers
class WebSocketManager:
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.discard(websocket)

    async def broadcast(self, data: dict):
        if not self.active_connections:
            return
        dead = []
        msg = json.dumps(data)
        for ws in self.active_connections:
            try:
                await ws.send_text(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.active_connections.discard(ws)

client_ws_manager = WebSocketManager()
debug_ws_manager = WebSocketManager()

@app.on_event("startup")
async def startup_event():
    init_db()
    # Background task for periodic cluster broadcasting & stale purge
    asyncio.create_task(broadcast_loop())

async def broadcast_loop():
    """Periodically broadcasts updated shuttle positions and debug feeds."""
    while True:
        try:
            clustering_engine.purge_expired_pings()
            shuttles = clustering_engine.compute_shuttle_clusters()

            # Broadcast to apps
            shuttle_dicts = [s.dict() if hasattr(s, 'dict') else s.model_dump() for s in shuttles]
            await client_ws_manager.broadcast({
                "type": "SHUTTLE_UPDATE",
                "shuttles": shuttle_dicts,
                "timestamp": asyncio.get_event_loop().time()
            })

            # Broadcast to debug dashboard
            if debug_ws_manager.active_connections:
                debug_pings = clustering_engine.get_raw_debug_pings()
                await debug_ws_manager.broadcast({
                    "type": "DEBUG_UPDATE",
                    "shuttles": shuttle_dicts,
                    "raw_pings": debug_pings,
                    "active_rider_count": len(clustering_engine.riders),
                    "active_shuttle_count": len(shuttles)
                })
        except Exception as e:
            logger.error(f"Error in broadcast loop: {e}")

        await asyncio.sleep(1.5)

@app.get("/")
async def root():
    dashboard_path = STATIC_DIR / "dashboard.html"
    if dashboard_path.exists():
        return FileResponse(str(dashboard_path))
    return {"name": "Inertia Backend", "status": "running", "campus": "VIT Vellore"}

@app.get("/dashboard")
async def get_dashboard():
    return FileResponse(str(STATIC_DIR / "dashboard.html"))

@app.get("/api/v1/config")
async def get_public_config():
    return {
        "campus_name": "VIT Vellore",
        "upi_vpa": settings.UPI_VPA,
        "shuttle_fare": settings.SHUTTLE_FARE_INR,
        "merchant_name": settings.MERCHANT_NAME,
        "google_maps_api_key": settings.GOOGLE_MAPS_API_KEY,
        "geofence": {
            "lat_min": settings.GEOFENCE_LAT_MIN,
            "lat_max": settings.GEOFENCE_LAT_MAX,
            "lng_min": settings.GEOFENCE_LNG_MIN,
            "lng_max": settings.GEOFENCE_LNG_MAX
        }
    }

@app.get("/api/v1/routes")
async def get_routes():
    routes_data = []
    for r in clustering_engine.routes.values():
        routes_data.append(r.dict() if hasattr(r, 'dict') else r.model_dump())
    return {"routes": routes_data}

@app.get("/api/v1/shuttles", response_model=List[Shuttle])
async def get_shuttles():
    return clustering_engine.get_shuttles()

@app.post("/api/v1/ping")
async def receive_ping(ping: LocationPing):
    result = clustering_engine.ingest_ping(ping)
    if result:
        return {"status": "ok", "result": result}
    return {"status": "ignored", "reason": "outside_campus_or_route"}

@app.post("/api/v1/check-in", response_model=CheckInResponse)
async def rider_check_in(req: CheckInRequest):
    return ride_manager.check_in(req)

@app.post("/api/v1/end-ride")
async def rider_end_ride(req: EndRideRequest):
    return ride_manager.end_ride(req)

@app.post("/api/v1/payments")
async def record_upi_payment(req: PaymentRequest):
    return ride_manager.process_payment(req)

@app.get("/api/v1/rides/history")
async def get_history(rider_id: str = Query("demo_rider")):
    return {"rides": ride_manager.get_history(rider_id)}

@app.get("/api/v1/spend/summary")
async def get_spend(rider_id: str = Query("demo_rider")):
    return ride_manager.get_spend(rider_id)

@app.websocket("/ws/shuttles")
async def websocket_shuttles(websocket: WebSocket):
    await client_ws_manager.connect(websocket)
    try:
        # Send immediate initial state
        shuttles = clustering_engine.get_shuttles()
        shuttle_dicts = [s.dict() if hasattr(s, 'dict') else s.model_dump() for s in shuttles]
        await websocket.send_text(json.dumps({
            "type": "INITIAL_STATE",
            "shuttles": shuttle_dicts
        }))
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        client_ws_manager.disconnect(websocket)
    except Exception:
        client_ws_manager.disconnect(websocket)

@app.websocket("/ws/debug")
async def websocket_debug(websocket: WebSocket):
    await debug_ws_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        debug_ws_manager.disconnect(websocket)
    except Exception:
        debug_ws_manager.disconnect(websocket)
