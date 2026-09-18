import sqlite3
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional, Dict, Any
from ..config import settings
from ..models import RideHistoryItem, MonthlySpendSummary

DB_PATH = settings.DATA_DIR / "inertia.db"

def get_db():
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS ride_sessions (
        session_id TEXT PRIMARY KEY,
        rider_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        start_time REAL NOT NULL,
        end_time REAL,
        status TEXT NOT NULL,
        fare REAL DEFAULT 20.0,
        paid INTEGER DEFAULT 0
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS payments (
        payment_id TEXT PRIMARY KEY,
        session_id TEXT,
        rider_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp REAL NOT NULL,
        status TEXT NOT NULL,
        vpa TEXT NOT NULL,
        txn_ref TEXT
    )
    """)
    conn.commit()

    # Pre-seed realistic past rides if empty
    cursor.execute("SELECT COUNT(*) as count FROM ride_sessions")
    row = cursor.fetchone()
    if row and row["count"] == 0:
        seed_sample_data(conn)

    conn.close()

def seed_sample_data(conn):
    cursor = conn.cursor()
    now = time.time()
    # Create sample historical rides across current and previous month
    sample_rides = [
        ("sess_seed_1", "demo_rider", "route_1", now - 3600 * 5, now - 3600 * 4.8, "COMPLETED", 20.0, 1),
        ("sess_seed_2", "demo_rider", "route_2", now - 86400 * 1, now - 86400 * 1 + 600, "COMPLETED", 20.0, 1),
        ("sess_seed_3", "demo_rider", "route_1", now - 86400 * 2, now - 86400 * 2 + 720, "COMPLETED", 20.0, 1),
        ("sess_seed_4", "demo_rider", "route_1", now - 86400 * 3, now - 86400 * 3 + 650, "COMPLETED", 20.0, 1),
        ("sess_seed_5", "demo_rider", "route_2", now - 86400 * 4, now - 86400 * 4 + 800, "COMPLETED", 20.0, 1),
        ("sess_seed_6", "demo_rider", "route_1", now - 86400 * 5, now - 86400 * 5 + 550, "COMPLETED", 20.0, 1),
        ("sess_seed_7", "demo_rider", "route_2", now - 86400 * 7, now - 86400 * 7 + 700, "COMPLETED", 20.0, 1),
        ("sess_seed_8", "demo_rider", "route_1", now - 86400 * 9, now - 86400 * 9 + 600, "COMPLETED", 20.0, 1),
        ("sess_seed_9", "demo_rider", "route_1", now - 86400 * 12, now - 86400 * 12 + 750, "COMPLETED", 20.0, 1),
        ("sess_seed_10", "demo_rider", "route_2", now - 86400 * 15, now - 86400 * 15 + 620, "COMPLETED", 20.0, 1),
    ]

    for s in sample_rides:
        cursor.execute("""
        INSERT INTO ride_sessions (session_id, rider_id, route_id, start_time, end_time, status, fare, paid)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, s)

        cursor.execute("""
        INSERT INTO payments (payment_id, session_id, rider_id, route_id, amount, timestamp, status, vpa, txn_ref)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (f"pay_{s[0]}", s[0], s[1], s[2], s[6], s[4], "COMPLETED", settings.UPI_VPA, f"UPI-{int(s[4])}"))

    # Also insert rides from last month to generate "-15% vs last month" comparison
    last_month_base = now - 86400 * 35
    for i in range(14):
        t = last_month_base + i * 86400 * 2
        cursor.execute("""
        INSERT INTO ride_sessions (session_id, rider_id, route_id, start_time, end_time, status, fare, paid)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (f"sess_lm_{i}", "demo_rider", "route_1" if i % 2 == 0 else "route_2", t, t + 600, "COMPLETED", 20.0, 1))
        cursor.execute("""
        INSERT INTO payments (payment_id, session_id, rider_id, route_id, amount, timestamp, status, vpa, txn_ref)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (f"pay_lm_{i}", f"sess_lm_{i}", "demo_rider", "route_1" if i % 2 == 0 else "route_2", 20.0, t + 600, "COMPLETED", settings.UPI_VPA, f"UPI-{int(t)}"))

    conn.commit()

def create_ride_session(session_id: str, rider_id: str, route_id: str) -> None:
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
    INSERT INTO ride_sessions (session_id, rider_id, route_id, start_time, status, fare, paid)
    VALUES (?, ?, ?, ?, 'IN_PROGRESS', 20.0, 0)
    """, (session_id, rider_id, route_id, time.time()))
    conn.commit()
    conn.close()

def end_ride_session(session_id: str, status: str = "COMPLETED") -> None:
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
    UPDATE ride_sessions
    SET end_time = ?, status = ?
    WHERE session_id = ?
    """, (time.time(), status, session_id))
    conn.commit()
    conn.close()

def record_payment(
    payment_id: str,
    session_id: Optional[str],
    rider_id: str,
    route_id: str,
    amount: float,
    status: str = "COMPLETED",
    txn_ref: Optional[str] = None
) -> None:
    conn = get_db()
    cursor = conn.cursor()
    ts = time.time()
    cursor.execute("""
    INSERT INTO payments (payment_id, session_id, rider_id, route_id, amount, timestamp, status, vpa, txn_ref)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (payment_id, session_id, rider_id, route_id, amount, ts, status, settings.UPI_VPA, txn_ref or f"UPI-{int(ts)}"))

    if session_id:
        cursor.execute("""
        UPDATE ride_sessions
        SET paid = 1
        WHERE session_id = ?
        """, (session_id,))

    conn.commit()
    conn.close()

def get_ride_history(rider_id: str, limit: int = 20) -> List[RideHistoryItem]:
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
    SELECT session_id, rider_id, route_id, start_time, end_time, status, fare, paid
    FROM ride_sessions
    WHERE rider_id = ? OR rider_id = 'demo_rider'
    ORDER BY start_time DESC
    LIMIT ?
    """, (rider_id, limit))
    rows = cursor.fetchall()
    conn.close()

    items = []
    for r in rows:
        route_name = "Route 1: Main Loop" if r["route_id"] == "route_1" else "Route 2: Academic Express"
        items.append(RideHistoryItem(
            session_id=r["session_id"],
            rider_id=r["rider_id"],
            route_id=r["route_id"],
            route_name=route_name,
            start_time=r["start_time"],
            end_time=r["end_time"],
            status=r["status"],
            fare=r["fare"],
            paid=bool(r["paid"])
        ))
    return items

def get_spend_summary(rider_id: str) -> MonthlySpendSummary:
    conn = get_db()
    cursor = conn.cursor()

    # Current month spend
    now_dt = datetime.utcnow()
    start_of_month = datetime(now_dt.year, now_dt.month, 1).timestamp()

    # Start of last month
    first_curr_month = datetime(now_dt.year, now_dt.month, 1)
    last_month_end = first_curr_month - timedelta(days=1)
    start_of_last_month = datetime(last_month_end.year, last_month_end.month, 1).timestamp()

    cursor.execute("""
    SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count
    FROM payments
    WHERE (rider_id = ? OR rider_id = 'demo_rider')
      AND timestamp >= ?
    """, (rider_id, start_of_month))
    curr_row = cursor.fetchone()
    current_total = float(curr_row["total"])
    ride_count = int(curr_row["count"])

    cursor.execute("""
    SELECT COALESCE(SUM(amount), 0) as total
    FROM payments
    WHERE (rider_id = ? OR rider_id = 'demo_rider')
      AND timestamp >= ? AND timestamp < ?
    """, (rider_id, start_of_last_month, start_of_month))
    last_row = cursor.fetchone()
    last_month_total = float(last_row["total"])

    if last_month_total > 0:
        pct_change = round(((current_total - last_month_total) / last_month_total) * 100.0, 1)
    else:
        pct_change = 0.0

    # Daily breakdown for current month
    cursor.execute("""
    SELECT strftime('%Y-%m-%d', datetime(timestamp, 'unixepoch')) as day, SUM(amount) as day_total, COUNT(*) as day_rides
    FROM payments
    WHERE (rider_id = ? OR rider_id = 'demo_rider')
      AND timestamp >= ?
    GROUP BY day
    ORDER BY day ASC
    """, (rider_id, start_of_month))
    daily_rows = cursor.fetchall()
    conn.close()

    daily_spend = [
        {"date": d["day"], "amount": float(d["day_total"]), "rides": int(d["day_rides"])}
        for d in daily_rows
    ]

    return MonthlySpendSummary(
        month_name=now_dt.strftime("%B %Y"),
        total_spend=current_total,
        ride_count=ride_count,
        last_month_spend=last_month_total,
        percentage_change=pct_change,
        daily_spend=daily_spend
    )
