import json
import random
import re
import string
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models, schemas, security
from app.database import get_db
from app.policy_engine import generate_policy_signature
from app.policy_modes import semantics_for


router = APIRouter(prefix="/api/exams", tags=["Exam Management"])


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def generate_unique_exam_code(db: Session) -> str:
    chars = string.ascii_uppercase + string.digits
    for _ in range(100):
        code = "".join(random.choices(chars, k=6))
        exists = db.query(models.ExamSession.id).filter(
            models.ExamSession.exam_code == code
        ).first()
        if not exists:
            return code
    raise RuntimeError("Could not generate a unique exam code")


def _normalize_domain(value: str) -> str:
    domain = value.strip().lower()
    domain = re.sub(r"^https?://", "", domain).split("/", 1)[0]
    domain = domain.split(":", 1)[0].strip(".")
    if not domain or "." not in domain or " " in domain:
        raise HTTPException(status_code=422, detail=f"Invalid AI domain: {value}")
    return domain


def _default_executables(name: str) -> list[str]:
    compact = re.sub(r"[^a-z0-9]", "", name.lower())
    return [f"{compact}.exe", compact]


def _get_or_create_browser(
    db: Session,
    name: str,
    executables: list[str],
    exam_title: str,
) -> models.BrowserResource:
    browser = db.query(models.BrowserResource).filter(
        models.BrowserResource.name.ilike(name.strip())
    ).first()
    normalized_execs = list(dict.fromkeys(
        value.strip() for value in (executables or _default_executables(name)) if value.strip()
    ))
    if browser:
        existing = json.loads(browser.executables or "[]")
        browser.executables = json.dumps(list(dict.fromkeys([*existing, *normalized_execs])))
        return browser
    browser = models.BrowserResource(
        name=name.strip(),
        executables=json.dumps(normalized_execs),
        description=f"Registered while creating {exam_title}",
        is_custom=True,
    )
    db.add(browser)
    db.flush()
    return browser


def _get_or_create_ai(
    db: Session,
    name: str,
    domains: list[str],
    desktop_executables: list[str],
    exam_title: str,
) -> models.AIResource:
    normalized_domains = list(dict.fromkeys(_normalize_domain(value) for value in domains))
    if not normalized_domains:
        raise HTTPException(
            status_code=422,
            detail="Enter at least one domain for the AI service so the desktop policy can enforce it.",
        )
    ai = db.query(models.AIResource).filter(
        models.AIResource.name.ilike(name.strip())
    ).first()
    normalized_execs = list(dict.fromkeys(value.strip() for value in desktop_executables if value.strip()))
    if ai:
        existing_domains = json.loads(ai.domains or "[]")
        existing_execs = json.loads(ai.desktop_executables or "[]")
        ai.domains = json.dumps(list(dict.fromkeys([*existing_domains, *normalized_domains])))
        ai.desktop_executables = json.dumps(list(dict.fromkeys([*existing_execs, *normalized_execs])))
        return ai
    ai = models.AIResource(
        name=name.strip(),
        domains=json.dumps(normalized_domains),
        desktop_executables=json.dumps(normalized_execs),
        description=f"Registered while creating {exam_title}",
        is_custom=True,
    )
    db.add(ai)
    db.flush()
    return ai


def _create_policy_for_exam(
    db: Session,
    exam_in: schemas.ExamSessionCreate,
    lecturer_id: str,
) -> tuple[models.AccessPolicy, str, Optional[str]]:
    semantics = semantics_for(exam_in.policy_mode)
    browser = None
    ai = None
    browser_name = (exam_in.browser_name or exam_in.allowed_browser or "").strip()
    ai_name = (exam_in.ai_name or "").strip()
    if semantics.needs_browser and not browser_name:
        raise HTTPException(status_code=422, detail="This policy mode requires a browser name.")
    if semantics.needs_ai and not ai_name:
        raise HTTPException(status_code=422, detail="This policy mode requires an AI service name.")

    if semantics.needs_browser:
        browser = _get_or_create_browser(
            db, browser_name, exam_in.browser_executables, exam_in.title
        )
    if semantics.needs_ai:
        ai = _get_or_create_ai(
            db,
            ai_name,
            exam_in.ai_domains,
            exam_in.ai_desktop_executables,
            exam_in.title,
        )

    allowed_browsers = [browser.id] if browser else []
    allowed_ai = [ai.id] if ai else []
    matrix: dict[str, list[str]] = {}
    if browser and ai:
        matrix[browser.id] = [ai.id]
    elif browser:
        matrix[browser.id] = ["*"] if semantics.ai_mode == "ALLOW_ANY" else []
    elif ai:
        matrix["*"] = [ai.id]

    policy = models.AccessPolicy(
        title=f"Policy · {exam_in.title}",
        description=exam_in.description,
        version=1,
        default_action="DENY",
        policy_mode=exam_in.policy_mode,
        browser_mode=semantics.browser_mode,
        ai_mode=semantics.ai_mode,
        web_access_scope=semantics.web_access_scope,
        desktop_app_mode="BLOCK_ALL_UNAUTHORIZED",
        allowed_browsers=json.dumps(allowed_browsers),
        allowed_ai=json.dumps(allowed_ai),
        browser_ai_matrix=json.dumps(matrix),
        allowed_desktop_apps=json.dumps(
            exam_in.ai_desktop_executables if ai and semantics.ai_mode == "ALLOW_SELECTED" else []
        ),
        lecturer_id=lecturer_id,
    )
    policy.signature = generate_policy_signature({
        "title": policy.title,
        "version": 1,
        "default_action": "DENY",
        "policy_mode": policy.policy_mode,
        "browser_mode": policy.browser_mode,
        "ai_mode": policy.ai_mode,
        "web_access_scope": policy.web_access_scope,
        "allowed_browsers": allowed_browsers,
        "allowed_ai": allowed_ai,
        "browser_ai_matrix": matrix,
    })
    db.add(policy)
    db.flush()
    return policy, browser.name if browser else "Any installed browser", ai.name if ai else None


def _auto_complete(db: Session, exam: models.ExamSession) -> None:
    end_time = ensure_utc(exam.end_time)
    if exam.status == "active" and end_time and utc_now() >= end_time:
        exam.status = "completed"
        exam.is_active = False
        sessions = db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id,
            models.StudentSession.status == "active",
        ).all()
        for student_session in sessions:
            student_session.status = "completed"
            student_session.completed_at = utc_now()
        db.commit()


def _attendance_list(db: Session, exam_id: str) -> list[schemas.StudentAttendanceItem]:
    sessions = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam_id
    ).order_by(models.StudentSession.joined_at.asc()).all()
    return [
        schemas.StudentAttendanceItem(
            session_id=item.id,
            student_name=item.student_name,
            joined_at=ensure_utc(item.joined_at) or utc_now(),
            status=item.status,
            device_info=item.device_info,
            browser_compliant=item.browser_compliant is not False,
            last_heartbeat=ensure_utc(item.last_heartbeat) or utc_now(),
            camera_status=item.camera_status or "not_required",
            camera_frame_updated_at=ensure_utc(item.camera_frame_updated_at),
            submission_count=db.query(models.Submission).filter(
                models.Submission.student_session_id == item.id
            ).count(),
            completed_at=ensure_utc(item.completed_at),
        )
        for item in sessions
    ]


def _base_response(exam: models.ExamSession) -> dict:
    return {
        "id": exam.id,
        "title": exam.title,
        "description": exam.description,
        "duration_minutes": exam.duration_minutes or 60,
        "status": exam.status,
        "start_time": ensure_utc(exam.start_time),
        "end_time": ensure_utc(exam.end_time),
        "allowed_browser": exam.allowed_browser,
        "allowed_ai": exam.allowed_ai,
        "policy_mode": exam.policy_mode,
        "camera_required": bool(exam.camera_required),
        "submissions_enabled": bool(exam.submissions_enabled),
        "policy_id": exam.policy_id,
        "exam_code": exam.exam_code,
        "is_active": bool(exam.is_active),
        "lecturer_id": exam.lecturer_id,
        "created_at": ensure_utc(exam.created_at) or utc_now(),
    }


def _detail_response(db: Session, exam: models.ExamSession) -> schemas.ExamSessionDetail:
    attendance = _attendance_list(db, exam.id)
    policy_response = None
    if exam.policy:
        from app.routers.policies import parse_policy_response

        policy_response = parse_policy_response(exam.policy)
    return schemas.ExamSessionDetail(
        **_base_response(exam),
        active_students_count=sum(item.status in {"waiting", "active"} for item in attendance),
        total_joined_count=len(attendance),
        submission_count=db.query(models.Submission).filter(
            models.Submission.exam_session_id == exam.id
        ).count(),
        attendance=attendance,
        policy=policy_response,
    )


def _owned_exam(db: Session, exam_id: str, user: models.User) -> models.ExamSession:
    exam = db.query(models.ExamSession).filter(models.ExamSession.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam session not found")
    if user.role == "lecturer" and exam.lecturer_id != user.id:
        raise HTTPException(status_code=403, detail="You do not own this exam session")
    return exam


@router.post("/", response_model=schemas.ExamSessionResponse, status_code=status.HTTP_201_CREATED)
def create_exam_session(
    exam_in: schemas.ExamSessionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    if exam_in.policy_id:
        policy = db.query(models.AccessPolicy).filter(
            models.AccessPolicy.id == exam_in.policy_id,
            models.AccessPolicy.lecturer_id == current_user.id,
        ).first()
        if not policy:
            raise HTTPException(status_code=404, detail="Policy template not found")
        browser_display = (exam_in.browser_name or exam_in.allowed_browser or "Policy-defined browser").strip()
        ai_display = (exam_in.ai_name or "").strip() or None
        policy_mode = policy.policy_mode
    else:
        policy, browser_display, ai_display = _create_policy_for_exam(db, exam_in, current_user.id)
        policy_mode = exam_in.policy_mode

    exam = models.ExamSession(
        title=exam_in.title.strip(),
        description=(exam_in.description or "").strip() or None,
        duration_minutes=exam_in.duration_minutes,
        status="waiting",
        allowed_browser=browser_display,
        allowed_ai=ai_display,
        policy_mode=policy_mode,
        camera_required=exam_in.camera_required,
        submissions_enabled=exam_in.submissions_enabled,
        policy_id=policy.id,
        exam_code=generate_unique_exam_code(db),
        is_active=True,
        lecturer_id=current_user.id,
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return schemas.ExamSessionResponse(**_base_response(exam))


@router.get("/", response_model=List[schemas.ExamSessionDetail])
def list_lecturer_exams(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exams = db.query(models.ExamSession).filter(
        models.ExamSession.lecturer_id == current_user.id
    ).order_by(models.ExamSession.created_at.desc()).all()
    for exam in exams:
        _auto_complete(db, exam)
    return [_detail_response(db, exam) for exam in exams]


@router.get("/{exam_id}", response_model=schemas.ExamSessionDetail)
def get_exam_detail(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    exam = _owned_exam(db, exam_id, current_user)
    _auto_complete(db, exam)
    return _detail_response(db, exam)


@router.post("/{exam_id}/start", response_model=schemas.ExamSessionDetail)
def start_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    if exam.status == "completed":
        raise HTTPException(status_code=409, detail="Completed sessions cannot be restarted")
    now = utc_now()
    exam.status = "active"
    exam.start_time = now
    exam.end_time = now + timedelta(minutes=exam.duration_minutes or 60)
    exam.is_active = True
    for student_session in exam.student_sessions:
        if student_session.status == "waiting":
            student_session.status = "active"
    db.commit()
    db.refresh(exam)
    return _detail_response(db, exam)


@router.post("/{exam_id}/stop", response_model=schemas.ExamSessionDetail)
def stop_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    now = utc_now()
    exam.status = "completed"
    exam.end_time = now
    exam.is_active = False
    for student_session in exam.student_sessions:
        if student_session.status in {"waiting", "active"}:
            student_session.status = "completed"
            student_session.completed_at = now
    db.commit()
    db.refresh(exam)
    return _detail_response(db, exam)


@router.patch("/{exam_id}/toggle", response_model=schemas.ExamSessionDetail)
def toggle_exam_status(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    exam.is_active = not bool(exam.is_active)
    db.commit()
    db.refresh(exam)
    return _detail_response(db, exam)


@router.get("/{exam_id}/attendance", response_model=schemas.AttendanceSummaryResponse)
def attendance_summary(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    _auto_complete(db, exam)
    attendance = _attendance_list(db, exam.id)
    return schemas.AttendanceSummaryResponse(
        exam_id=exam.id,
        title=exam.title,
        status=exam.status,
        duration_minutes=exam.duration_minutes or 60,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        total_attendees=len(attendance),
        active_attendees=sum(item.status in {"waiting", "active"} for item in attendance),
        completed_attendees=sum(item.status == "completed" for item in attendance),
        submission_count=db.query(models.Submission).filter(
            models.Submission.exam_session_id == exam.id
        ).count(),
        attendance_list=attendance,
    )
