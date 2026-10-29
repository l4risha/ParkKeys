"""ParkKeys FastAPI entrypoint. Run: uvicorn app.main:app --reload"""
import asyncio
import logging
from contextlib import asynccontextmanager, suppress

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .db import get_db
from .ml import ml_refresh_loop
from .routers import admin, auth, public, queue, routes

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = None
    if settings.ml_enabled:
        task = asyncio.create_task(ml_refresh_loop())  # refresh every 30 min
    yield
    if task:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


app = FastAPI(
    title="ParkKeys API",
    description="Barangay tricycle queue management API (Cabadbaran City).",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins or ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(routes.router)
app.include_router(queue.router)
app.include_router(admin.router)
app.include_router(public.router)


@app.get("/api/health", tags=["health"])
def health(conn=Depends(get_db)):
    conn.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
def root():
    return {"name": "ParkKeys API", "docs": "/docs", "health": "/api/health"}
