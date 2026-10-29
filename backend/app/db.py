"""PostgreSQL connection. One connection per request, simple ra."""
import psycopg
from psycopg.rows import dict_row

from .config import settings


def connect() -> psycopg.Connection:
    # autocommit=True: reads don't hold a transaction open. Every write endpoint
    # still wraps its work in `with conn.transaction()` para atomic.
    return psycopg.connect(
        settings.database_url, row_factory=dict_row, autocommit=True
    )


def get_db():
    """FastAPI dependency. Siya ang mag-close sa connection."""
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()
