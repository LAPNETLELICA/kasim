import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# PostgreSQL 18 Database Configuration with automatic fallback for local dev
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "sqlite:///./kasim.db"
)

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL, connect_args={"check_same_thread": False}
    )
else:
    try:
        engine = create_engine(
            DATABASE_URL,
            pool_size=10,
            max_overflow=20,
            pool_pre_ping=True
        )
        # Verify connection
        with engine.connect() as conn:
            pass
    except Exception as e:
        print(f"[Warning] PostgreSQL connection failed ({e}). Falling back to SQLite dev database.")
        DATABASE_URL = "sqlite:///./kasim.db"
        engine = create_engine(
            DATABASE_URL, connect_args={"check_same_thread": False}
        )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependency for acquiring database sessions per request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
