# Kasim FastAPI Backend

Backend service powering the Kasim Exam System with PostgreSQL 18.

## Requirements
- Python 3.10+
- PostgreSQL 18 (or SQLite for development fallback)

## Setup & Running
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Swagger API documentation is available at `http://localhost:8000/docs`.
