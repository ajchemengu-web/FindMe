"""
SMS delivery -- pluggable, because Supabase Auth used to own "which SMS provider is
configured" as a per-project Dashboard setting this service has no equivalent of.
Default is "console" (logs the code instead of sending anything -- fine for local dev,
required reading before switching SMS_PROVIDER=twilio in production). Add another
provider by implementing send_sms() and branching on settings.sms_provider.
"""
import logging

import httpx

from app.config import get_settings

logger = logging.getLogger("findme.sms")


async def send_sms(to: str, body: str) -> None:
    settings = get_settings()

    if settings.sms_provider == "console":
        logger.warning("SMS (console provider -- not actually sent) to %s: %s", to, body)
        return

    if settings.sms_provider == "twilio":
        if not (settings.twilio_account_sid and settings.twilio_auth_token and settings.twilio_from_number):
            raise RuntimeError(
                "SMS_PROVIDER=twilio but TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN/TWILIO_FROM_NUMBER "
                "are not fully set."
            )
        url = f"https://api.twilio.com/2010-04-01/Accounts/{settings.twilio_account_sid}/Messages.json"
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.post(
                url,
                data={"To": to, "From": settings.twilio_from_number, "Body": body},
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
            )
            res.raise_for_status()
        return

    raise RuntimeError(f"Unknown SMS_PROVIDER: {settings.sms_provider}")
