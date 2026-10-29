"""Admin API: drivers, routes, queue monitoring, skip/remove, dashboard, reports, ML."""
import psycopg
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from ..audit import write_audit
from ..db import get_db
from ..ml import demand_details, demand_levels, refresh_all_predictions
from ..queue_utils import ACTIVE, require_route
from ..schemas import (
    AdminRouteQueueOut,
    DashboardOut,
    DriverCreateIn,
    DriverOut,
    DriverUpdateIn,
    PredictionOut,
    PredictionRefreshOut,
    PublicRouteSummaryOut,
    QueueActionOut,
    ReasonIn,
    ReportOut,
    RouteCreateIn,
    RouteOut,
    RouteUpdateIn,
)
from ..security import hash_password, require_roles

router = APIRouter(prefix="/api/admin", tags=["admin"])
admin_only = require_roles("admin")


# ---------- drivers ----------
DRIVER_SELECT = """
    SELECT d.id, d.user_id, u.email, u.full_name, d.tricycle_no, d.phone,
           (d.is_active AND u.is_active) AS is_active, d.created_at
      FROM drivers d
      JOIN users u ON u.id = d.user_id
"""


def _fetch_driver(conn, driver_id: int) -> dict:
    row = conn.execute(DRIVER_SELECT + " WHERE d.id = %s", (driver_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Driver not found")
    return row


def _remove_active_queue_for_driver(conn, user_id: int, admin: dict, request: Request) -> None:
    """Deactivated driver dapat mawala sa queue, para dili ma-block ang linya."""
    rows = conn.execute(
        """SELECT id, route_id FROM queue_entries
            WHERE user_id = %s AND status IN ('waiting', 'on_deck')
            FOR UPDATE""",
        (user_id,),
    ).fetchall()
    for row in rows:
        conn.execute(
            """UPDATE queue_entries
                  SET status = 'removed', reason_code = 'driver_request', updated_at = now()
                WHERE id = %s""",
            (row["id"],),
        )
        write_audit(
            conn,
            admin["id"],
            "queue_removed",
            {
                "entry_id": row["id"],
                "route_id": row["route_id"],
                "reason_code": "driver_request",
                "note": "driver deactivated",
            },
            request,
        )


@router.get("/drivers", response_model=list[DriverOut])
def list_drivers(admin=Depends(admin_only), conn=Depends(get_db)):
    return conn.execute(DRIVER_SELECT + " ORDER BY d.id").fetchall()


@router.post("/drivers", response_model=DriverOut, status_code=status.HTTP_201_CREATED)
def create_driver(
    payload: DriverCreateIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    email = payload.email.lower().strip()
    try:
        with conn.transaction():
            user = conn.execute(
                """INSERT INTO users (email, password_hash, full_name, role)
                   VALUES (%s, %s, %s, 'driver') RETURNING id""",
                (email, hash_password(payload.password), payload.full_name.strip()),
            ).fetchone()
            driver = conn.execute(
                """INSERT INTO drivers (user_id, tricycle_no, phone)
                   VALUES (%s, %s, %s) RETURNING id""",
                (user["id"], payload.tricycle_no.strip(), payload.phone),
            ).fetchone()
            write_audit(
                conn,
                admin["id"],
                "driver_create",
                {"driver_id": driver["id"], "user_id": user["id"], "email": email},
                request,
            )
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Email or tricycle number already exists")
    return _fetch_driver(conn, driver["id"])


@router.patch("/drivers/{driver_id}", response_model=DriverOut)
def update_driver(
    driver_id: int,
    payload: DriverUpdateIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    try:
        with conn.transaction():
            driver = conn.execute(
                "SELECT id, user_id FROM drivers WHERE id = %s FOR UPDATE", (driver_id,)
            ).fetchone()
            if driver is None:
                raise HTTPException(status_code=404, detail="Driver not found")

            user_sets, user_params = [], []
            driver_sets, driver_params = [], []
            changed = []

            if payload.email is not None:
                user_sets.append("email = %s")
                user_params.append(payload.email.lower().strip())
                changed.append("email")
            if payload.full_name is not None:
                user_sets.append("full_name = %s")
                user_params.append(payload.full_name.strip())
                changed.append("full_name")
            if payload.password is not None:
                user_sets.append("password_hash = %s")
                user_params.append(hash_password(payload.password))
                changed.append("password")
            if payload.is_active is not None:
                user_sets.append("is_active = %s")
                user_params.append(payload.is_active)
                driver_sets.append("is_active = %s")
                driver_params.append(payload.is_active)
                changed.append("is_active")
            if payload.tricycle_no is not None:
                driver_sets.append("tricycle_no = %s")
                driver_params.append(payload.tricycle_no.strip())
                changed.append("tricycle_no")
            if payload.phone is not None:
                driver_sets.append("phone = %s")
                driver_params.append(payload.phone)
                changed.append("phone")

            if user_sets:
                conn.execute(
                    f"UPDATE users SET {', '.join(user_sets)} WHERE id = %s",
                    user_params + [driver["user_id"]],
                )
            if driver_sets:
                conn.execute(
                    f"UPDATE drivers SET {', '.join(driver_sets)} WHERE id = %s",
                    driver_params + [driver_id],
                )
            if payload.is_active is False:
                _remove_active_queue_for_driver(conn, driver["user_id"], admin, request)
            write_audit(
                conn,
                admin["id"],
                "driver_update",
                {"driver_id": driver_id, "changed": changed},
                request,
            )
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Email or tricycle number already exists")
    return _fetch_driver(conn, driver_id)


@router.delete("/drivers/{driver_id}")
def deactivate_driver(
    driver_id: int,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        driver = conn.execute(
            "SELECT id, user_id FROM drivers WHERE id = %s FOR UPDATE", (driver_id,)
        ).fetchone()
        if driver is None:
            raise HTTPException(status_code=404, detail="Driver not found")
        conn.execute("UPDATE drivers SET is_active = FALSE WHERE id = %s", (driver_id,))
        conn.execute("UPDATE users SET is_active = FALSE WHERE id = %s", (driver["user_id"],))
        _remove_active_queue_for_driver(conn, driver["user_id"], admin, request)
        write_audit(
            conn,
            admin["id"],
            "driver_deactivate",
            {"driver_id": driver_id, "user_id": driver["user_id"]},
            request,
        )
    return {"message": "Driver deactivated", "driver_id": driver_id}


# ---------- routes ----------
@router.get("/routes", response_model=list[RouteOut])
def admin_list_routes(admin=Depends(admin_only), conn=Depends(get_db)):
    return conn.execute("SELECT id, name, active FROM routes ORDER BY name").fetchall()


@router.post("/routes", response_model=RouteOut, status_code=status.HTTP_201_CREATED)
def create_route(
    payload: RouteCreateIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    try:
        with conn.transaction():
            route = conn.execute(
                "INSERT INTO routes (name) VALUES (%s) RETURNING id, name, active",
                (payload.name.strip(),),
            ).fetchone()
            write_audit(
                conn,
                admin["id"],
                "route_create",
                {"route_id": route["id"], "name": route["name"]},
                request,
            )
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Route name already exists")
    return route


@router.patch("/routes/{route_id}", response_model=RouteOut)
def update_route(
    route_id: int,
    payload: RouteUpdateIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    try:
        with conn.transaction():
            route = conn.execute(
                "SELECT id, name, active FROM routes WHERE id = %s FOR UPDATE", (route_id,)
            ).fetchone()
            if route is None:
                raise HTTPException(status_code=404, detail="Route not found")

            sets, params, changed = [], [], []
            if payload.name is not None:
                name = payload.name.strip()
                if len(name) < 2:
                    raise HTTPException(status_code=422, detail="Route name too short")
                sets.append("name = %s")
                params.append(name)
                changed.append("name")
            if payload.active is not None:
                sets.append("active = %s")
                params.append(payload.active)
                changed.append("active")

            if sets:
                conn.execute(
                    f"UPDATE routes SET {', '.join(sets)} WHERE id = %s", params + [route_id]
                )
            write_audit(
                conn,
                admin["id"],
                "route_update",
                {"route_id": route_id, "changed": changed},
                request,
            )
            route = conn.execute(
                "SELECT id, name, active FROM routes WHERE id = %s", (route_id,)
            ).fetchone()
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Route name already exists")
    return route


@router.delete("/routes/{route_id}")
def disable_route(
    route_id: int,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        route = conn.execute(
            "SELECT id, name FROM routes WHERE id = %s FOR UPDATE", (route_id,)
        ).fetchone()
        if route is None:
            raise HTTPException(status_code=404, detail="Route not found")
        conn.execute("UPDATE routes SET active = FALSE WHERE id = %s", (route_id,))
        write_audit(
            conn,
            admin["id"],
            "route_disable",
            {"route_id": route_id, "name": route["name"]},
            request,
        )
    return {"message": "Route disabled", "route_id": route_id}


# ---------- queue monitoring ----------
@router.get("/queues", response_model=list[PublicRouteSummaryOut])
def monitor_queues(admin=Depends(admin_only), conn=Depends(get_db)):
    rows = conn.execute(
        """SELECT r.id AS route_id, r.name AS route_name, r.active,
                  (SELECT COUNT(*) FROM queue_entries q
                    WHERE q.route_id = r.id AND q.queue_type = 'passenger'
                      AND q.status IN ('waiting', 'on_deck')) AS passengers_waiting,
                  (SELECT COUNT(*) FROM queue_entries q
                    WHERE q.route_id = r.id AND q.queue_type = 'driver'
                      AND q.status IN ('waiting', 'on_deck')) AS drivers_in_queue
             FROM routes r
            ORDER BY r.name"""
    ).fetchall()
    demand = demand_levels(conn, [row["route_id"] for row in rows])
    return [
        {**row, "demand_level": demand[row["route_id"]]["demand_level"],
         "demand_source": demand[row["route_id"]]["source"]}
        for row in rows
    ]


@router.get("/queues/{route_id}", response_model=AdminRouteQueueOut)
def monitor_route(
    route_id: int,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    route = require_route(conn, route_id, allow_inactive=True)
    rows = conn.execute(
        """SELECT qe.id, qe.route_id, r.name AS route_name, qe.user_id, qe.queue_type,
                  qe.queue_number, qe.status, qe.reason_code, qe.joined_at,
                  qe.completed_at, u.full_name, u.email, d.tricycle_no,
                  ROW_NUMBER() OVER (
                      PARTITION BY qe.queue_type ORDER BY qe.queue_number, qe.id
                  ) AS position
             FROM queue_entries qe
             JOIN routes r ON r.id = qe.route_id
             JOIN users u ON u.id = qe.user_id
             LEFT JOIN drivers d ON d.user_id = qe.user_id
            WHERE qe.route_id = %s AND qe.status IN ('waiting', 'on_deck')
            ORDER BY qe.queue_type, qe.queue_number""",
        (route_id,),
    ).fetchall()
    entries = []
    for row in rows:
        item = dict(row)
        item["people_ahead"] = item["position"] - 1
        entries.append(item)

    passengers = [e for e in entries if e["queue_type"] == "passenger"]
    drivers = [e for e in entries if e["queue_type"] == "driver"]
    demand = demand_details(conn, [route_id])[route_id]
    return {
        "route_id": route["id"],
        "route_name": route["name"],
        "active": route["active"],
        "passengers_waiting": len(passengers),
        "drivers_in_queue": len(drivers),
        "passengers": passengers,
        "drivers": drivers,
        "demand_level": demand["demand_level"],
    }


def _close_entry(
    conn,
    entry_id: int,
    new_status: str,
    reason_code: str,
    admin: dict,
    request: Request,
) -> QueueActionOut:
    # NOTE: caller wraps in transaction. Lock una para walay double action.
    row = conn.execute(
        "SELECT id, status FROM queue_entries WHERE id = %s FOR UPDATE", (entry_id,)
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Queue entry not found")
    if row["status"] not in ACTIVE:
        raise HTTPException(status_code=409, detail="Entry is not active anymore")

    conn.execute(
        """UPDATE queue_entries
              SET status = %s, reason_code = %s, updated_at = now()
            WHERE id = %s""",
        (new_status, reason_code, entry_id),
    )
    write_audit(
        conn,
        admin["id"],
        f"queue_{new_status}",
        {"entry_id": entry_id, "reason_code": reason_code, "previous_status": row["status"]},
        request,
    )
    return {
        "message": f"Queue entry {new_status}",
        "entry_id": entry_id,
        "status": new_status,
        "reason_code": reason_code,
    }


@router.post("/queue/{entry_id}/skip", response_model=QueueActionOut)
def skip_entry(
    entry_id: int,
    payload: ReasonIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        return _close_entry(conn, entry_id, "skipped", payload.reason_code, admin, request)


@router.post("/queue/{entry_id}/remove", response_model=QueueActionOut)
def remove_entry(
    entry_id: int,
    payload: ReasonIn,
    request: Request,
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    with conn.transaction():
        return _close_entry(conn, entry_id, "removed", payload.reason_code, admin, request)


# ---------- dashboard + reports ----------
@router.get("/dashboard", response_model=DashboardOut)
def dashboard(admin=Depends(admin_only), conn=Depends(get_db)):
    return conn.execute(
        """SELECT
             (SELECT COUNT(*) FROM routes WHERE active) AS routes_active,
             (SELECT COUNT(*) FROM drivers d JOIN users u ON u.id = d.user_id
               WHERE d.is_active AND u.is_active) AS drivers_active,
             (SELECT COUNT(*) FROM queue_entries
               WHERE queue_type = 'passenger' AND status IN ('waiting', 'on_deck'))
               AS passengers_waiting,
             (SELECT COUNT(*) FROM queue_entries
               WHERE queue_type = 'driver' AND status IN ('waiting', 'on_deck'))
               AS drivers_in_queue,
             (SELECT COUNT(*) FROM dispatch_logs WHERE served_at::date = CURRENT_DATE)
               AS completed_today,
             (SELECT COUNT(*) FROM queue_entries
               WHERE status = 'cancelled' AND updated_at::date = CURRENT_DATE)
               AS cancelled_today,
             now() AS as_of"""
    ).fetchone()


@router.get("/reports", response_model=ReportOut)
def reports(
    days: int = Query(default=7, ge=1, le=90),
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    routes = conn.execute("SELECT id, name FROM routes ORDER BY name").fetchall()
    served = {
        row["route_id"]: row["completed"]
        for row in conn.execute(
            """SELECT route_id, COUNT(*) AS completed FROM dispatch_logs
                WHERE served_at >= now() - make_interval(days => %s)
                GROUP BY route_id""",
            (days,),
        ).fetchall()
    }
    closed = {
        row["route_id"]: row
        for row in conn.execute(
            """SELECT route_id,
                      COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
                      COUNT(*) FILTER (WHERE status = 'skipped') AS skipped,
                      COUNT(*) FILTER (WHERE status = 'removed') AS removed
                 FROM queue_entries
                WHERE joined_at >= now() - make_interval(days => %s)
                GROUP BY route_id""",
            (days,),
        ).fetchall()
    }
    rows = []
    for route in routes:
        statuses = closed.get(route["id"], {})
        rows.append(
            {
                "route_id": route["id"],
                "route_name": route["name"],
                "completed_trips": served.get(route["id"], 0),
                "cancelled": statuses.get("cancelled", 0),
                "skipped": statuses.get("skipped", 0),
                "removed": statuses.get("removed", 0),
            }
        )
    return {"days": days, "rows": rows}


# ---------- ML predictions ----------
@router.get("/predictions", response_model=list[PredictionOut])
def predictions(
    route_id: int | None = Query(default=None),
    admin=Depends(admin_only),
    conn=Depends(get_db),
):
    if route_id is not None:
        require_route(conn, route_id, allow_inactive=True)
        routes = conn.execute("SELECT id, name FROM routes WHERE id = %s", (route_id,)).fetchall()
    else:
        routes = conn.execute("SELECT id, name FROM routes ORDER BY name").fetchall()

    details = demand_details(conn, [route["id"] for route in routes])
    return [
        {
            "route_id": route["id"],
            "route_name": route["name"],
            **details[route["id"]],
        }
        for route in routes
    ]


@router.post("/predictions/refresh", response_model=PredictionRefreshOut)
def refresh_predictions(admin=Depends(admin_only)):
    return refresh_all_predictions()
