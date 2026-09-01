import os
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app import models, schemas, security
from app.database import get_db


router = APIRouter(prefix="/api/camera", tags=["Camera Monitoring"])

CAMERA_ROOT = Path(os.getenv(
    "KASIM_CAMERA_ROOT",
    str(Path(__file__).resolve().parents[2] / "camera_frames"),
)).resolve()
MAX_FRAME_BYTES = int(os.getenv("KASIM_MAX_CAMERA_FRAME_BYTES", str(3 * 1024 * 1024)))


def _student_session(db: Session, session_id: str) -> models.StudentSession:
    item = db.query(models.StudentSession).filter(
        models.StudentSession.id == session_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Student session not found")
    return item


def _owned_exam(db: Session, exam_id: str, lecturer: models.User) -> models.ExamSession:
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == lecturer.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam session not found")
    return exam


@router.post("/{session_id}/status")
def update_camera_status(
    session_id: str,
    payload: schemas.CameraStatusRequest,
    db: Session = Depends(get_db),
):
    student_session = _student_session(db, session_id)
    if not student_session.exam_session.camera_required:
        student_session.camera_status = "not_required"
    else:
        student_session.camera_status = payload.status
    db.commit()
    return {"session_id": session_id, "camera_status": student_session.camera_status}


@router.post("/{session_id}/frame")
async def upload_camera_frame(
    session_id: str,
    frame: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    student_session = _student_session(db, session_id)
    if not student_session.exam_session.camera_required:
        raise HTTPException(status_code=403, detail="Camera monitoring is disabled for this exam")
    if frame.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=415, detail="Camera frame must be JPEG, PNG, or WebP")

    data = await frame.read(MAX_FRAME_BYTES + 1)
    await frame.close()
    if len(data) > MAX_FRAME_BYTES:
        raise HTTPException(status_code=413, detail="Camera frame is too large")
    if not data:
        raise HTTPException(status_code=422, detail="Camera frame is empty")

    extension = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[frame.content_type]
    directory = CAMERA_ROOT / student_session.exam_session_id
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / f"{student_session.id}{extension}"
    old_path = Path(student_session.camera_frame_path) if student_session.camera_frame_path else None
    destination.write_bytes(data)
    if old_path and old_path != destination:
        old_path.unlink(missing_ok=True)

    student_session.camera_frame_path = str(destination)
    student_session.camera_frame_updated_at = models.utc_now()
    student_session.camera_status = "active"
    db.commit()
    return {
        "session_id": student_session.id,
        "camera_status": "active",
        "frame_updated_at": student_session.camera_frame_updated_at,
    }


@router.get("/exams/{exam_id}/feed", response_model=List[schemas.CameraFeedItem])
def camera_feed(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    return [
        schemas.CameraFeedItem(
            session_id=item.id,
            student_name=item.student_name,
            camera_status=item.camera_status or "not_required",
            frame_updated_at=item.camera_frame_updated_at,
            frame_available=bool(item.camera_frame_path and Path(item.camera_frame_path).is_file()),
        )
        for item in exam.student_sessions
    ]


@router.get("/sessions/{session_id}/frame")
def get_camera_frame(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    student_session = _student_session(db, session_id)
    _owned_exam(db, student_session.exam_session_id, current_user)
    if not student_session.camera_frame_path:
        raise HTTPException(status_code=404, detail="No camera frame is available")
    path = Path(student_session.camera_frame_path)
    if not path.is_file():
        raise HTTPException(status_code=410, detail="Camera frame is no longer available")
    media_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(path.suffix.lower(), "application/octet-stream")
    return FileResponse(path, media_type=media_type, headers={"Cache-Control": "no-store"})
