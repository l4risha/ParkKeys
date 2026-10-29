"""Queue API: passenger join/view/cancel; driver join/view/status/leave/serve."""
import psycopg
from fastapi import APIRouter, Depends, HTTPException, Request, status

from ..audit import write_audit
from ..db import get_db
from ..queue_utils import (
    duplicate_active_error,
    get_active_entry,
    get_entry,
    join_queue,
    queue_count,
    require_route,
)
from ..schemas import (
    DriverViewOut,
    JoinIn,
    PassengerViewOut,
    QueueEntryOut,
    ServeOut,
    StatusUpdateIn,
)
from ..security import require_roles

router = APIRouter(prefix="/api/queue", tags=["queue"])
passenger_only = require_roles("passenger")
driver_only = require_roles("driver")


def _active_entry_locked(conn, user_id: int, queue_type: str) -> dict | None:
    row = conn.execute(
        """SELECT id FROM queue_entries
            WHERE user_id = %s AND queue_type = %s
              AND status IN ('waiting', 'on_deck')
            FOR UPDATE""",
        (user_id, queue_type),
    ).fetchone()
    return get_entry(conn, row["id"]) if row else None


# ---------- passenger ----------
@router.post("/passenger/join", response_model=QueueEntryOut, status_code=status.HTTP_201_CREATED)
def passenger_join(
    payload: JoinIn,
    request: Request,
    user=Depends(passenger_only),
    conn=Depends(get_db),
):
    require_route(conn, payload.route_id)
    if get_active_entry(conn, user["id"]):
        raise duplicate_active_error()
    try:
        with conn.transaction():
            entry = join_queue(conn, user["id"], payload.route_id, "passenger")
            write_audit(
                conn,
                user["id"],
                "queue_join",
                {
                    "entry_id": entry["id"],
                    "route_id": entry["route_id"],
                    "route_name": entry["route_name"],
                    "queue_type": "passenger",
                    "queue_number": entry["queue_number"],
                },
                request,
            )
    except psycopg.errors.UniqueViolation:
        raise duplicate_active_error()
    return entry


@router.get("/passenger", response_model=PassengerViewOut)
def passenger_view(user=Depends(passenger_only), conn=Depends(get_db)):
    return {"entry": get_active_entry(conn, user["id"], "passenger")}


@router.delete("/passenger")
def passenger_cancel(
    request: Request,
    user=Depends(passenger_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        entry = _active_entry_locked(conn, user["id"], "passenger")
        if entry is None:
            raise HTTPException(status_code=409, detail="No active passenger queue entry")
        conn.execute(
            """UPDATE queue_entries
                  SET status = 'cancelled', updated_at = now()
                WHERE id = %s""",
            (entry["id"],),
        )
        write_audit(
            conn,
            user["id"],
            "queue_cancel",
            {
                "entry_id": entry["id"],
                "route_id": entry["route_id"],
                "route_name": entry["route_name"],
                "queue_type": "passenger",
                "queue_number": entry["queue_number"],
            },
            request,
        )
    return {"message": "Passenger queue entry cancelled", "entry_id": entry["id"]}


# ---------- driver ----------
def _driver_profile(conn, user_id: int) -> dict:
    profile = conn.execute(
        """SELECT d.id, d.tricycle_no, d.is_active, u.is_active AS user_active
             FROM drivers d JOIN users u ON u.id = d.user_id
            WHERE d.user_id = %s""",
        (user_id,),
    ).fetchone()
    if profile is None or not profile["is_active"] or not profile["user_active"]:
        raise HTTPException(status_code=403, detail="Driver profile is inactive or missing")
    return profile


@router.post("/driver/join", response_model=QueueEntryOut, status_code=status.HTTP_201_CREATED)
def driver_join(
    payload: JoinIn,
    request: Request,
    user=Depends(driver_only),
    conn=Depends(get_db),
):
    _driver_profile(conn, user["id"])
    require_route(conn, payload.route_id)
    if get_active_entry(conn, user["id"]):
        raise duplicate_active_error()
    try:
        with conn.transaction():
            entry = join_queue(conn, user["id"], payload.route_id, "driver")
            write_audit(
                conn,
                user["id"],
                "queue_join",
                {
                    "entry_id": entry["id"],
                    "route_id": entry["route_id"],
                    "route_name": entry["route_name"],
                    "queue_type": "driver",
                    "queue_number": entry["queue_number"],
                },
                request,
            )
    except psycopg.errors.UniqueViolation:
        raise duplicate_active_error()
    return entry


@router.get("/driver", response_model=DriverViewOut)
def driver_view(user=Depends(driver_only), conn=Depends(get_db)):
    entry = get_active_entry(conn, user["id"], "driver")
    waiting = queue_count(conn, entry["route_id"], "passenger") if entry else 0
    return {"entry": entry, "passengers_waiting": waiting}


@router.patch("/driver/status", response_model=QueueEntryOut)
def driver_update_status(
    payload: StatusUpdateIn,
    request: Request,
    user=Depends(driver_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        entry = _active_entry_locked(conn, user["id"], "driver")
        if entry is None:
            raise HTTPException(status_code=409, detail="No active driver queue entry")
        conn.execute(
            "UPDATE queue_entries SET status = %s, updated_at = now() WHERE id = %s",
            (payload.status, entry["id"]),
        )
        write_audit(
            conn,
            user["id"],
            "queue_status",
            {
                "entry_id": entry["id"],
                "route_id": entry["route_id"],
                "queue_number": entry["queue_number"],
                "new_status": payload.status,
            },
            request,
        )
        updated = get_entry(conn, entry["id"])
    return updated


@router.delete("/driver")
def driver_leave(
    request: Request,
    user=Depends(driver_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        entry = _active_entry_locked(conn, user["id"], "driver")
        if entry is None:
            raise HTTPException(status_code=409, detail="No active driver queue entry")
        conn.execute(
            "UPDATE queue_entries SET status = 'cancelled', updated_at = now() WHERE id = %s",
            (entry["id"],),
        )
        write_audit(
            conn,
            user["id"],
            "queue_cancel",
            {
                "entry_id": entry["id"],
                "route_id": entry["route_id"],
                "route_name": entry["route_name"],
                "queue_type": "driver",
                "queue_number": entry["queue_number"],
            },
            request,
        )
    return {"message": "Driver left the queue", "entry_id": entry["id"]}


@router.post("/driver/serve", response_model=ServeOut)
def driver_serve(
    request: Request,
    user=Depends(driver_only),
    conn=Depends(get_db),
):
    """Position 1 driver + position 1 passenger sa parehas nga route. One transaction."""
    _driver_profile(conn, user["id"])
    with conn.transaction():
        driver_entry = _active_entry_locked(conn, user["id"], "driver")
        if driver_entry is None:
            raise HTTPException(status_code=409, detail="No active driver queue entry")
        if driver_entry["position"] != 1:
            raise HTTPException(
                status_code=409,
                detail="Only the driver at position 1 can serve the next passenger",
            )

        passenger = conn.execute(
            """SELECT id FROM queue_entries
                WHERE route_id = %s AND queue_type = 'passenger'
                  AND status IN ('waiting', 'on_deck')
                ORDER BY queue_number, id
                LIMIT 1
                FOR UPDATE""",
            (driver_entry["route_id"],),
        ).fetchone()
        if passenger is None:
            raise HTTPException(status_code=409, detail="No passenger waiting on this route")

        conn.execute(
            """UPDATE queue_entries
                  SET status = 'completed', completed_at = now(), updated_at = now()
                WHERE id IN (%s, %s)""",
            (driver_entry["id"], passenger["id"]),
        )
        dispatch = conn.execute(
            """INSERT INTO dispatch_logs
                   (route_id, driver_user_id, passenger_user_id,
                    driver_entry_id, passenger_entry_id, served_by)
               VALUES (%s, %s, %s, %s, %s, %s)
               RETURNING served_at""",
            (
                driver_entry["route_id"],
                user["id"],
                conn.execute(
                    "SELECT user_id FROM queue_entries WHERE id = %s", (passenger["id"],)
                ).fetchone()["user_id"],
                driver_entry["id"],
                passenger["id"],
                user["id"],
            ),
        ).fetchone()
        passenger_entry = get_entry(conn, passenger["id"])
        write_audit(
            conn,
            user["id"],
            "queue_serve",
            {
                "route_id": driver_entry["route_id"],
                "route_name": driver_entry["route_name"],
                "driver_entry_id": driver_entry["id"],
                "passenger_entry_id": passenger["id"],
                "driver_queue_number": driver_entry["queue_number"],
                "passenger_queue_number": passenger_entry["queue_number"],
            },
            request,
        )

    return {
        "message": "Trip served. Both entries completed.",
        "route_id": driver_entry["route_id"],
        "route_name": driver_entry["route_name"],
        "driver_entry_id": driver_entry["id"],
        "passenger_entry_id": passenger["id"],
        "driver_queue_number": driver_entry["queue_number"],
        "passenger_queue_number": passenger_entry["queue_number"],
        "served_at": dispatch["served_at"],
    }
