"""
/uploads -- ports 20260702120800_storage.sql's two buckets:
  - avatars: public, but a user may only write inside their own folder.
  - intel-photos: private, uploader-only -- the "uploaded photos" OSINT feature this
    project's PRD calls for (tracking a device/person via a photo someone uploads).
    This endpoint stores the raw file and hands back a time-limited signed URL for the
    uploader to view it; it does NOT do any image analysis -- see this project's README
    for what a real OSINT pipeline (EXIF extraction, reverse image search, etc.) on top
    of this would need.
"""
from fastapi import APIRouter, HTTPException, UploadFile, status

from app.deps import CurrentUser, DbSession
from app.schemas.upload import AvatarUploadOut, IntelPhotoUploadOut
from app.config import get_settings
from app.services import storage

router = APIRouter(prefix="/uploads", tags=["uploads"])

_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


async def _read_validated(file: UploadFile) -> bytes:
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Unsupported file type: {file.content_type}")
    content = await file.read()
    if len(content) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "File too large (max 10 MB).")
    return content


@router.post("/avatar", response_model=AvatarUploadOut)
async def upload_avatar(file: UploadFile, current_user: CurrentUser, db: DbSession) -> AvatarUploadOut:
    content = await _read_validated(file)
    url = await storage.upload_avatar(current_user.id, file.filename or "avatar", content, file.content_type)
    current_user.avatar_url = url
    await db.commit()
    return AvatarUploadOut(avatar_url=url)


@router.post("/intel-photo", response_model=IntelPhotoUploadOut)
async def upload_intel_photo(file: UploadFile, current_user: CurrentUser) -> IntelPhotoUploadOut:
    content = await _read_validated(file)
    key = await storage.upload_intel_photo(current_user.id, file.filename or "photo", content, file.content_type)
    settings = get_settings()
    view_url = await storage.presigned_get_url(settings.s3_intel_photos_bucket, key)
    return IntelPhotoUploadOut(object_key=key, view_url=view_url)
