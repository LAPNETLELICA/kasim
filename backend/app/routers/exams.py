import random
import string
from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/exams", tags=["Exam Management"])


def generate_unique_exam_code(db: Session) -> str:
    """Generate a unique 6-character uppercase alphanumeric exam code."""
    chars = string.ascii_uppercase + string.digits
    for _ in range(100):
        code = "".join(random.choices(chars, k=6))
        existing = db.query(models.ExamSession).filter(models.ExamSession.exam_code == code).first()
        if not existing:
            return code
    raise RuntimeError("Could not generate a unique exam code after multiple attempts")


@router.post("/", response_model=schemas.ExamSessionResponse, status_code=status.HTTP_201_CREATED)
def create_exam_session(
    exam_in: schemas.ExamSessionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer"))
):
    now = datetime.utcnow()
    start_time = exam_in.start_time or now
    if exam_in.duration_minutes and exam_in.duration_minutes > 0:
        end_time = start_time + timedelta(minutes=exam_in.duration_minutes)
    elif exam_in.end_time:
        end_time = exam_in.end_time
    else:
        end_time = start_time + timedelta(minutes=60)

    if start_time >= end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start time must be strictly earlier than end time"
        )
    
    unique_code = generate_unique_exam_code(db)
    
    exam = models.ExamSession(
        title=exam_in.title,
        start_time=start_time,
        end_time=end_time,
        allowed_browser=exam_in.allowed_browser,
        exam_code=unique_code,
        is_active=True,
        lecturer_id=current_user.id
    )
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return exam


@router.get("/", response_model=List[schemas.ExamSessionDetail])
def list_lecturer_exams(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer"))
):
    exams = db.query(models.ExamSession).filter(models.ExamSession.lecturer_id == current_user.id).all()
    results = []
    for exam in exams:
        active_count = db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id,
            models.StudentSession.status == "active"
        ).count()
        total_count = db.query(models.StudentSession).filter(
            models.StudentSession.exam_session_id == exam.id
        ).count()
        
        results.append(
            schemas.ExamSessionDetail(
                id=exam.id,
                title=exam.title,
                start_time=exam.start_time,
                end_time=exam.end_time,
                allowed_browser=exam.allowed_browser,
                exam_code=exam.exam_code,
                is_active=exam.is_active,
                lecturer_id=exam.lecturer_id,
                created_at=exam.created_at,
                active_students_count=active_count,
                total_joined_count=total_count
            )
        )
    return results


@router.get("/{exam_id}", response_model=schemas.ExamSessionDetail)
def get_exam_detail(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    exam = db.query(models.ExamSession).filter(models.ExamSession.id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    active_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id,
        models.StudentSession.status == "active"
    ).count()
    total_count = db.query(models.StudentSession).filter(
        models.StudentSession.exam_session_id == exam.id
    ).count()

    return schemas.ExamSessionDetail(
        id=exam.id,
        title=exam.title,
        start_time=exam.start_time,
        end_time=exam.end_time,
        allowed_browser=exam.allowed_browser,
        exam_code=exam.exam_code,
        is_active=exam.is_active,
        lecturer_id=exam.lecturer_id,
        created_at=exam.created_at,
        active_students_count=active_count,
        total_joined_count=total_count
    )


@router.patch("/{exam_id}/toggle", response_model=schemas.ExamSessionResponse)
def toggle_exam_active(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer"))
):
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == current_user.id
    ).first()
    if not exam:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam session not found")
    
    exam.is_active = not exam.is_active
    db.commit()
    db.refresh(exam)
    return exam
