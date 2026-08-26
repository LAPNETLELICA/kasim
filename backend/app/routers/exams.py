import random
import string
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/exams", tags=["Exam Management"])


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def generate_unique_exam_code(db: Session) -> str:
    """Generate a unique 6-character uppercase alphanumeric exam code."""
    chars = string.ascii_uppercase + string.digits
    for _ in range(100):
        code = "".join(random.choices(chars, k=6))
        existing = db.query(models.ExamSession).filter(models.ExamSession.exam_code == code).first()
        if not existing:
            return code
    raise RuntimeError("Could not generate a unique exam code after multiple attempts")


def _get_attendance_list(db: Session, exam_id: str) -> List[schemas.StudentAttendanceItem]:
    sessions = (
        db.query(models.StudentSession)
        .filter(models.StudentSession.exam_session_id == exam_id)
        .order_by(models.StudentSession.joined_at.asc())
        .all()
    )
    return [
        schemas.StudentAttendanceItem(
            session_id=s.id,
            student_name=s.student_name,
            joined_at=ensure_utc(s.joined_at) or utc_now(),
            status=s.status,
            device_info=s.device_info,
            browser_compliant=s.browser_compliant if hasattr(s, 'browser_compliant') and s.browser_compliant is not None else True,
            last_heartbeat=ensure_utc(s.last_heartbeat) or utc_now(),
        )
        for s in sessions
    ]


@router.post("/", response_model=schemas.ExamSessionResponse, status_code=status.HTTP_201_CREATED)
def create_exam_session(
    exam_in: schemas.ExamSessionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    unique_code = generate_unique_exam_code(db)

    allowed_browser_val = exam_in.allowed_browser or "Google Chrome"
    policy_id_val = exam_in.policy_id

    # If no policy_id provided, auto-create a signed AccessPolicy for this exam session
    if not policy_id_val:
        # Check or register browser resource
        b_res = db.query(models.BrowserResource).filter(
            models.BrowserResource.name.ilike(allowed_browser_val)
        ).first()
        if not b_res:
            exe = f"{allowed_browser_val.lower().replace(' ', '')}.exe"
            b_res = models.BrowserResource(
                id=f"browser_{models.uuid.uuid4().hex[:8]}",
                name=allowed_browser_val,
                executables=models.json.dumps([exe, allowed_browser_val.lower()]),
                description=f"Auto registered browser for exam {exam_in.title}",
                is_custom=True
            )
            db.add(b_res)
            db.commit()
            db.refresh(b_res)

        from app.policy_engine import create_signed_policy
        auto_policy = create_signed_policy(
            db=db,
            title=f"Policy for {exam_in.title}",
            description=f"Auto-generated default-deny policy for exam session",
            browser_mode="ALLOW_SELECTED",
            ai_mode="ALLOW_SELECTED",
            desktop_app_mode="BLOCK_ALL_UNAUTHORIZED",
            allowed_browsers=[b_res.id],
            allowed_ai=[],
            browser_ai_matrix={b_res.id: []},
            allowed_desktop_apps=[]
        )
        policy_id_val = auto_policy.id

    exam = models.ExamSession(
        title=exam_in.title,
        duration_minutes=exam_in.duration_minutes,
        status="waiting",
        start_time=None,
        end_time=None,
        allowed_browser=allowed_browser_val,
        policy_id=policy_id_val,
        exam_code=unique_code,
        is_active=True,
        lecturer_id=current_user.id,
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)


    return schemas.ExamSessionResponse(
        id=exam.id,
        title=exam.title,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        allowed_browser=exam.allowed_browser,
        policy_id=exam.policy_id,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=ensure_utc(exam.created_at) or utc_now(),
    )



@router.get("/", response_model=List[schemas.ExamSessionDetail])
def list_lecturer_exams(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exams = (
        db.query(models.ExamSession)
        .filter(models.ExamSession.lecturer_id == current_user.id)
        .order_by(models.ExamSession.created_at.desc())
        .all()
    )
    results = []
    now = utc_now()
    for exam in exams:
        # Check auto-stop
        end_t = ensure_utc(exam.end_time)
        if exam.status == "active" and end_t and now >= end_t:
            exam.status = "completed"
            db.query(models.StudentSession).filter(
                models.StudentSession.exam_session_id == exam.id,
                models.StudentSession.status == "active",
            ).update({"status": "completed"})
            db.commit()

        active_count = db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id,
            models.StudentSession.status.in_(["waiting", "active"]),
        ).count()
        total_count = db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id
        ).count()
        attendance = _get_attendance_list(db, exam.id)
        
        results.append(
            schemas.ExamSessionDetail(
                id=exam.id,
                title=exam.title,
                duration_minutes=exam.duration_minutes or 60,
                status=exam.status,
                start_time=ensure_utc(exam.start_time),
                end_time=ensure_utc(exam.end_time),
                allowed_browser=exam.allowed_browser,
                exam_code=exam.exam_code,
                is_active=exam.is_active,
                lecturer_id=exam.lecturer_id,
                created_at=ensure_utc(exam.created_at) or utc_now(),
                active_students_count=active_count,
                total_joined_count=total_count,
                attendance=attendance,
            )
        )
    return results


@router.get("/{exam_id}", response_model=schemas.ExamSessionDetail)
def get_exam_detail(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    exam = db.query(models.ExamSession).filter(models.ExamSession.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    # Auto-stop check on inspection if exam is active and end_time has passed
    now = utc_now()
    end_t = ensure_utc(exam.end_time)
    if exam.status == "active" and end_t and now >= end_t:
        exam.status = "completed"
        db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id,
            models.StudentSession.status == "active",
        ).update({"status": "completed"})
        db.commit()
        db.refresh(exam)
    
    active_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.status.in_(["waiting", "active"]),
    ).count()
    total_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id
    ).count()
    attendance = _get_attendance_list(db, exam.id)

    return schemas.ExamSessionDetail(
        id=exam.id,
        title=exam.title,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        allowed_browser=exam.allowed_browser,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=ensure_utc(exam.created_at) or utc_now(),
        active_students_count=active_count,
        total_joined_count=total_count,
        attendance=attendance,
    )


@router.post("/{exam_id}/start", response_model=schemas.ExamSessionDetail)
def start_exam_session(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == current_user.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    if exam.status == "completed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot start an already completed exam session.")
    
    now = utc_now()
    duration = exam.duration_minutes or 60
    exam.status = "active"
    exam.start_time = now
    exam.end_time = now + timedelta(minutes=duration)
    exam.is_active = True

    # Transition any waiting students to active
    db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.status == "waiting",
    ).update({"status": "active"})

    db.commit()
    db.refresh(exam)

    active_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.status == "active",
    ).count()
    total_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id
    ).count()
    attendance = _get_attendance_list(db, exam.id)

    return schemas.ExamSessionDetail(
        id=exam.id,
        title=exam.title,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        allowed_browser=exam.allowed_browser,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=ensure_utc(exam.created_at) or utc_now(),
        active_students_count=active_count,
        total_joined_count=total_count,
        attendance=attendance,
    )


@router.post("/{exam_id}/stop", response_model=schemas.ExamSessionDetail)
def stop_exam_session(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == current_user.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    exam.status = "completed"
    exam.end_time = utc_now()
    
    # Mark all student sessions as completed
    db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.status.in_(["waiting", "active"]),
    ).update({"status": "completed"})

    db.commit()
    db.refresh(exam)

    active_count = 0
    total_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id
    ).count()
    attendance = _get_attendance_list(db, exam.id)

    return schemas.ExamSessionDetail(
        id=exam.id,
        title=exam.title,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        allowed_browser=exam.allowed_browser,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=ensure_utc(exam.created_at) or utc_now(),
        active_students_count=active_count,
        total_joined_count=total_count,
        attendance=attendance,
    )


@router.get("/{exam_id}/attendance", response_model=schemas.AttendanceSummaryResponse)
def get_exam_attendance_report(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == current_user.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    attendance = _get_attendance_list(db, exam.id)
    active_attendees = sum(1 for a in attendance if a.status in ["waiting", "active"])
    completed_attendees = sum(1 for a in attendance if a.status == "completed")

    return schemas.AttendanceSummaryResponse(
        exam_id=exam.id,
        title=exam.title,
        status=exam.status,
        duration_minutes=exam.duration_minutes or 60,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        total_attendees=len(attendance),
        active_attendees=active_attendees,
        completed_attendees=completed_attendees,
        attendance_list=attendance,
    )


@router.patch("/{exam_id}/toggle", response_model=schemas.ExamSessionResponse)
def toggle_exam_active(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == current_user.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    exam.is_active = not exam.is_active
    db.commit()
    db.refresh(exam)
    return schemas.ExamSessionResponse(
        id=exam.id,
        title=exam.title,
        duration_minutes=exam.duration_minutes or 60,
        status=exam.status,
        start_time=ensure_utc(exam.start_time),
        end_time=ensure_utc(exam.end_time),
        allowed_browser=exam.allowed_browser,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=ensure_utc(exam.created_at) or utc_now(),
    )
