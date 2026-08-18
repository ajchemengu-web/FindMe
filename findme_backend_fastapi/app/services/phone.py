"""Phone-number normalization -- ported verbatim from findme_app/lib/phone.ts so a
number typed slightly differently at sign-up vs sign-in still matches. See that file's
original comment for why this deliberately isn't full E.164 validation."""
import re


def normalize_phone(raw: str) -> str:
    return re.sub(r"[\s\-()]", "", raw)


def normalize_kenyan_msisdn(raw: str) -> str | None:
    """Ported from mpesa-stk-push/index.ts's normalizeKenyanMsisdn(). Accepts
    07XX..., 01XX..., +2547XX..., 2547XX... and normalizes to Safaricom's required
    2547XXXXXXXX / 2541XXXXXXXX form, or None if it doesn't look like a Kenyan MSISDN."""
    digits = re.sub(r"\D", "", raw)
    if digits.startswith("254") and len(digits) == 12:
        return digits
    if digits[:2] in ("07", "01") and len(digits) == 10:
        return "254" + digits[1:]
    if digits[:1] in ("7", "1") and len(digits) == 9:
        return "254" + digits
    return None
