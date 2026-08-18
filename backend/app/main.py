from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import auth, exams, sessions

# Initialize database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Kasim Secure Exam Platform API",
    description="Backend service powering the Kasim exam management and browser lockdown system.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS setup for Web Lecturer Dashboard and Windows Student Desktop App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(exams.router)
app.include_router(sessions.router)


@app.get("/")
def root():
    return {
        "system": "Kasim Secure Exam Platform API",
        "version": "2.0.0",
        "status": "online",
        "database": "PostgreSQL 18"
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}
