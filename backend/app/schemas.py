from datetime import datetime
from typing import Optional, List, Literal
from pydantic import BaseModel, EmailStr, Field


# --- Auth & User Schemas ---
class UserBase(BaseModel):
    username: str
    email: EmailStr
    role: str = Field(..., description="Role must be 'lecturer' or 'student'")


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)


class UserResponse(UserBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenData(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


ALLOWED_BROWSERS = Literal[
    "Google Chrome",
    "Microsoft Edge",
    "Mozilla Firefox",
    "Brave",
]


class StudentAttendanceItem(BaseModel):
    session_id: str
    student_name: str
    joined_at: datetime
    status: str
    device_info: Optional[str] = None
    browser_compliant: bool = True
    last_heartbeat: datetime

    class Config:
        from_attributes = True


class ExamSessionCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    duration_minutes: int = Field(default=60, ge=1, description="Duration of the exam in minutes (must be >= 1)")
    allowed_browser: ALLOWED_BROWSERS = Field(
        default="Google Chrome",
        description="Allowed browser: Google Chrome, Microsoft Edge, Mozilla Firefox, or Brave"
    )


class ExamSessionResponse(BaseModel):
    id: str
    title: str
    duration_minutes: int
    status: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    allowed_browser: str
    exam_code: str
    is_active: bool
    lecturer_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class ExamSessionDetail(ExamSessionResponse):
    active_students_count: int = 0
    total_joined_count: int = 0
    attendance: List[StudentAttendanceItem] = []


class AttendanceSummaryResponse(BaseModel):
    exam_id: str
    title: str
    status: str
    duration_minutes: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    total_attendees: int = 0
    active_attendees: int = 0
    completed_attendees: int = 0
    attendance_list: List[StudentAttendanceItem] = []


# --- Student Session Schemas ---
class VerifyCodeRequest(BaseModel):
    exam_code: str = Field(..., min_length=6, max_length=6)


class LockdownRulesResponse(BaseModel):
    valid: bool
    exam_id: str
    title: str
    allowed_browser: str
    duration_minutes: int = 60
    status: str = "waiting"
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    is_active: bool
    message: str


class StudentJoinRequest(BaseModel):
    exam_code: str = Field(..., min_length=6, max_length=6)
    student_name: str = Field(..., min_length=2, max_length=100)
    device_info: Optional[str] = "Windows Desktop Client"


class StudentSessionResponse(BaseModel):
    session_id: str
    exam_id: str
    exam_title: str
    student_name: str
    allowed_browser: str
    duration_minutes: int
    exam_status: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    status: str
    joined_at: datetime

    class Config:
        from_attributes = True


class HeartbeatRequest(BaseModel):
    session_id: str
    current_running_browser: Optional[str] = None


class HeartbeatResponse(BaseModel):
    status: str
    exam_status: str
    is_exam_active: bool
    is_allowed: bool
    time_remaining_seconds: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    message: str
