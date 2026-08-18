"""
M-Pesa (Safaricom Daraja) STK Push -- ports mpesa-stk-push/index.ts and
mpesa-stk-callback/index.ts. This is the app's real payment path (Stripe was already
unused before this rewrite -- see the top-level README for why it wasn't carried
forward). Because STK Push has no equivalent of silently re-charging a saved card,
this isn't a true auto-renewing subscription -- it's a fixed-term pass: pay via STK
Push, get 30 days of Plus/Pro, pay again before it lapses.
"""
import base64
from datetime import datetime

import httpx

from app.config import get_settings

KES_PRICE: dict[str, int] = {"plus": 650, "pro": 1300}
PASS_DURATION_DAYS = 30
REFERRAL_COMMISSION_RATE = 0.4


class MpesaError(Exception):
    pass


def _daraja_timestamp() -> str:
    return datetime.now().strftime("%Y%m%d%H%M%S")


async def _get_access_token(base_url: str, consumer_key: str, consumer_secret: str) -> str:
    basic = base64.b64encode(f"{consumer_key}:{consumer_secret}".encode()).decode()
    async with httpx.AsyncClient(timeout=15) as client:
        res = await client.get(
            f"{base_url}/oauth/v1/generate?grant_type=client_credentials",
            headers={"Authorization": f"Basic {basic}"},
        )
    if res.status_code != 200:
        raise MpesaError(f"Daraja OAuth failed: {res.status_code} {res.text}")
    return res.json()["access_token"]


async def initiate_stk_push(tier: str, msisdn: str) -> dict:
    """Returns Daraja's raw response dict (CheckoutRequestID, MerchantRequestID, ...).
    Raises MpesaError on any failure -- callers should surface .args[0] to the client,
    same as the original's `throw new Error(...)` -> 500 response."""
    settings = get_settings()
    if not (
        settings.mpesa_consumer_key and settings.mpesa_consumer_secret
        and settings.mpesa_shortcode and settings.mpesa_passkey
    ):
        raise MpesaError(
            "MPESA_CONSUMER_KEY / MPESA_CONSUMER_SECRET / MPESA_SHORTCODE / MPESA_PASSKEY not configured."
        )

    amount = KES_PRICE[tier]
    timestamp = _daraja_timestamp()
    password = base64.b64encode(
        f"{settings.mpesa_shortcode}{settings.mpesa_passkey}{timestamp}".encode()
    ).decode()
    access_token = await _get_access_token(settings.mpesa_base_url, settings.mpesa_consumer_key, settings.mpesa_consumer_secret)

    callback_url = f"{settings.public_base_url}/billing/mpesa/callback"
    async with httpx.AsyncClient(timeout=20) as client:
        res = await client.post(
            f"{settings.mpesa_base_url}/mpesa/stkpush/v1/processrequest",
            headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
            json={
                "BusinessShortCode": settings.mpesa_shortcode,
                "Password": password,
                "Timestamp": timestamp,
                "TransactionType": "CustomerPayBillOnline",
                "Amount": amount,
                "PartyA": msisdn,
                "PartyB": settings.mpesa_shortcode,
                "PhoneNumber": msisdn,
                "CallBackURL": callback_url,
                "AccountReference": f"FindMe {tier}",
                "TransactionDesc": f"FindMe {'Plus' if tier == 'plus' else 'Pro'} -- 30 days",
            },
        )
    body = res.json()
    if res.status_code != 200 or not body.get("CheckoutRequestID"):
        raise MpesaError(
            f"Daraja STK Push failed: {body.get('errorMessage') or body.get('ResponseDescription') or body}"
        )
    return body
