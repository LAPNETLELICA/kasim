import datetime
import uuid
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Integer, Text
from sqlalchemy.orm import relationship
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    role = Column(String, nullable=False, default="student")  # "lecturer" or "student"
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    created_exams = relationship("ExamSession", back_populates="lecturer", cascade="all, delete-orphan")
    sessions = relationship("StudentSession", back_populates="student", cascade="all, delete-orphan")


class ExamSession(Base):
    __tablename__ = "exam_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    allowed_browser = Column(String, nullable=False, default="Google Chrome")  # e.g., "Google Chrome", "Microsoft Edge"
    exam_code = Column(String(6), unique=True, nullable=False, index=True)
    is_active = Column(Boolean, default=True)
    lecturer_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    lecturer = relationship("User", back_populates="created_exams")
    student_sessions = relationship("StudentSession", back_populates="exam_session", cascade="all, delete-orphan")


class StudentSession(Base):
    __tablename__ = "student_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    exam_session_id = Column(String, ForeignKey("exam_sessions.id"), nullable=False)
    student_id = Column(String, ForeignKey("users.id"), nullable=False)
    joined_at = Column(DateTime, default=datetime.datetime.utcnow)
    status = Column(String, default="active")  # "active", "completed", "terminated"
    device_info = Column(Text, nullable=True)
    last_heartbeat = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    exam_session = relationship("ExamSession", back_populates="student_sessions")
    student = relationship("User", back_populates="sessions")
