-- ParkKeys seed data: 31 barangays + demo users + synthetic demand history.
-- Run AFTER schema.sql:
--   psql -U postgres -d parkkeys_db -f database/seed_data.sql
-- Passwords below are placeholders. Run `python scripts/seed_users.py` to set
-- the real bcrypt hashes (documented in README).

BEGIN;

INSERT INTO routes (name) VALUES
    ('Antonio Luna'),
    ('Bay-ang'),
    ('Bayabas'),
    ('Caasinan'),
    ('Cabinet'),
    ('Calamba'),
    ('Calibunan'),
    ('Comagascas'),
    ('Concepcion'),
    ('Del Pilar'),
    ('Katugasan'),
    ('Kauswagan'),
    ('La Union'),
    ('Mabini'),
    ('Mahaba'),
    ('Poblacion 1'),
    ('Poblacion 2'),
    ('Poblacion 3'),
    ('Poblacion 4'),
    ('Poblacion 5'),
    ('Poblacion 6'),
    ('Poblacion 7'),
    ('Poblacion 8'),
    ('Poblacion 9'),
    ('Poblacion 10'),
    ('Poblacion 11'),
    ('Poblacion 12'),
    ('Puting Bato'),
    ('Sanghan'),
    ('Soriano'),
    ('Tolosa')
ON CONFLICT (name) DO NOTHING;

-- Demo accounts. Hash gi-fill sa scripts/seed_users.py.
INSERT INTO users (email, password_hash, full_name, role) VALUES
    ('admin@parkkeys.com',      '!run-seed-users-script', 'Barangay Admin',    'admin'),
    ('driver1@parkkeys.com',   '!run-seed-users-script', 'Driver Ramon',      'driver'),
    ('driver2@parkkeys.com',   '!run-seed-users-script', 'Driver Nilo',       'driver'),
    ('driver3@parkkeys.com',   '!run-seed-users-script', 'Driver Jose',       'driver'),
    ('passenger1@parkkeys.com','!run-seed-users-script', 'Passenger Maria',   'passenger'),
    ('passenger2@parkkeys.com','!run-seed-users-script', 'Passenger Ana',     'passenger'),
    ('passenger3@parkkeys.com','!run-seed-users-script', 'Passenger Ben',     'passenger')
ON CONFLICT (email) DO NOTHING;

INSERT INTO drivers (user_id, tricycle_no, phone)
SELECT u.id, d.tricycle_no, d.phone
FROM (VALUES
    ('driver1@parkkeys.com', 'TRI-001', '09171230001'),
    ('driver2@parkkeys.com', 'TRI-002', '09171230002'),
    ('driver3@parkkeys.com', 'TRI-003', '09171230003')
) AS d(email, tricycle_no, phone)
JOIN users u ON u.email = d.email
ON CONFLICT (tricycle_no) DO NOTHING;

-- Synthetic hourly history para sa ML demo (30 days x 24 hours x 31 routes).
-- Only insert kung wala pa history, para safe ang re-run.
INSERT INTO demand_history (route_id, recorded_at, demand_count)
SELECT r.id,
       h.ts,
       GREATEST(0, (
           2
           + (r.id % 5)
           + CASE
               WHEN EXTRACT(hour FROM h.ts AT TIME ZONE 'Asia/Manila') BETWEEN 6 AND 9 THEN 4
               WHEN EXTRACT(hour FROM h.ts AT TIME ZONE 'Asia/Manila') BETWEEN 16 AND 18 THEN 3
               WHEN EXTRACT(hour FROM h.ts AT TIME ZONE 'Asia/Manila') BETWEEN 11 AND 13 THEN 2
               ELSE 0
             END
           + CASE WHEN EXTRACT(isodow FROM h.ts AT TIME ZONE 'Asia/Manila') IN (6, 7) THEN -1 ELSE 0 END
           + ((random() * 5)::int - 2)
       )::int)
FROM routes r
CROSS JOIN generate_series(
    date_trunc('hour', now()) - interval '29 days',
    date_trunc('hour', now()),
    interval '1 hour'
) AS h(ts)
WHERE NOT EXISTS (SELECT 1 FROM demand_history);

COMMIT;
