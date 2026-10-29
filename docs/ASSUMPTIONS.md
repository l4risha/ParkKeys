# Assumptions

Simple choices made when the spec was silent. Keep this list updated.

1. **Queue number vs position.** `queue_entries.queue_number` is the ticket number assigned when joining (1, 2, 3, ... per route + queue_type). It never changes. *Position* and *passengers/drivers ahead* are computed live with `ROW_NUMBER()` over active entries (`waiting`, `on_deck`). This is how positions are "recomputed" after serve/skip/remove without rewriting old tickets.
2. **Active queue membership.** `waiting` and `on_deck` are both active and both count as waiting for public counts. `completed`, `cancelled`, `skipped`, `removed` are closed.
3. **Who serves?** The driver at position 1 calls `POST /api/queue/driver/serve`. The API then takes the passenger at position 1 of the same route. Admins cannot serve; they can only skip/remove.
4. **Driver status update.** `PATCH /api/queue/driver/status` only toggles between `waiting` and `on_deck`. Completing a trip is done through the serve endpoint so both sides close together.
5. **"Delete driver/route" = deactivate/disable.** Historical queue and dispatch rows keep their foreign keys. There is no hard delete.
6. **ML history table.** `demand_history` is added to hold synthetic hourly demand used to train scikit-learn. The spec's table list did not name it explicitly; this keeps demo history separate from real `dispatch_logs`.
7. **ML model.** One small `RandomForestRegressor` per route (features: hour of day, day of week). Predicted count becomes LOW (<4), MEDIUM (<8), HIGH (>=8). If training/reading fails, a rule-based average from history is used; if history is empty, LOW. The main API never crashes because of ML.
8. **JWT transport.** Login/register accept JSON (not OAuth2 form) because Flutter calls it directly. Tokens are Bearer tokens, HS256, expiry from `.env`.
9. **Local verification DB.** The system PostgreSQL password was unknown, so a second PostgreSQL cluster was initialized at `.pgdata/` on port **5433** for real pytest runs. The code is normal and works with the documented 5432 setup too.
10. **No pagination.** Queues and 31 routes are small; endpoints return full lists. Keeps the student demo simple.
11. **Timestamps** are stored with timezone (`TIMESTAMPTZ`). Business dates for reports use the server's date in Asia/Manila? Reports use `CURRENT_DATE` of the DB server; noted for the demo.
