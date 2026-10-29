-- ParkKeys schema (PostgreSQL)
-- Run: psql -U postgres -d parkkeys_db -f database/schema.sql
-- Keep it simple: plain SQL, no triggers, no ORM.

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name     TEXT NOT NULL,
    role          TEXT NOT NULL CHECK (role IN ('passenger', 'driver', 'admin')),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS routes (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS drivers (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    tricycle_no  TEXT NOT NULL UNIQUE,
    phone        TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS queue_entries (
    id           BIGSERIAL PRIMARY KEY,
    route_id     BIGINT NOT NULL REFERENCES routes(id),
    user_id      BIGINT NOT NULL REFERENCES users(id),
    queue_type   TEXT NOT NULL CHECK (queue_type IN ('passenger', 'driver')),
    queue_number INTEGER NOT NULL,
    status       TEXT NOT NULL DEFAULT 'waiting'
                 CHECK (status IN ('waiting', 'on_deck', 'completed', 'cancelled', 'skipped', 'removed')),
    reason_code  TEXT,
    joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    -- Queue number unique within one route + type. Old tickets keep their number.
    CONSTRAINT queue_number_unique UNIQUE (route_id, queue_type, queue_number),
    -- reason_code domain
    CONSTRAINT queue_reason_code_valid
        CHECK (reason_code IS NULL OR reason_code IN ('no_show', 'vehicle_issue', 'driver_request', 'other')),
    -- skip/remove kinahanglan naay reason; uban status walay reason.
    CONSTRAINT queue_reason_required
        CHECK ((status IN ('skipped', 'removed') AND reason_code IS NOT NULL)
               OR (status NOT IN ('skipped', 'removed') AND reason_code IS NULL))
);

-- Rule 1: one active queue entry per user (DB level, not just API).
CREATE UNIQUE INDEX IF NOT EXISTS one_active_queue_per_user
    ON queue_entries (user_id) WHERE status IN ('waiting', 'on_deck');

CREATE INDEX IF NOT EXISTS queue_route_type_status_idx
    ON queue_entries (route_id, queue_type, status, queue_number);

CREATE INDEX IF NOT EXISTS queue_user_status_idx
    ON queue_entries (user_id, status);

CREATE TABLE IF NOT EXISTS dispatch_logs (
    id                  BIGSERIAL PRIMARY KEY,
    route_id            BIGINT NOT NULL REFERENCES routes(id),
    driver_user_id      BIGINT NOT NULL REFERENCES users(id),
    passenger_user_id   BIGINT NOT NULL REFERENCES users(id),
    driver_entry_id     BIGINT NOT NULL UNIQUE REFERENCES queue_entries(id),
    passenger_entry_id  BIGINT NOT NULL UNIQUE REFERENCES queue_entries(id),
    served_by           BIGINT REFERENCES users(id), -- driver or admin action
    served_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    action_type TEXT NOT NULL,
    details     JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_created_idx ON audit_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS demand_history (
    id           BIGSERIAL PRIMARY KEY,
    route_id     BIGINT NOT NULL REFERENCES routes(id),
    recorded_at  TIMESTAMPTZ NOT NULL,
    demand_count INTEGER NOT NULL CHECK (demand_count >= 0),
    UNIQUE (route_id, recorded_at)
);

CREATE TABLE IF NOT EXISTS predictions (
    id              BIGSERIAL PRIMARY KEY,
    route_id        BIGINT NOT NULL REFERENCES routes(id),
    predicted_for   TIMESTAMPTZ NOT NULL, -- hour bucket
    demand_level    TEXT NOT NULL CHECK (demand_level IN ('LOW', 'MEDIUM', 'HIGH')),
    predicted_count NUMERIC(6, 2),
    model_version   TEXT NOT NULL DEFAULT 'fallback',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (route_id, predicted_for)
);

COMMIT;
