from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Integer, Text
from sqlalchemy.orm import relationship
from app.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    role = Column(String, nullable=False, default="student")  # "lecturer" or "student"
    created_at = Column(DateTime, default=utc_now)

    # Relationships
    created_exams = relationship("ExamSession", back_populates="lecturer", cascade="all, delete-orphan")
    sessions = relationship("StudentSession", back_populates="student", cascade="all, delete-orphan")


class ExamSession(Base):
    __tablename__ = "exam_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    duration_minutes = Column(Integer, nullable=False, default=60)
    status = Column(String, nullable=False, default="waiting")  # "waiting", "active", "completed"
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    allowed_browser = Column(String, nullable=False, default="Google Chrome")  # "Google Chrome", "Microsoft Edge", "Mozilla Firefox", "Brave"
    exam_code = Column(String(6), unique=True, nullable=False, index=True)
    is_active = Column(Boolean, default=True)
    lecturer_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=utc_now)

    # Relationships
    lecturer = relationship("User", back_populates="created_exams")
    student_sessions = relationship("StudentSession", back_populates="exam_session", cascade="all, delete-orphan")


class StudentSession(Base):
    __tablename__ = "student_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    exam_session_id = Column(String, ForeignKey("exam_sessions.id"), nullable=False)
    student_name = Column(String, nullable=False)
    student_id = Column(String, ForeignKey("users.id"), nullable=True)
    joined_at = Column(DateTime, default=utc_now)
    status = Column(String, default="waiting")  # "waiting", "active", "completed", "terminated"
    device_info = Column(Text, nullable=True)
    browser_compliant = Column(Boolean, default=True)
    last_heartbeat = Column(DateTime, default=utc_now)

    # Relationships
    exam_session = relationship("ExamSession", back_populates="student_sessions")
    student = relationship("User", back_populates="sessions")
