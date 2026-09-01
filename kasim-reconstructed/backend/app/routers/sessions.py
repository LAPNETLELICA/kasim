from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import get_db
from app.policy_engine import create_signed_policy_payload


router = APIRouter(prefix="/api/sessions", tags=["Student Sessions"])


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def get_signed_policy_if_available(
    exam: models.ExamSession,
    db: Session,
) -> Optional[schemas.SignedPolicyPayload]:
    if not exam.policy_id:
        return None
    policy = db.query(models.AccessPolicy).filter(
        models.AccessPolicy.id == exam.policy_id
    ).first()
    if not policy:
        return None

    # The registry is dynamic and contains only resources entered by lecturers.
    # Sending the known registry lets the client identify and deny alternatives
    # without relying on a baked-in browser or AI list.
    browsers = db.query(models.BrowserResource).all()
    ai_services = db.query(models.AIResource).all()
    return create_signed_policy_payload(policy, browsers, ai_services)


def _student_response(
    exam: models.ExamSession,
    student_session: models.StudentSession,
    signed_policy: Optional[schemas.SignedPolicyPayload],
) -> schemas.StudentSessionResponse:
    return schemas.StudentSessionResponse(
        session_id=student_session.id,
        exam_id=exam.id,
        exam_title=exam.title,
        student_name=student_session.student_name,
        allowed_browser=exam.allowed_browser,
        allowed_ai=exam.allowed_ai,
        policy_mode=exam.policy_mode,
        camera_required=bool(exam.camera_required),
        submissions_enabled=bool(exam.submissions_enabled),
        policy_id=exam.policy_id,
        signed_policy=signed_policy,
        duration_minutes=exam.duration_minutes or 60,
        exam_status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        status=student_session.status,
        joined_at=ensure_utc(student_session.joined_at) or utc_now(),
    )


@router.post("/verify-code", response_model=schemas.LockdownRulesResponse)
def verify_exam_code(req: schemas.VerifyCodeRequest, db: Session = Depends(get_db)):
    code = req.exam_code.strip().upper()
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.exam_code == code
    ).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam code was not found")
    if exam.status == "completed" or not exam.is_active:
        raise HTTPException(status_code=410, detail="This exam session has ended")

    signed_policy = get_signed_policy_if_available(exam, db)
    return schemas.LockdownRulesResponse(
        valid=True,
        exam_id=exam.id,
        title=exam.title,
        allowed_browser=exam.allowed_browser,
        allowed_ai=exam.allowed_ai,
        policy_mode=exam.policy_mode,
        camera_required=bool(exam.camera_required),
        submissions_enabled=bool(exam.submissions_enabled),
        policy_id=exam.policy_id,
        signed_policy=signed_policy,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        is_active=bool(exam.is_active),
        message=(
            "Session is live. Lockdown begins after joining."
            if exam.status == "active"
            else "Code accepted. Join the waiting room."
        ),
    )


@router.post("/join", response_model=schemas.StudentSessionResponse)
def join_exam_session(req: schemas.StudentJoinRequest, db: Session = Depends(get_db)):
    code = req.exam_code.strip().upper()
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.exam_code == code
    ).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam code was not found")
    if exam.status == "completed" or not exam.is_active:
        raise HTTPException(status_code=410, detail="This exam session is closed")

    now = utc_now()
    student_name = req.student_name.strip()
    student_session = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.student_name.ilike(student_name),
        models.StudentSession.status.in_(["waiting", "active"]),
    ).first()
    if student_session:
        student_session.last_heartbeat = now
        student_session.device_info = req.device_info
    else:
        student_session = models.StudentSession(
            exam_session_id=exam.id,
            student_name=student_name,
            status="waiting" if exam.status == "waiting" else "active",
            device_info=req.device_info,
            browser_compliant=True,
            last_heartbeat=now,
            camera_status="pending" if exam.camera_required else "not_required",
        )
        db.add(student_session)
    db.commit()
    db.refresh(student_session)
    return _student_response(
        exam,
        student_session,
        get_signed_policy_if_available(exam, db),
    )


@router.post("/heartbeat", response_model=schemas.HeartbeatResponse)
def session_heartbeat(req: schemas.HeartbeatRequest, db: Session = Depends(get_db)):
    student_session = db.query(models.StudentSession).filter(
        models.StudentSession.id == req.session_id
    ).first()
    if not student_session:
        raise HTTPException(status_code=404, detail="Student session not found")

    exam = student_session.exam_session
    now = utc_now()
    start_time = ensure_utc(exam.start_time)
    end_time = ensure_utc(exam.end_time)

    if req.violation_event:
        violation = req.violation_event
        db.add(models.AuditViolation(
            exam_session_id=exam.id,
            student_session_id=student_session.id,
            student_name=student_session.student_name,
            device_id=violation.device_id or "Kasim desktop client",
            violation_type=violation.violation_type,
            resource_name=violation.resource_name,
            action_taken=violation.action_taken,
            details=violation.details,
        ))

    is_allowed = True
    message = "Lockdown is active and the device is compliant."
    if req.current_running_browser and exam.policy and exam.policy.browser_mode != "ALLOW_ANY":
        expected = exam.allowed_browser.casefold()
        actual = req.current_running_browser.casefold()
        if expected not in actual and actual not in expected:
            is_allowed = False
            message = f"Browser blocked. This exam requires {exam.allowed_browser}."

    student_session.last_heartbeat = now
    student_session.browser_compliant = is_allowed
    signed_policy = get_signed_policy_if_available(exam, db)
    policy_version = signed_policy.version if signed_policy else 1

    if exam.status == "waiting":
        db.commit()
        return schemas.HeartbeatResponse(
            status=student_session.status,
            exam_status="waiting",
            is_exam_active=False,
            is_allowed=True,
            policy_version=policy_version,
            signed_policy=signed_policy,
            time_remaining_seconds=(exam.duration_minutes or 60) * 60,
            start_time=None,
            end_time=None,
            message="Waiting for the lecturer to launch the session.",
        )

    if exam.status == "active" and exam.is_active:
        if end_time and now >= end_time:
            exam.status = "completed"
            exam.is_active = False
        else:
            if student_session.status == "waiting":
                student_session.status = "active"
            db.commit()
            remaining = int((end_time - now).total_seconds()) if end_time else (exam.duration_minutes or 60) * 60
            return schemas.HeartbeatResponse(
                status=student_session.status,
                exam_status="active",
                is_exam_active=True,
                is_allowed=is_allowed,
                policy_version=policy_version,
                signed_policy=signed_policy,
                time_remaining_seconds=max(0, remaining),
                start_time=start_time,
                end_time=end_time,
                message=message,
            )

    student_session.status = "completed"
    student_session.completed_at = student_session.completed_at or now
    db.commit()
    return schemas.HeartbeatResponse(
        status="completed",
        exam_status="completed",
        is_exam_active=False,
        is_allowed=True,
        policy_version=policy_version,
        signed_policy=signed_policy,
        time_remaining_seconds=0,
        start_time=start_time,
        end_time=end_time,
        message="Exam session completed. Lockdown has been released.",
    )


@router.post("/leave")
def leave_exam_session(session_id: str, db: Session = Depends(get_db)):
    student_session = db.query(models.StudentSession).filter(
        models.StudentSession.id == session_id
    ).first()
    if not student_session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student session not found")
    student_session.status = "completed"
    student_session.completed_at = utc_now()
    db.commit()
    return {"message": "Student session completed successfully"}
