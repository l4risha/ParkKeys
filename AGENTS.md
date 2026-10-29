# ParkKeys: Project Spec (source of truth)
Barangay-based tricycle queue management system (Cabadbaran City). School project with a final oral defense, so keep code SIMPLE, readable, and defendable by a student.

Stack: Flutter Web (Dart) + FastAPI (Python) + PostgreSQL + scikit-learn. Folders: backend/, frontend/, database/, docs/

Roles (only 3): passenger, driver, admin. Role checks enforced SERVER-SIDE on every protected endpoint (JWT with role claim).

Core concept: Destinations are 31 barangays in table `routes` (single source of truth, UNIQUE name, `active` flag; inactive routes cannot be used for new queue entries). Barangays: Antonio Luna, Bay-ang, Bayabas, Caasinan, Cabinet, Calamba, Calibunan, Comagascas, Concepcion, Del Pilar, Katugasan, Kauswagan, La Union, Mabini, Mahaba, Poblacion 1 to Poblacion 12, Puting Bato, Sanghan, Soriano, Tolosa.
Two queues per barangay in table `queue_entries`: queue_type = 'passenger' or 'driver'.
- Passenger: selects barangay, joins passenger queue, sees queue number + passengers ahead + status, can cancel.
- Driver: views/selects route, joins driver queue, sees position, updates status, completes or leaves the queue.
- Admin: manages drivers (add/edit/deactivate), manages routes (add/edit/disable), monitors queues, views ML demand prediction (LOW/MEDIUM/HIGH), views reports, can skip/remove entries.
- Serving: the driver at position 1 and the passenger at position 1 of the SAME route are matched; both marked completed in ONE transaction; positions of both queues recomputed.

Business rules (enforce in API AND database):
1. One active entry (waiting/on_deck) per user via PostgreSQL partial unique index: CREATE UNIQUE INDEX one_active_queue_per_user ON queue_entries (user_id) WHERE status IN ('waiting','on_deck'); API returns 409 on duplicate.
2. Statuses: waiting, on_deck, completed, cancelled, skipped, removed. Cancelled/removed never count as waiting.
3. Admin skip/remove REQUIRES reason_code from: no_show, vehicle_issue, driver_request, other (422 if missing; DB CHECK constraint).
4. Every queue action (join, cancel, serve, skip, remove) and admin edit is written to audit_logs (user_id actor, action_type, details, ip_address, timestamp).
5. Passwords: use the `bcrypt` package directly (NOT passlib), cost >= 10. JWT auth.
6. Flutter NEVER touches the DB or holds secrets. All data via FastAPI REST API. Secrets only in backend .env (provide .env.example). CORS enabled for Flutter Web.
7. All counts/positions/queue numbers come from real DB queries. NEVER hard-code sample numbers.
8. Live updates: Flutter polls every 3 seconds (no WebSocket).
9. Public no-login endpoint + page: per barangay, drivers in queue + passengers waiting + demand level.
10. ML: scikit-learn predicts hourly demand per barangay as LOW/MEDIUM/HIGH; refresh every 30 min; if ML fails or has no data, return a fallback and never crash the main API. Include synthetic seed history so the demo works.
11. Non-functional: changes visible to clients within 3 seconds; REST API follows OpenAPI (FastAPI /docs); UI works 360px to 1920px; deployable via a repeatable script in 15 minutes.

Code style: simple, concise, short comments in Bisaya-English (code-switching). No over-engineering. No features outside this spec.
Working rules: never claim something is tested/committed unless you actually ran it. Show REAL output.
