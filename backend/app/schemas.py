from datetime import datetime
from typing import Optional, List
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


class ExamSessionCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(default=None, description="Dynamic duration of the exam in minutes")
    allowed_browser: str = Field(default="Google Chrome", description="Target allowed browser e.g. Google Chrome, Microsoft Edge")


class ExamSessionResponse(BaseModel):
    id: str
    title: str
    start_time: datetime
    end_time: datetime
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


# --- Student Session Schemas ---
class VerifyCodeRequest(BaseModel):
    exam_code: str = Field(..., min_length=6, max_length=6)


class LockdownRulesResponse(BaseModel):
    valid: bool
    exam_id: str
    title: str
    allowed_browser: str
    start_time: datetime
    end_time: datetime
    is_active: bool
    message: str


class StudentJoinRequest(BaseModel):
    exam_code: str = Field(..., min_length=6, max_length=6)
    device_info: Optional[str] = "Windows Desktop Client"


class StudentSessionResponse(BaseModel):
    session_id: str
    exam_id: str
    exam_title: str
    allowed_browser: str
    start_time: datetime
    end_time: datetime
    status: str
    joined_at: datetime

    class Config:
        from_attributes = True


class HeartbeatRequest(BaseModel):
    session_id: str
    current_running_browser: Optional[str] = None


class HeartbeatResponse(BaseModel):
    status: str
    is_exam_active: bool
    is_allowed: bool
    time_remaining_seconds: int
    message: str
