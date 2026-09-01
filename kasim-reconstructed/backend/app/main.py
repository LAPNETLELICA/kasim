import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import auth, exams, sessions, resources, policies, audit, camera, submissions
from app.schema_compat import apply_sqlite_compatibility_migrations

# Initialize database tables
apply_sqlite_compatibility_migrations(engine)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Kasim Secure Exam Platform API",
    description="Backend service powering the Kasim policy-based access control and browser lockdown system.",
    version="3.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS setup for the lecturer web dashboard and Flutter apps. Desktop requests are not subject
# to browser CORS, so production should set explicit HTTPS origins.
allowed_origins = [
    item.strip()
    for item in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000,http://localhost:7890,http://127.0.0.1:7890,http://localhost:7891,http://127.0.0.1:7891",
    ).split(",")
    if item.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(exams.router)
app.include_router(sessions.router)
app.include_router(resources.router)
app.include_router(policies.router)
app.include_router(audit.router)
app.include_router(camera.router)
app.include_router(submissions.router)



@app.get("/")
def root():
    return {
        "system": "Kasim Secure Exam Platform API",
        "version": "3.0.0",
        "status": "online",
        "database": engine.dialect.name,
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}
