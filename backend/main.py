from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import Base, engine
import models  # noqa: F401  (registers models with Base before create_all)
import auth

# --- Sprint 1: create tables if they don't exist yet ---
# (Sprint 2 note: once the team is comfortable, swap this for versioned
#  Alembic migrations instead of create_all.)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="ParkKeys API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this before production deployment
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def hello_world():
    """Sprint 1 deliverable: running 'hello world' API endpoint."""
    return {"message": "ParkKeys API is running", "status": "ok"}


# --- Sprint 2: authentication routes ---
app.include_router(auth.router)
