"""
Expo push notifications -- replaces consent-notify/index.ts's sendExpoPush() +
geofence-evaluate's alert delivery. Both old Edge Functions were thin relays to the
same Expo push HTTP API this module calls directly; the only real change is that this
runs in-process right after the triggering write instead of via a Database Webhook
round trip.
"""
import logging
import uuid

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.device import Device

logger = logging.getLogger("findme.push")


async def _send_expo_push(tokens: list[str], title: str, body: str, data: dict) -> None:
    if not tokens:
        return
    settings = get_settings()
    messages = [
        {"to": token, "title": title, "body": body, "data": data, "sound": "default"} for token in tokens
    ]
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            await client.post(settings.expo_push_url, json=messages)
    except httpx.HTTPError as exc:
        # Same "log and continue" philosophy as the old consent-notify -- a push
        # delivery failure should never fail the write that triggered it.
        logger.error("Expo push delivery failed: %s", exc)


async def notify_user(db: AsyncSession, user_id: uuid.UUID, title: str, body: str, data: dict) -> None:
    tokens = (
        await db.execute(
            select(Device.push_token).where(Device.owner_id == user_id, Device.push_token.is_not(None))
        )
    ).scalars().all()
    await _send_expo_push([t for t in tokens if t], title, body, data)
