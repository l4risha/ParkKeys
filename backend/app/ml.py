"""Simple scikit-learn hourly demand prediction + safe fallback.

One RandomForestRegressor per route (features: hour, day of week).
Kung mo-fail ang ML, mogamit og average from history; kung wala history, LOW.
Dili gyud ni mo-crash sa main API.
"""
import asyncio
import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sklearn.ensemble import RandomForestRegressor

from .config import settings
from .db import connect

logger = logging.getLogger("parkkeys.ml")

MANILA = ZoneInfo("Asia/Manila")
MODEL_VERSION = "rf-hourly-v1"
FALLBACK_VERSION = "fallback-hourly-v1"


def level_for(count: float) -> str:
    if count < 4:
        return "LOW"
    if count < 8:
        return "MEDIUM"
    return "HIGH"


def _now_hour() -> datetime:
    return datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)


def _fallback_row(conn, route_id: int, hour: int, dow: int) -> dict:
    """Rule-based fallback gamit ang history average."""
    row = conn.execute(
        """SELECT AVG(demand_count) AS avg_count
             FROM demand_history
            WHERE route_id = %s
              AND EXTRACT(hour FROM recorded_at AT TIME ZONE 'Asia/Manila')::int = %s
              AND EXTRACT(isodow FROM recorded_at AT TIME ZONE 'Asia/Manila')::int - 1 = %s
              AND recorded_at >= now() - interval '60 days'""",
        (route_id, hour, dow),
    ).fetchone()
    avg = float(row["avg_count"]) if row and row["avg_count"] is not None else 0.0
    return {
        "demand_level": level_for(avg) if row and row["avg_count"] is not None else "LOW",
        "predicted_count": avg,
        "model_version": FALLBACK_VERSION,
        "source": "fallback",
    }


def refresh_all_predictions() -> dict:
    """Train models and upsert this hour's prediction for every active route."""
    now_ph = datetime.now(MANILA)
    hour, dow = now_ph.hour, now_ph.isoweekday() - 1
    updated = 0
    errors = 0
    try:
        with connect() as conn, conn.transaction():
            history = conn.execute(
                """SELECT route_id,
                          EXTRACT(hour FROM recorded_at AT TIME ZONE 'Asia/Manila')::int AS hour,
                          EXTRACT(isodow FROM recorded_at AT TIME ZONE 'Asia/Manila')::int - 1 AS dow,
                          demand_count
                     FROM demand_history
                    WHERE recorded_at >= now() - interval '60 days'"""
            ).fetchall()
            routes = conn.execute("SELECT id FROM routes WHERE active = TRUE").fetchall()

            by_route: dict[int, list[dict]] = defaultdict(list)
            for item in history:
                by_route[item["route_id"]].append(item)

            for route in routes:
                route_id = route["id"]
                samples = by_route.get(route_id, [])
                try:
                    if len(samples) < 24:
                        pred_count = (
                            sum(s["demand_count"] for s in samples) / len(samples)
                            if samples else 0.0
                        )
                        version = FALLBACK_VERSION
                    else:
                        x = [[s["hour"], s["dow"]] for s in samples]
                        y = [s["demand_count"] for s in samples]
                        model = RandomForestRegressor(
                            n_estimators=40, max_depth=10, random_state=42, n_jobs=1
                        )
                        model.fit(x, y)
                        pred_count = float(model.predict([[hour, dow]])[0])
                        version = MODEL_VERSION
                except Exception:
                    logger.exception("ML failed for route %s, fallback gamit", route_id)
                    pred_count = (
                        sum(s["demand_count"] for s in samples) / len(samples)
                        if samples else 0.0
                    )
                    version = FALLBACK_VERSION
                    errors += 1

                conn.execute(
                    """INSERT INTO predictions
                           (route_id, predicted_for, demand_level, predicted_count, model_version)
                       VALUES (%s, date_trunc('hour', now()), %s, %s, %s)
                       ON CONFLICT (route_id, predicted_for) DO UPDATE
                           SET demand_level = EXCLUDED.demand_level,
                               predicted_count = EXCLUDED.predicted_count,
                               model_version = EXCLUDED.model_version,
                               created_at = now()""",
                    (route_id, level_for(pred_count), round(pred_count, 2), version),
                )
                updated += 1

            conn.execute(
                "DELETE FROM predictions WHERE predicted_for < now() - interval '7 days'"
            )
    except Exception:
        logger.exception("Prediction refresh totally failed - API still running")
        return {"updated": 0, "model_version": FALLBACK_VERSION, "errors": errors + 1}

    return {"updated": updated, "model_version": MODEL_VERSION, "errors": errors}


def demand_details(conn, route_ids: list[int]) -> dict[int, dict]:
    """Current-hour predictions; missing ones use fallback. Never raise."""
    if not route_ids:
        return {}
    now_ph = datetime.now(MANILA)
    hour, dow = now_ph.hour, now_ph.isoweekday() - 1
    try:
        rows = conn.execute(
            """SELECT route_id, demand_level, predicted_count, model_version
                 FROM predictions
                WHERE route_id = ANY(%s) AND predicted_for = date_trunc('hour', now())""",
            (route_ids,),
        ).fetchall()
    except Exception:
        logger.exception("Cannot read predictions")
        rows = []

    result = {
        row["route_id"]: {
            "demand_level": row["demand_level"],
            "predicted_count": (
                float(row["predicted_count"]) if row["predicted_count"] is not None else None
            ),
            "model_version": row["model_version"],
            "predicted_for": _now_hour(),
            "source": "fallback" if row["model_version"] == FALLBACK_VERSION else "ml",
        }
        for row in rows
    }

    missing = [rid for rid in route_ids if rid not in result]
    for route_id in missing:
        try:
            result[route_id] = {
                **_fallback_row(conn, route_id, hour, dow),
                "predicted_for": _now_hour(),
            }
        except Exception:
            logger.exception("Fallback failed for route %s", route_id)
            result[route_id] = {
                "demand_level": "LOW",
                "predicted_count": 0.0,
                "model_version": FALLBACK_VERSION,
                "predicted_for": _now_hour(),
                "source": "fallback",
            }
    return result


def demand_levels(conn, route_ids: list[int]) -> dict[int, dict]:
    """Light version para sa public list (level + source lang)."""
    return {
        rid: {"demand_level": info["demand_level"], "source": info["source"]}
        for rid, info in demand_details(conn, route_ids).items()
    }


async def ml_refresh_loop() -> None:
    while True:
        try:
            result = await asyncio.to_thread(refresh_all_predictions)
            logger.info("Predictions refreshed: %s", result)
        except Exception:
            logger.exception("Background ML refresh failed")
        await asyncio.sleep(max(1, settings.ml_refresh_minutes) * 60)
