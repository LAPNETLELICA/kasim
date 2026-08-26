from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Integer, Text
from sqlalchemy.orm import relationship
from app.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class BrowserResource(Base):
    __tablename__ = "browser_resources"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, unique=True, nullable=False, index=True)
    executables = Column(Text, nullable=False)  # JSON string array e.g. ["chrome.exe", "google-chrome"]
    description = Column(Text, nullable=True)
    is_custom = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utc_now)


class AIResource(Base):
    __tablename__ = "ai_resources"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, unique=True, nullable=False, index=True)
    domains = Column(Text, nullable=False)  # JSON string array e.g. ["claude.ai", "api.anthropic.com"]
    desktop_executables = Column(Text, nullable=False, default="[]")  # JSON string array e.g. ["Claude.exe"]
    description = Column(Text, nullable=True)
    is_custom = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utc_now)


class AccessPolicy(Base):
    __tablename__ = "access_policies"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    version = Column(Integer, nullable=False, default=1)
    default_action = Column(String, nullable=False, default="DENY")
    browser_mode = Column(String, nullable=False, default="ALLOW_SELECTED")  # "ALLOW_SELECTED", "BLOCK_ALL"
    ai_mode = Column(String, nullable=False, default="ALLOW_SELECTED")       # "ALLOW_SELECTED", "BLOCK_ALL"
    desktop_app_mode = Column(String, nullable=False, default="BLOCK_ALL_UNAUTHORIZED")
    allowed_browsers = Column(Text, nullable=False, default="[]")  # JSON list of browser IDs
    allowed_ai = Column(Text, nullable=False, default="[]")        # JSON list of AI IDs
    browser_ai_matrix = Column(Text, nullable=False, default="{}")  # JSON dict e.g. {"brw_1": ["ai_1"]}
    allowed_desktop_apps = Column(Text, nullable=False, default="[]")
    signature = Column(String, nullable=True)
    lecturer_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=utc_now)
    updated_at = Column(DateTime, default=utc_now, onupdate=utc_now)

    # Relationships
    lecturer = relationship("User", back_populates="created_policies")
    exam_sessions = relationship("ExamSession", back_populates="policy")


class AuditViolation(Base):
    __tablename__ = "audit_violations"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    exam_session_id = Column(String, ForeignKey("exam_sessions.id"), nullable=True)
    student_session_id = Column(String, ForeignKey("student_sessions.id"), nullable=True)
    student_name = Column(String, nullable=False)
    device_id = Column(String, nullable=True)
    violation_type = Column(String, nullable=False)  # e.g., "UNAUTHORIZED_BROWSER", "UNAUTHORIZED_AI_DOMAIN", "UNAUTHORIZED_DESKTOP_APP"
    resource_name = Column(String, nullable=False)
    action_taken = Column(String, nullable=False, default="BLOCKED")
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=utc_now)


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
    created_policies = relationship("AccessPolicy", back_populates="lecturer", cascade="all, delete-orphan")
    sessions = relationship("StudentSession", back_populates="student", cascade="all, delete-orphan")


class ExamSession(Base):
    __tablename__ = "exam_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    duration_minutes = Column(Integer, nullable=False, default=60)
    status = Column(String, nullable=False, default="waiting")  # "waiting", "active", "completed"
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    allowed_browser = Column(String, nullable=False, default="Google Chrome")  # Backward compatibility field
    policy_id = Column(String, ForeignKey("access_policies.id"), nullable=True)
    exam_code = Column(String(6), unique=True, nullable=False, index=True)
    is_active = Column(Boolean, default=True)
    lecturer_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=utc_now)

    # Relationships
    lecturer = relationship("User", back_populates="created_exams")
    policy = relationship("AccessPolicy", back_populates="exam_sessions")
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

