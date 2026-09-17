-- Migration 001: users and drivers tables
-- Sprint 1 (schema finalization) + Sprint 2 (auth) support
-- Run manually on local dev DB first, or let SQLAlchemy create_all() bootstrap it in Sprint 1.

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'passenger', -- passenger | driver | admin
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS drivers (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_plate_number VARCHAR(20),
    route_name          VARCHAR(120),
    status              VARCHAR(20) NOT NULL DEFAULT 'offline', -- offline | queued | driving
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
