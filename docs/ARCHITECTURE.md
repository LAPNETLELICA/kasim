# Kasim System Architecture & Operations Manual

## 1. Overview & Repository Architecture

Kasim is a secure exam management platform built with a modular, multi-folder structure. It features a centralized Python FastAPI backend integrated with PostgreSQL 18, a Flutter Web administration portal for lecturers, and a Flutter Windows Desktop Client for students with automated environment lockdown enforcement.

```
kasim/
├── backend/                  # FastAPI Python Application (PostgreSQL 18)
│   ├── app/
│   │   ├── main.py           # FastAPI entry point, CORS & router inclusion
│   │   ├── database.py       # PostgreSQL 18 SQLAlchemy connection pool
│   │   ├── models.py         # DB models (User, ExamSession, StudentSession)
│   │   ├── schemas.py        # Pydantic validation schemas
│   │   ├── security.py       # JWT tokens & bcrypt password hashing
│   │   └── routers/
│   │       ├── auth.py       # User registration, login, JWT token auth
│   │       ├── exams.py      # Exam session creation & unique code generation
│   │       └── sessions.py   # Code verification, join, heartbeat & lockdown rules
│   ├── run.bat               # Automation script to activate venv & run FastAPI server
│   └── requirements.txt      # Python dependencies
│
├── lecturer/                 # Flutter Web Application for Teachers
│   ├── lib/                  # Login, Dashboard, Exam Creation & Live Monitor
│   ├── run.bat               # Launch Web App
│   └── pubspec.yaml          # Flutter Web configuration
│
├── student/                  # Flutter Windows Desktop Client for Students
│   ├── lib/                  # Student auth, Exam Code entry, Active Lockdown UI
│   ├── run.bat               # Launch Windows desktop app
│   ├── build_release.bat     # Build release executable script
│   ├── installer_setup.iss   # Inno Setup installer builder script
│   └── pubspec.yaml          # Flutter Desktop configuration
│
├── docs/
│   ├── ARCHITECTURE.md       # Complete system architecture documentation
│   └── DEPLOYMENT_GUIDE.md   # Production build & student deployment guide
```

---

## 2. System Architecture & Data Flow

```mermaid
sequenceDiagram
    autonumber
    actor Lecturer as Lecturer (Web App)
    participant Backend as FastAPI Backend (Port 8000)
    participant DB as PostgreSQL 18 DB
    actor Student as Student (Windows Desktop App)

    Lecturer->>Backend: POST /api/auth/login
    Backend-->>Lecturer: Return JWT Token

    Lecturer->>Backend: POST /api/exams/ (Title, Start/End Time, Allowed Browser)
    Backend->>DB: Store ExamSession & Generate Unique 6-Digit Code
    Backend-->>Lecturer: Exam Created (Code: e.g. "X9K2P4")

    Student->>Backend: POST /api/sessions/verify-code ("X9K2P4")
    Backend->>DB: Query ExamSession & Check Time Window
    Backend-->>Student: Return Lockdown Rules (Allowed Browser: "Google Chrome", Time Window)

    Student->>Backend: POST /api/sessions/join
    Backend->>DB: Create StudentSession (status="active")
    Backend-->>Student: Confirm Session Joined

    loop Heartbeat & Lockdown Monitoring (Every 10 Seconds)
        Student->>Student: Inspect Windows Running Processes (tasklist)
        Student->>Backend: POST /api/sessions/heartbeat (sessionId, runningBrowser)
        Backend->>DB: Update last_heartbeat & verify expiry
        Backend-->>Student: Heartbeat Response (is_exam_active, time_remaining_seconds)
    end

    note over Student,Backend: Once End Time is reached:
    Backend-->>Student: Response (is_exam_active=false, time_remaining=0)
    Student->>Student: Lockdown Automatically Released
```

---

## 3. Database Schema (PostgreSQL 18)

### `users` Table
- `id` (VARCHAR, PK, UUID): Unique user identifier.
- `username` (VARCHAR, UNIQUE, INDEX): Login username.
- `email` (VARCHAR, UNIQUE, INDEX): User email address.
- `hashed_password` (VARCHAR): Bcrypt hashed password.
- `role` (VARCHAR): User role (`lecturer` or `student`).
- `created_at` (TIMESTAMP): Registration timestamp.

### `exam_sessions` Table
- `id` (VARCHAR, PK, UUID): Exam session identifier.
- `title` (VARCHAR): Exam title.
- `start_time` (TIMESTAMP): Scheduled start time (UTC).
- `end_time` (TIMESTAMP): Scheduled end time (UTC).
- `allowed_browser` (VARCHAR): Policy browser requirement (e.g. `Google Chrome`, `Microsoft Edge`).
- `exam_code` (VARCHAR(6), UNIQUE, INDEX): 6-character uppercase alphanumeric exam code.
- `is_active` (BOOLEAN): Master toggle status set by lecturer.
- `lecturer_id` (VARCHAR, FK -> `users.id`): Creator lecturer reference.
- `created_at` (TIMESTAMP): Creation timestamp.

### `student_sessions` Table
- `id` (VARCHAR, PK, UUID): Joined session identifier.
- `exam_session_id` (VARCHAR, FK -> `exam_sessions.id`): Associated exam.
- `student_id` (VARCHAR, FK -> `users.id`): Participating student.
- `joined_at` (TIMESTAMP): Join timestamp.
- `status` (VARCHAR): Status (`active`, `completed`, `terminated`).
- `device_info` (TEXT): Client environment details.
- `last_heartbeat` (TIMESTAMP): Most recent keepalive timestamp.

---

## 4. Browser Lockdown Enforcement & Expiration Lifecycle

1. **Lecturer Session Initialization:**
   - The lecturer logs into `lecturer/` web app, creates an exam specifying title, duration, and target allowed browser (e.g., Google Chrome).
   - The system generates a unique **Exam Code** (e.g., `A7B9X2`).

2. **Student Authentication & Code Verification:**
   - The student opens the `student/` Windows desktop application and enters the 6-digit Exam Code.
   - Backend checks code validity, master active status, and time window (`start_time <= UTC NOW <= end_time`).

3. **Desktop Environment Lockdown:**
   - The desktop app initiates `LockdownService` process monitoring.
   - It verifies that the designated allowed browser is running and alerts/flags any non-permitted browser or forbidden background application.
   - Regular heartbeats are sent to the backend to confirm active compliance.

4. **Auto-Expiration Release:**
   - When the scheduled `end_time` is reached, the backend heartbeat response returns `is_exam_active=false` with `time_remaining_seconds=0`.
   - The student desktop application automatically terminates process restriction polling and notifies the student that restrictions are released.

---

## 5. Local Setup & Execution Guide

### Prerequisites
- Python 3.10+
- PostgreSQL 18
- Flutter SDK (for Web and Windows Desktop builds)

---

### Step 1: Run Backend Service (FastAPI)

```bash
# Navigate to backend directory
cd backend

# Create virtual environment (optional)
python -m venv venv
# On Windows PowerShell:
.\venv\Scripts\Activate.ps1

# Install requirements
pip install -r requirements.txt

# Set Database Connection String (Optional, defaults to local PostgreSQL)
$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/kasim_db"

# Launch FastAPI server
uvicorn app.main:app --reload --port 8000
```
- Interactive API Documentation available at: `http://localhost:8000/docs`

---

### Step 2: Run Lecturer Web Dashboard

```bash
# Navigate to lecturer directory
cd lecturer

# Install Flutter dependencies
flutter pub get

# Run Flutter Web app on Chrome
flutter run -d chrome --web-port 3000
```

---

### Step 3: Run Student Windows Desktop Client

```bash
# Navigate to student directory
cd student

# Install Flutter dependencies
flutter pub get

# Run Windows Desktop application
flutter run -d windows
```
