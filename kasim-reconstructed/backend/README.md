# Kasim FastAPI service

The API owns lecturer identity, dynamic resource registration, signed policies,
exam timing, student attendance, camera frames, submissions, and audit events.

## Run

```bash
python -m venv .venv
# activate the environment
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Interactive API documentation is available at `http://localhost:8000/docs`.
SQLite is the local default; set `DATABASE_URL` for PostgreSQL.

## Important environment variables

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | PostgreSQL/SQLite connection string |
| `SECRET_KEY` | JWT signing secret |
| `POLICY_SIGNING_KEY` | Signed desktop-policy HMAC key |
| `GOOGLE_CLIENT_ID` | Audience used to verify Google ID tokens |
| `KASIM_UPLOAD_ROOT` | Student document storage directory |
| `KASIM_CAMERA_ROOT` | Latest camera-frame storage directory |
| `KASIM_MAX_UPLOAD_BYTES` | Maximum bytes per submission |

## Main routes

- `/api/auth/*`: register, sign in, verified Google sign-in, and profile updates.
- `/api/exams/*`: create, list, launch, stop, and monitor sessions.
- `/api/sessions/*`: verify code, join, heartbeat, and student completion.
- `/api/camera/*`: camera state, frame ingestion, and lecturer feed.
- `/api/submissions/*`: upload/list/download, including session ZIP export.
- `/api/resources/*`: empty-by-default dynamic browser and AI registry.
- `/api/policies/*`: reusable signed policies and previews.
- `/api/audit/*`: policy-violation telemetry.

For a production deployment, use managed migrations and object storage rather
than the local SQLite compatibility migration and filesystem directories.
