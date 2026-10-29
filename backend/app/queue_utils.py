"""Shared queue queries. Positions come from the DB, never hard-coded."""
import psycopg
from fastapi import HTTPException

ACTIVE = ("waiting", "on_deck")

ENTRY_SELECT = """
    SELECT qe.id, qe.route_id, r.name AS route_name, qe.user_id, qe.queue_type,
           qe.queue_number, qe.status, qe.reason_code, qe.joined_at,
           qe.updated_at, qe.completed_at,
           (SELECT COUNT(*)
              FROM queue_entries a
             WHERE a.route_id = qe.route_id
               AND a.queue_type = qe.queue_type
               AND a.status IN ('waiting', 'on_deck')
               AND a.queue_number < qe.queue_number) AS people_ahead
      FROM queue_entries qe
      JOIN routes r ON r.id = qe.route_id
"""


def shape(row: dict) -> dict:
    """Add position = people ahead + 1."""
    data = dict(row)
    data["position"] = data["people_ahead"] + 1
    return data


def get_active_entry(conn, user_id: int, queue_type: str | None = None) -> dict | None:
    sql = ENTRY_SELECT + " WHERE qe.user_id = %s AND qe.status IN ('waiting', 'on_deck')"
    params: list = [user_id]
    if queue_type:
        sql += " AND qe.queue_type = %s"
        params.append(queue_type)
    row = conn.execute(sql, params).fetchone()
    return shape(row) if row else None


def get_entry(conn, entry_id: int) -> dict | None:
    row = conn.execute(ENTRY_SELECT + " WHERE qe.id = %s", (entry_id,)).fetchone()
    return shape(row) if row else None


def require_route(conn, route_id: int, allow_inactive: bool = False) -> dict:
    route = conn.execute(
        "SELECT id, name, active FROM routes WHERE id = %s", (route_id,)
    ).fetchone()
    if route is None:
        raise HTTPException(status_code=404, detail="Route not found")
    if not route["active"] and not allow_inactive:
        raise HTTPException(status_code=400, detail="Route is inactive")
    return route


def lock_queue(conn, route_id: int, queue_type: str) -> None:
    """Advisory lock para sigurado ang sunod nga queue number (no race)."""
    key = route_id * 10 + (1 if queue_type == "passenger" else 2)
    conn.execute("SELECT pg_advisory_xact_lock(%s)", (key,))


def next_queue_number(conn, route_id: int, queue_type: str) -> int:
    row = conn.execute(
        """SELECT COALESCE(MAX(queue_number), 0) + 1 AS next_no
             FROM queue_entries WHERE route_id = %s AND queue_type = %s""",
        (route_id, queue_type),
    ).fetchone()
    return row["next_no"]


def queue_count(conn, route_id: int, queue_type: str) -> int:
    row = conn.execute(
        """SELECT COUNT(*) AS total FROM queue_entries
            WHERE route_id = %s AND queue_type = %s
              AND status IN ('waiting', 'on_deck')""",
        (route_id, queue_type),
    ).fetchone()
    return row["total"]


def join_queue(conn, user_id: int, route_id: int, queue_type: str) -> dict:
    """Insert waiting entry. Caller controls transaction."""
    lock_queue(conn, route_id, queue_type)
    number = next_queue_number(conn, route_id, queue_type)
    row = conn.execute(
        """INSERT INTO queue_entries (route_id, user_id, queue_type, queue_number, status)
           VALUES (%s, %s, %s, %s, 'waiting')
           RETURNING id""",
        (route_id, user_id, queue_type, number),
    ).fetchone()
    return get_entry(conn, row["id"])


def duplicate_active_error() -> HTTPException:
    return HTTPException(
        status_code=409,
        detail="You already have an active queue entry. Cancel or finish it first.",
    )


def is_unique_violation(exc: psycopg.Error) -> bool:
    return isinstance(exc, psycopg.errors.UniqueViolation)
