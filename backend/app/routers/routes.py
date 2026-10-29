"""Authenticated route/barangay list."""
from fastapi import APIRouter, Depends, Query

from ..db import get_db
from ..schemas import RouteOut
from ..security import get_current_user

router = APIRouter(prefix="/api/routes", tags=["routes"])


@router.get("", response_model=list[RouteOut])
def list_routes(
    search: str | None = Query(default=None, max_length=100),
    user=Depends(get_current_user),
    conn=Depends(get_db),
):
    sql = "SELECT id, name, active FROM routes WHERE active = TRUE"
    params: list = []
    if search:
        sql += " AND name ILIKE %s"
        params.append(f"%{search.strip()}%")
    sql += " ORDER BY name"
    return conn.execute(sql, params).fetchall()
