from datetime import datetime
from typing import Optional, List, Literal
from pydantic import BaseModel, EmailStr, Field


# --- Auth & User Schemas ---
class UserBase(BaseModel):
    username: str = Field(..., min_length=2, description="Platform Name / Username")
    email: EmailStr
    role: str = Field(default="lecturer", description="Role must be 'lecturer' or 'student'")


class UserCreate(BaseModel):
    username: str = Field(..., min_length=2, description="Platform Name / Full Name")
    email: EmailStr
    password: str = Field(..., min_length=6)
    role: str = Field(default="lecturer")


class UserResponse(BaseModel):
    id: str
    username: str
    email: EmailStr
    role: str
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
    identifier: Optional[str] = Field(None, description="Email or Platform Name")
    username: Optional[str] = Field(None, description="Fallback username")
    password: str


class GoogleLoginRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = "Google Lecturer User"
    google_id: Optional[str] = None



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


# --- Resource Registry Schemas ---
class BrowserResourceCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    executables: List[str] = Field(..., min_items=1, description="List of executable names, e.g. ['chrome.exe', 'google-chrome']")
    description: Optional[str] = None


class BrowserResourceResponse(BaseModel):
    id: str
    name: str
    executables: List[str]
    description: Optional[str] = None
    is_custom: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AIResourceCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    domains: List[str] = Field(..., min_items=1, description="List of domain hostnames, e.g. ['claude.ai', 'api.anthropic.com']")
    desktop_executables: List[str] = Field(default_factory=list, description="List of desktop binary names, e.g. ['Claude.exe']")
    description: Optional[str] = None


class AIResourceResponse(BaseModel):
    id: str
    name: str
    domains: List[str]
    desktop_executables: List[str]
    description: Optional[str] = None
    is_custom: bool
    created_at: datetime

    class Config:
        from_attributes = True


# --- Policy Schemas ---
class AccessPolicyCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    description: Optional[str] = None
    default_action: str = Field(default="DENY")
    browser_mode: str = Field(default="ALLOW_SELECTED", description="ALLOW_SELECTED or BLOCK_ALL")
    ai_mode: str = Field(default="ALLOW_SELECTED", description="ALLOW_SELECTED or BLOCK_ALL")
    desktop_app_mode: str = Field(default="BLOCK_ALL_UNAUTHORIZED")
    allowed_browsers: List[str] = Field(default_factory=list, description="List of allowed browser resource IDs")
    allowed_ai: List[str] = Field(default_factory=list, description="List of allowed AI resource IDs")
    browser_ai_matrix: dict = Field(default_factory=dict, description="Map of browser_id -> list of allowed AI resource IDs")
    allowed_desktop_apps: List[str] = Field(default_factory=list, description="List of allowed desktop app binary names")


class AccessPolicyResponse(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    version: int
    default_action: str
    browser_mode: str
    ai_mode: str
    desktop_app_mode: str
    allowed_browsers: List[str]
    allowed_ai: List[str]
    browser_ai_matrix: dict
    allowed_desktop_apps: List[str]
    signature: Optional[str] = None
    lecturer_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SignedPolicyPayload(BaseModel):
    policy_id: str
    version: int
    issued_at: str
    expires_at: str
    default_action: str = "DENY"
    browser_mode: str
    ai_mode: str
    desktop_app_mode: str
    registered_browsers: List[BrowserResourceResponse]
    registered_ai: List[AIResourceResponse]
    allowed_browsers: List[str]
    allowed_ai: List[str]
    browser_ai_matrix: dict
    allowed_desktop_apps: List[str]
    signature: str


# --- Policy Preview & Matrix Simulation Schemas ---
class PreviewMatrixItem(BaseModel):
    browser_name: str
    browser_status: str  # ALLOW / DENY
    ai_name: str
    ai_status: str       # ALLOW / DENY
    pair_permission: str # ALLOW / DENY
    reason: str


class PolicyPreviewResponse(BaseModel):
    policy_title: str
    default_action: str = "DENY"
    browser_summary: List[dict] # [{"name": "Chrome", "status": "ALLOW"}, ...]
    ai_summary: List[dict]      # [{"name": "Claude", "status": "ALLOW"}, ...]
    matrix_rules: List[PreviewMatrixItem]
    desktop_app_summary: List[dict]


# --- Audit & Violation Schemas ---
class AuditViolationCreate(BaseModel):
    exam_session_id: Optional[str] = None
    student_session_id: Optional[str] = None
    student_name: str
    device_id: Optional[str] = None
    violation_type: str  # e.g., UNAUTHORIZED_BROWSER, UNAUTHORIZED_AI_DOMAIN, UNAUTHORIZED_DESKTOP_APP
    resource_name: str
    action_taken: str = "BLOCKED"
    details: Optional[str] = None


class AuditViolationResponse(BaseModel):
    id: str
    exam_session_id: Optional[str] = None
    student_session_id: Optional[str] = None
    student_name: str
    device_id: Optional[str] = None
    violation_type: str
    resource_name: str
    action_taken: str
    details: Optional[str] = None
    timestamp: datetime

    class Config:
        from_attributes = True


class ExamSessionCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    duration_minutes: int = Field(default=60, ge=1, description="Duration of the exam in minutes (must be >= 1)")
    allowed_browser: Optional[str] = Field(
        default="Google Chrome",
        description="Backward compatible allowed browser string"
    )
    policy_id: Optional[str] = Field(default=None, description="Linked Access Policy ID")


class ExamSessionResponse(BaseModel):
    id: str
    title: str
    duration_minutes: int
    status: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    allowed_browser: str
    policy_id: Optional[str] = None
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
    policy: Optional[AccessPolicyResponse] = None


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
    policy_id: Optional[str] = None
    signed_policy: Optional[SignedPolicyPayload] = None
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
    policy_id: Optional[str] = None
    signed_policy: Optional[SignedPolicyPayload] = None
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
    violation_event: Optional[AuditViolationCreate] = None


class HeartbeatResponse(BaseModel):
    status: str
    exam_status: str
    is_exam_active: bool
    is_allowed: bool
    policy_version: int = 1
    signed_policy: Optional[SignedPolicyPayload] = None
    time_remaining_seconds: int
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    message: str

