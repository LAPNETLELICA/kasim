from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/sessions", tags=["Student Exam Sessions"])


@router.post("/verify-code", response_model=schemas.LockdownRulesResponse)
def verify_exam_code(req: schemas.VerifyCodeRequest, db: Session = Depends(get_db)):
    exam = db.query(models.ExamSession).filter(models.ExamSession.exam_code == req.exam_code.upper()).first()
    if not exam:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id="",
            title="",
            allowed_browser="",
            start_time=datetime.utcnow(),
            end_time=datetime.utcnow(),
            is_active=False,
            message="Invalid Exam Code. Please check and try again."
        )
    
    now = datetime.utcnow()
    if not exam.is_active:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            start_time=exam.start_time,
            end_time=exam.end_time,
            is_active=False,
            message="This exam session has been deactivated by the lecturer."
        )
    
    if now < exam.start_time:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            start_time=exam.start_time,
            end_time=exam.end_time,
            is_active=True,
            message=f"Exam has not started yet. Scheduled start: {exam.start_time.isoformat()} UTC"
        )
        
    if now > exam.end_time:
        return schemas.LockdownRulesResponse(
            valid=False,
            exam_id=exam.id,
            title=exam.title,
            allowed_browser=exam.allowed_browser,
            start_time=exam.start_time,
            end_time=exam.end_time,
            is_active=False,
            message="Exam time window has expired."
        )

    return schemas.LockdownRulesResponse(
        valid=True,
        exam_id=exam.id,
        title=exam.title,
        allowed_browser=exam.allowed_browser,
        start_time=exam.start_time,
        end_time=exam.end_time,
        is_active=True,
        message="Exam code verified successfully. Lockdown rules active."
    )


@router.post("/join", response_model=schemas.StudentSessionResponse)
def join_exam_session(
    req: schemas.StudentJoinRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    exam = db.query(models.ExamSession).filter(models.ExamSession.exam_code == req.exam_code.upper()).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid exam code")
    
    now = datetime.utcnow()
    if not exam.is_active or now < exam.start_time or now > exam.end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Exam session is not currently active or available"
        )
    
    # Check if student already joined
    existing_session = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.student_id == current_user.id,
        models.StudentSession.status == "active"
    ).first()

    if existing_session:
        existing_session.last_heartbeat = now
        db.commit()
        return schemas.StudentSessionResponse(
            session_id=existing_session.id,
            exam_id=exam.id,
            exam_title=exam.title,
            allowed_browser=exam.allowed_browser,
            start_time=exam.start_time,
            end_time=exam.end_time,
            status=existing_session.status,
            joined_at=existing_session.joined_at
        )

    new_session = models.StudentSession(
        exam_session_id=exam.id,
        student_id=current_user.id,
        status="active",
        device_info=req.device_info,
        last_heartbeat=now
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    return schemas.StudentSessionResponse(
        session_id=new_session.id,
        exam_id=exam.id,
        exam_title=exam.title,
        allowed_browser=exam.allowed_browser,
        start_time=exam.start_time,
        end_time=exam.end_time,
        status=new_session.status,
        joined_at=new_session.joined_at
    )


@router.post("/heartbeat", response_model=schemas.HeartbeatResponse)
def session_heartbeat(req: schemas.HeartbeatRequest, db: Session = Depends(get_db)):
    session = db.query(models.StudentSession).filter(models.StudentSession.id == req.session_id).first()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student session not found")
    
    exam = session.exam_session
    now = datetime.utcnow()
    
    # Update heartbeat time
    session.last_heartbeat = now
    db.commit()

    # Check auto-expiration
    if now >= exam.end_time or not exam.is_active:
        session.status = "completed"
        db.commit()
        return schemas.HeartbeatResponse(
            status="completed",
            is_exam_active=False,
            is_allowed=True,
            time_remaining_seconds=0,
            message="Exam duration has ended. Lockdown automatically released."
        )

    time_remaining = int((exam.end_time - now).total_seconds())

    # Check browser compliance if specified
    is_allowed = True
    message = "Lockdown active and compliant."
    if req.current_running_browser:
        target = exam.allowed_browser.lower()
        actual = req.current_running_browser.lower()
        if target not in actual and actual not in target:
            is_allowed = False
            message = f"Browser policy violation! Exam requires '{exam.allowed_browser}'."

    return schemas.HeartbeatResponse(
        status=session.status,
        is_exam_active=True,
        is_allowed=is_allowed,
        time_remaining_seconds=time_remaining,
        message=message
    )


@router.post("/leave")
def leave_exam_session(session_id: str, db: Session = Depends(get_db)):
    session = db.query(models.StudentSession).filter(models.StudentSession.id == session_id).first()
    if session:
        session.status = "completed"
        db.commit()
    return {"message": "Session completed successfully"}
