import hashlib
import io
import os
import re
import uuid
import zipfile
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session

from app import models, schemas, security
from app.database import get_db


router = APIRouter(prefix="/api/submissions", tags=["Exam Submissions"])

UPLOAD_ROOT = Path(os.getenv(
    "KASIM_UPLOAD_ROOT",
    str(Path(__file__).resolve().parents[2] / "uploads"),
)).resolve()
MAX_UPLOAD_BYTES = int(os.getenv("KASIM_MAX_UPLOAD_BYTES", str(25 * 1024 * 1024)))
DEFAULT_EXTENSIONS = {
    ".pdf", ".doc", ".docx", ".odt", ".rtf", ".txt",
    ".xls", ".xlsx", ".csv", ".ppt", ".pptx",
    ".png", ".jpg", ".jpeg", ".zip",
    ".py", ".js", ".ts", ".java", ".c", ".cpp", ".html", ".css",
}


def _allowed_extensions() -> set[str]:
    configured = os.getenv("KASIM_ALLOWED_SUBMISSION_EXTENSIONS", "").strip()
    if not configured:
        return DEFAULT_EXTENSIONS
    return {
        value if value.startswith(".") else f".{value}"
        for value in (part.strip().lower() for part in configured.split(","))
        if value
    }


def _safe_component(value: str, fallback: str = "file") -> str:
    value = re.sub(r"[^A-Za-z0-9._ -]+", "-", value).strip(" .-")
    return value[:120] or fallback


def _submission_response(item: models.Submission) -> schemas.SubmissionResponse:
    return schemas.SubmissionResponse(
        id=item.id,
        exam_session_id=item.exam_session_id,
        student_session_id=item.student_session_id,
        student_name=item.student_name,
        original_name=item.original_name,
        mime_type=item.mime_type,
        size_bytes=item.size_bytes,
        sha256=item.sha256,
        uploaded_at=item.uploaded_at,
    )


def _owned_exam(db: Session, exam_id: str, lecturer: models.User) -> models.ExamSession:
    exam = db.query(models.ExamSession).filter(
        models.ExamSession.id == exam_id,
        models.ExamSession.lecturer_id == lecturer.id,
    ).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam session not found")
    return exam


@router.post("/{session_id}", response_model=schemas.SubmissionResponse, status_code=status.HTTP_201_CREATED)
async def upload_submission(
    session_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    student_session = db.query(models.StudentSession).filter(
        models.StudentSession.id == session_id
    ).first()
    if not student_session:
        raise HTTPException(status_code=404, detail="Student session not found")
    exam = student_session.exam_session
    if not exam.submissions_enabled:
        raise HTTPException(status_code=403, detail="File submissions are disabled for this exam")
    if exam.status == "completed" and student_session.status != "active":
        raise HTTPException(status_code=410, detail="This exam is no longer accepting submissions")

    original_name = _safe_component(file.filename or "submission")
    extension = Path(original_name).suffix.lower()
    if extension not in _allowed_extensions():
        raise HTTPException(
            status_code=415,
            detail=f"{extension or 'Files without an extension'} are not accepted for this exam",
        )

    destination_dir = UPLOAD_ROOT / exam.id / student_session.id
    destination_dir.mkdir(parents=True, exist_ok=True)
    stored_name = f"{uuid.uuid4().hex}{extension}"
    destination = destination_dir / stored_name
    digest = hashlib.sha256()
    size = 0
    try:
        with destination.open("wb") as output:
            while chunk := await file.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail=f"File exceeds the {MAX_UPLOAD_BYTES // (1024 * 1024)} MB limit",
                    )
                digest.update(chunk)
                output.write(chunk)
    except Exception:
        destination.unlink(missing_ok=True)
        raise
    finally:
        await file.close()

    submission = models.Submission(
        exam_session_id=exam.id,
        student_session_id=student_session.id,
        student_name=student_session.student_name,
        original_name=original_name,
        stored_name=stored_name,
        storage_path=str(destination),
        mime_type=file.content_type,
        size_bytes=size,
        sha256=digest.hexdigest(),
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return _submission_response(submission)


@router.get("/exams/{exam_id}", response_model=List[schemas.SubmissionResponse])
def list_submissions(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    _owned_exam(db, exam_id, current_user)
    submissions = db.query(models.Submission).filter(
        models.Submission.exam_session_id == exam_id
    ).order_by(models.Submission.uploaded_at.asc()).all()
    return [_submission_response(item) for item in submissions]


@router.get("/{submission_id}/download")
def download_submission(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    submission = db.query(models.Submission).filter(
        models.Submission.id == submission_id
    ).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    _owned_exam(db, submission.exam_session_id, current_user)
    path = Path(submission.storage_path)
    if not path.is_file():
        raise HTTPException(status_code=410, detail="Submission file is no longer available")
    return FileResponse(
        path,
        media_type=submission.mime_type or "application/octet-stream",
        filename=submission.original_name,
    )


@router.get("/exams/{exam_id}/download-zip")
def download_exam_zip(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.require_role("lecturer")),
):
    exam = _owned_exam(db, exam_id, current_user)
    submissions = db.query(models.Submission).filter(
        models.Submission.exam_session_id == exam_id
    ).order_by(models.Submission.student_name.asc(), models.Submission.uploaded_at.asc()).all()
    if not submissions:
        raise HTTPException(status_code=404, detail="No student documents have been uploaded yet")

    archive = io.BytesIO()
    used_names: set[str] = set()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as output_zip:
        for item in submissions:
            source = Path(item.storage_path)
            if not source.is_file():
                continue
            student_dir = _safe_component(item.student_name, "student")
            original = _safe_component(item.original_name, "submission")
            archive_name = f"{student_dir}/{original}"
            if archive_name in used_names:
                archive_name = f"{student_dir}/{item.id[:8]}-{original}"
            used_names.add(archive_name)
            output_zip.write(source, archive_name)
    archive.seek(0)

    session_date = (exam.created_at or models.utc_now()).strftime("%Y-%m-%d")
    filename = f"{_safe_component(exam.title, 'exam')}-{session_date}.zip"
    headers = {"Content-Disposition": f'attachment; filename="{filename}"'}
    return StreamingResponse(archive, media_type="application/zip", headers=headers)
