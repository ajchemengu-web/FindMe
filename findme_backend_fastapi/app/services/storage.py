"""
S3/MinIO-backed object storage -- replaces Supabase Storage's avatars/intel-photos
buckets (20260702120800_storage.sql). Bucket-level ACLs (avatars public-read,
intel-photos fully private) are set once at bucket-creation time
(docker-compose.yml's minio-init step / your real S3 bucket policy), not per-row like
Supabase's storage.objects policies -- the per-object "only the owner can write to
their own folder" rule is still enforced here, just at the application layer: every
key is built as `{user_id}/{filename}`, and the caller always supplies their own
authenticated user id, never a client-controlled path.
"""
import uuid

import boto3
from botocore.client import Config
from starlette.concurrency import run_in_threadpool

from app.config import get_settings


def _client():
    settings = get_settings()
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
        config=Config(signature_version="s3v4"),
    )


def _safe_filename(filename: str) -> str:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
    ext = "".join(c for c in ext if c.isalnum())[:8] or "bin"
    return f"{uuid.uuid4()}.{ext}"


async def upload_avatar(user_id: uuid.UUID, filename: str, content: bytes, content_type: str) -> str:
    """Public bucket -- returns the durable public URL, same as the old avatars bucket
    (avatar_public_read policy)."""
    settings = get_settings()
    key = f"{user_id}/{_safe_filename(filename)}"

    def _put():
        _client().put_object(
            Bucket=settings.s3_avatars_bucket, Key=key, Body=content, ContentType=content_type
        )

    await run_in_threadpool(_put)
    return f"{settings.s3_public_base_url.rstrip('/')}/{key}"


async def upload_intel_photo(user_id: uuid.UUID, filename: str, content: bytes, content_type: str) -> str:
    """Private bucket -- returns the object key, not a public URL; fetch it back via
    presigned_get_url(). Mirrors intel_photo_owner_all's uploader-only access."""
    settings = get_settings()
    key = f"{user_id}/{_safe_filename(filename)}"

    def _put():
        _client().put_object(
            Bucket=settings.s3_intel_photos_bucket, Key=key, Body=content, ContentType=content_type
        )

    await run_in_threadpool(_put)
    return key


async def presigned_get_url(bucket: str, key: str, expires_seconds: int = 3600) -> str:
    def _sign():
        return _client().generate_presigned_url(
            "get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=expires_seconds
        )

    return await run_in_threadpool(_sign)
