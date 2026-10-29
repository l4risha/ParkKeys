"""Audit log helper - every queue action / admin edit muagi dinhi."""
from psycopg.types.json import Jsonb


def client_ip(request) -> str | None:
    if request is None:
        return None
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


def write_audit(conn, actor_id: int, action_type: str, details: dict, request=None) -> None:
    conn.execute(
        """INSERT INTO audit_logs (user_id, action_type, details, ip_address)
           VALUES (%s, %s, %s, %s)""",
        (actor_id, action_type, Jsonb(details), client_ip(request)),
    )
