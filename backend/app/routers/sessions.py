from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas

router = APIRouter(prefix="/api/sessions", tags=["Student Exam Sessions"])


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


@router.post("/verify-code", response_model=schemas.LockdownRulesResponse)
def verify_exam_code(req: schemas.VerifyCodeRequest, db: Session = Depends(get_db)):
    exam = db.query(models.ExamSession).filter(models.ExamSession.exam_code == req.exam_code.strip().upper()).first()
    if not exam:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id="",
            title="",
            allowed_browser="",
            duration_minutes=60,
            status="invalid",
            start_time=None,
            end_time=None,
            is_active=False,
            message="Invalid Exam Code. Please check and try again."
        )
    
    if not exam.is_active:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            duration_minutes=exam.duration_minutes or 60,
            status=exam.status,
            start_time=ensure_utc(exam.start_time),
            end_time=ensure_utc(exam.end_time),
            is_active=False,
            message="This exam session has been deactivated by the lecturer."
        )
    
    if exam.status == "completed":
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            duration_minutes=exam.duration_minutes or 60,
            status="completed",
            start_time=ensure_utc(exam.start_time),
            end_time=ensure_utc(exam.end_time),
            is_active=False,
            message="Exam session has already ended."
        )
    
    if exam.status == "active":
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            duration_minutes=exam.duration_minutes or 60,
            status="active",
            start_time=ensure_utc(exam.start_time),
            end_time=ensure_utc(exam.end_time),
            is_active=True,
            message="Exam session has already started. New student entries are locked."
        )

    return schemas.LockdownRulesResponse(
        valid=True,
        exam_id=exam.id,
        title=exam.title,
        allowed_browser=exam.allowed_browser,
        duration_minutes=exam.duration_minutes or 60,
        status="waiting",
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        is_active=True,
        message="Exam code verified successfully. Ready to join waiting lobby."
    )


@router.post("/join", response_model=schemas.StudentSessionResponse)
def join_exam_session(
    req: schemas.StudentJoinRequest,
    db: Session = Depends(get_db),
):
    student_name = req.student_name.strip()
    if not student_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Student name is required")

    exam = db.query(models.ExamSession).filter(models.ExamSession.exam_code == req.exam_code.strip().upper()).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid exam code")
    
    if not exam.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Exam session is deactivated or unavailable"
        )
    
    now = utc_now()
    end_t = ensure_utc(exam.end_time)

    # Check auto-stop if active
    if exam.status == "active" and end_t and now >= end_t:
        exam.status = "completed"
        db.commit()

    if exam.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Exam session has already concluded"
        )

    # Check if student with this name already joined
    existing_session = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.student_name == student_name,
    ).first()

    if exam.status == "active" and not existing_session:
        # If exam is already started and this student didn't join beforehand, block entry
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Exam session has already started. Late entry is not permitted."
        )

    if existing_session:
        existing_session.last_heartbeat = now
        if existing_session.status == "waiting" and exam.status == "active":
            existing_session.status = "active"
        db.commit()
        return schemas.StudentSessionResponse(
            session_id=existing_session.id,
            exam_id=exam.id,
            exam_title=exam.title,
            student_name=existing_session.student_name,
            allowed_browser=exam.allowed_browser,
            duration_minutes=exam.duration_minutes or 60,
            exam_status=exam.status,
            start_time=ensure_utc(exam.start_time),
            end_time=ensure_utc(exam.end_time),
            status=existing_session.status,
            joined_at=ensure_utc(existing_session.joined_at) or now,
        )

    # Register new student in waiting state
    new_session = models.StudentSession(
        exam_session_id=exam.id,
        student_name=student_name,
        status="waiting" if exam.status == "waiting" else "active",
        device_info=req.device_info,
        browser_compliant=True,
        last_heartbeat=now,
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    return schemas.StudentSessionResponse(
        session_id=new_session.id,
        exam_id=exam.id,
        exam_title=exam.title,
        student_name=new_session.student_name,
        allowed_browser=exam.allowed_browser,
        duration_minutes=exam.duration_minutes or 60,
        exam_status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        status=new_session.status,
        joined_at=ensure_utc(new_session.joined_at) or now,
    )


@router.post("/heartbeat", response_model=schemas.HeartbeatResponse)
def session_heartbeat(req: schemas.HeartbeatRequest, db: Session = Depends(get_db)):
    session = db.query(models.StudentSession).filter(models.StudentSession.id == req.session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student session not found")
    
    exam = session.exam_session
    now = utc_now()
    end_t = ensure_utc(exam.end_time)
    start_t = ensure_utc(exam.start_time)
    
    # Check browser compliance if specified
    is_allowed = True
    message = "Lockdown active and compliant."
    if req.current_running_browser:
        target = exam.allowed_browser.lower()
        actual = req.current_running_browser.lower()
        if target not in actual and actual not in target:
            is_allowed = False
            message = f"Browser policy violation! Exam requires '{exam.allowed_browser}'."

    session.last_heartbeat = now
    session.browser_compliant = is_allowed

    # 1. Exam is in waiting lobby
    if exam.status == "waiting":
        db.commit()
        return schemas.HeartbeatResponse(
            status=session.status,
            exam_status="waiting",
            is_exam_active=False,
            is_allowed=True,
            time_remaining_seconds=(exam.duration_minutes or 60) * 60,
            start_time=None,
            end_time=None,
            message="Waiting in lobby for lecturer to start session."
        )

    # 2. Exam is active: check expiration
    if exam.status == "active":
        if end_t and now >= end_t:
            exam.status = "completed"
            session.status = "completed"
            db.commit()
            return schemas.HeartbeatResponse(
                status="completed",
                exam_status="completed",
                is_exam_active=False,
                is_allowed=True,
                time_remaining_seconds=0,
                start_time=start_t,
                end_time=end_t,
                message="Exam duration has ended. Lockdown automatically released."
            )
        
        if not exam.is_active:
            session.status = "completed"
            db.commit()
            return schemas.HeartbeatResponse(
                status="completed",
                exam_status="completed",
                is_exam_active=False,
                is_allowed=True,
                time_remaining_seconds=0,
                start_time=start_t,
                end_time=end_t,
                message="Exam session paused or closed by lecturer."
            )

        if session.status == "waiting":
            session.status = "active"

        db.commit()
        time_remaining = int((end_t - now).total_seconds()) if end_t else (exam.duration_minutes or 60) * 60

        return schemas.HeartbeatResponse(
            status=session.status,
            exam_status="active",
            is_exam_active=True,
            is_allowed=is_allowed,
            time_remaining_seconds=max(0, time_remaining),
            start_time=start_t,
            end_time=end_t,
            message=message
        )

    # 3. Exam is completed
    session.status = "completed"
    db.commit()
    return schemas.HeartbeatResponse(
        status="completed",
        exam_status="completed",
        is_exam_active=False,
        is_allowed=True,
        time_remaining_seconds=0,
        start_time=start_t,
        end_time=end_t,
        message="Exam session has completed. Lockdown released."
    )


@router.post("/leave")
def leave_exam_session(session_id: str, db: Session = Depends(get_db)):
    session = db.query(models.StudentSession).filter(models.StudentSession.id == session_id).first()
    if session:
        session.status = "completed"
        db.commit()
    return {"message": "Session completed successfully"}
