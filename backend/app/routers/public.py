"""Public no-login endpoints para sa display board / public page."""
from fastapi import APIRouter, Depends

from ..db import get_db
from ..ml import demand_details, demand_levels
from ..queue_utils import require_route
from ..schemas import PublicRouteStatusOut, PublicRouteSummaryOut

router = APIRouter(prefix="/api/public", tags=["public"])


@router.get("/routes", response_model=list[PublicRouteSummaryOut])
def public_routes(conn=Depends(get_db)):
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
        {
            **row,
            "demand_level": demand[row["route_id"]]["demand_level"],
            "demand_source": demand[row["route_id"]]["source"],
        }
        for row in rows
    ]


@router.get("/routes/{route_id}/status", response_model=PublicRouteStatusOut)
def public_route_status(route_id: int, conn=Depends(get_db)):
    route = require_route(conn, route_id, allow_inactive=True)
    counts = conn.execute(
        """SELECT
             (SELECT COUNT(*) FROM queue_entries
               WHERE route_id = %s AND queue_type = 'passenger'
                 AND status IN ('waiting', 'on_deck')) AS passengers_waiting,
             (SELECT COUNT(*) FROM queue_entries
               WHERE route_id = %s AND queue_type = 'driver'
                 AND status IN ('waiting', 'on_deck')) AS drivers_in_queue""",
        (route_id, route_id),
    ).fetchone()
    drivers = conn.execute(
        """SELECT qe.queue_number, u.full_name, d.tricycle_no,
                  ROW_NUMBER() OVER (ORDER BY qe.queue_number, qe.id) AS position
             FROM queue_entries qe
             JOIN users u ON u.id = qe.user_id
             LEFT JOIN drivers d ON d.user_id = qe.user_id
            WHERE qe.route_id = %s AND qe.queue_type = 'driver'
              AND qe.status IN ('waiting', 'on_deck')
            ORDER BY qe.queue_number, qe.id""",
        (route_id,),
    ).fetchall()
    demand = demand_details(conn, [route_id])[route_id]
    now = conn.execute("SELECT now() AS now").fetchone()["now"]
    return {
        "route_id": route["id"],
        "route_name": route["name"],
        "active": route["active"],
        "drivers_in_queue": counts["drivers_in_queue"],
        "passengers_waiting": counts["passengers_waiting"],
        "demand_level": demand["demand_level"],
        "demand_source": demand["source"],
        "drivers": drivers,
        "updated_at": now,
    }
