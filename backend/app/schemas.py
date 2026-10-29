"""Pydantic request/response models. Kini ang shape sa OpenAPI /docs."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

Role = Literal["passenger", "driver", "admin"]
QueueType = Literal["passenger", "driver"]
QueueStatus = Literal["waiting", "on_deck", "completed", "cancelled", "skipped", "removed"]
ReasonCode = Literal["no_show", "vehicle_issue", "driver_request", "other"]


def _check_password(value: str) -> str:
    if len(value) < 8:
        raise ValueError("Password must be at least 8 characters")
    if len(value.encode("utf-8")) > 72:
        raise ValueError("Password must be at most 72 bytes (bcrypt limit)")
    return value


# ---------- auth ----------
class RegisterIn(BaseModel):
    email: EmailStr
    password: str
    full_name: str = Field(min_length=2, max_length=120)

    _pw = field_validator("password")(_check_password)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: int
    email: str
    full_name: str
    role: Role
    is_active: bool


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- routes ----------
class RouteOut(BaseModel):
    id: int
    name: str
    active: bool


class RouteCreateIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("Route name too short")
        return value


class RouteUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    active: bool | None = None


# ---------- queue ----------
class JoinIn(BaseModel):
    route_id: int


class StatusUpdateIn(BaseModel):
    status: Literal["waiting", "on_deck"]


class ReasonIn(BaseModel):
    # Required gyud para skip/remove -> missing = 422
    reason_code: ReasonCode


class QueueEntryOut(BaseModel):
    id: int
    route_id: int
    route_name: str
    queue_type: QueueType
    queue_number: int
    status: QueueStatus
    position: int
    people_ahead: int
    joined_at: datetime
    completed_at: datetime | None = None


class PassengerViewOut(BaseModel):
    entry: QueueEntryOut | None


class DriverViewOut(BaseModel):
    entry: QueueEntryOut | None
    passengers_waiting: int


class ServeOut(BaseModel):
    message: str
    route_id: int
    route_name: str
    driver_entry_id: int
    passenger_entry_id: int
    driver_queue_number: int
    passenger_queue_number: int
    served_at: datetime


# ---------- admin ----------
class DriverCreateIn(BaseModel):
    email: EmailStr
    password: str
    full_name: str = Field(min_length=2, max_length=120)
    tricycle_no: str = Field(min_length=2, max_length=30)
    phone: str | None = Field(default=None, max_length=30)

    _pw = field_validator("password")(_check_password)


class DriverUpdateIn(BaseModel):
    email: EmailStr | None = None
    password: str | None = None
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    tricycle_no: str | None = Field(default=None, min_length=2, max_length=30)
    phone: str | None = Field(default=None, max_length=30)
    is_active: bool | None = None

    @field_validator("password")
    @classmethod
    def check_password(cls, value: str | None) -> str | None:
        return _check_password(value) if value is not None else value


class DriverOut(BaseModel):
    id: int
    user_id: int
    email: str
    full_name: str
    tricycle_no: str
    phone: str | None
    is_active: bool
    created_at: datetime


class AdminQueueEntryOut(QueueEntryOut):
    user_id: int
    full_name: str
    email: str
    tricycle_no: str | None = None
    reason_code: ReasonCode | None = None


class QueueActionOut(BaseModel):
    message: str
    entry_id: int
    status: QueueStatus
    reason_code: ReasonCode | None = None


class AdminRouteQueueOut(BaseModel):
    route_id: int
    route_name: str
    active: bool
    passengers_waiting: int
    drivers_in_queue: int
    passengers: list[AdminQueueEntryOut]
    drivers: list[AdminQueueEntryOut]
    demand_level: Literal["LOW", "MEDIUM", "HIGH"]


class DashboardOut(BaseModel):
    routes_active: int
    drivers_active: int
    passengers_waiting: int
    drivers_in_queue: int
    completed_today: int
    cancelled_today: int
    as_of: datetime


class ReportRow(BaseModel):
    route_id: int
    route_name: str
    completed_trips: int
    cancelled: int
    skipped: int
    removed: int


class ReportOut(BaseModel):
    days: int
    rows: list[ReportRow]


class PredictionOut(BaseModel):
    route_id: int
    route_name: str
    predicted_for: datetime
    demand_level: Literal["LOW", "MEDIUM", "HIGH"]
    predicted_count: float | None
    model_version: str
    source: Literal["ml", "fallback"]


class PredictionRefreshOut(BaseModel):
    updated: int
    model_version: str
    errors: int


# ---------- public ----------
class PublicDriverOut(BaseModel):
    queue_number: int
    position: int
    full_name: str
    tricycle_no: str | None


class PublicRouteSummaryOut(BaseModel):
    route_id: int
    route_name: str
    active: bool
    drivers_in_queue: int
    passengers_waiting: int
    demand_level: Literal["LOW", "MEDIUM", "HIGH"]
    demand_source: Literal["ml", "fallback"]


class PublicRouteStatusOut(PublicRouteSummaryOut):
    drivers: list[PublicDriverOut]
    updated_at: datetime
