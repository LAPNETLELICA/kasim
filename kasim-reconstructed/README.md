# Kasim Secure Exam Platform

Kasim is a lecturer-controlled exam system with a Flutter web control plane, a
Flutter Windows student client, and a FastAPI policy service. This reconstruction
keeps the original cream/green lecturer palette and dark navy/blue student palette
while making the complete exam lifecycle explicit.

## What is implemented

- Email/password registration and sign-in, verified Google ID-token sign-in, and
  lecturer profile/dedicated-password updates.
- Five named exam access modes with no seeded browser or AI catalogue.
- On-demand browser and AI registration from the session-creation wizard.
- Six-character waiting-room codes, lecturer-controlled launch/stop, and an
  authoritative countdown shared by every student.
- Optional camera activation with periodic low-resolution frames and lecturer
  camera tiles.
- Multi-file student submissions and a lecturer download containing every file
  in a session/date-named ZIP archive.
- Dynamic, signed default-deny policies with browser/AI matrix enforcement,
  Windows process monitoring, and Chromium-family managed URL policies.
- Live attendance, compliance, camera, submission, and audit information.

## The five policy modes

| Mode | Browser rule | Web/AI rule |
| --- | --- | --- |
| Specific browser | One lecturer-named browser | Unrestricted web |
| Specific AI only | Any browser | Only one lecturer-named AI; standard sites blocked |
| Browser without AI | One lecturer-named browser | Standard web; AI blocked |
| Any browser, no AI | Any installed browser | Standard web; AI blocked |
| Browser + specific AI | One lecturer-named browser | Standard web plus one lecturer-named AI |

The API starts with an empty resource registry. Browser executable aliases and AI
domains are stored only when a lecturer enters them.

## Run locally

### 1. API

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

SQLite is used by default. Copy `.env.example` and set production secrets before
deploying.

### 2. Lecturer web app

```bash
cd lecturer
flutter pub get
flutter run -d chrome --web-port 3000 \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com \
  --dart-define=KASIM_API_URL=http://localhost:8000/api
```

### 3. Student Windows client

```powershell
cd student
flutter pub get
flutter run -d windows --dart-define=KASIM_API_URL=http://localhost:8000/api
```

Use `KASIM_API_URL` to point both applications at the deployed HTTPS API.

## Validation

The dependency-free authorization core can be tested without starting the API:

```bash
cd backend
python -m unittest app.test_policy_core
```

Full API and Flutter builds require the dependencies listed above.

## Production security notes

OS-level exam lockdown is a privileged security control, not a normal windowing
feature. Production releases should be code-signed, install the guard with the
required Windows privileges, use an organization-managed browser/network filter,
serve the API over TLS, rotate `SECRET_KEY` and `POLICY_SIGNING_KEY`, restrict
CORS, configure retention for camera frames/submissions, and obtain institutional
privacy/consent approval before enabling camera monitoring.
