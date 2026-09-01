from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import AuditViolation, ExamSession, User
from app.schemas import AuditViolationCreate, AuditViolationResponse
from app.security import get_current_user


router = APIRouter(prefix="/api/audit", tags=["Audit & Violations"])


@router.post("/violations", response_model=AuditViolationResponse, status_code=status.HTTP_201_CREATED)
def report_violation(
    violation_in: AuditViolationCreate,
    db: Session = Depends(get_db)
):
    """
    Ingests a security violation event dispatched from student desktop agent guards.
    """
    v = AuditViolation(
        exam_session_id=violation_in.exam_session_id,
        student_session_id=violation_in.student_session_id,
        student_name=violation_in.student_name,
        device_id=violation_in.device_id or "Windows Desktop Agent",
        violation_type=violation_in.violation_type,
        resource_name=violation_in.resource_name,
        action_taken=violation_in.action_taken,
        details=violation_in.details
    )
    db.add(v)
    db.commit()
    db.refresh(v)
    return v


@router.get("/violations/{exam_session_id}", response_model=List[AuditViolationResponse])
def get_exam_violations(
    exam_session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Fetches real-time audit log stream for an exam session.
    """
    if current_user.role != "lecturer":
        raise HTTPException(status_code=403, detail="Only lecturers can access audit logs")

    exam = db.query(ExamSession).filter(ExamSession.id == exam_session_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam session not found")
    if exam.lecturer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access audit logs for this exam")

    violations = db.query(AuditViolation).filter(
        AuditViolation.exam_session_id == exam_session_id
    ).order_by(AuditViolation.timestamp.desc()).all()

    return violations
