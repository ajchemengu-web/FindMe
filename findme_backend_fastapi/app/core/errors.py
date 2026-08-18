"""
Domain exceptions + a single FastAPI exception handler (registered in app/main.py) that
turns them into the right HTTP status. This is what lets app/services/authz.py raise a
plain `PlanLimitError("Free plan is limited to 3 devices...")` -- the same message text
the old Postgres trigger's RAISE EXCEPTION produced -- and have it surface to the
client automatically, without every router repeating its own try/except.
"""


class AppError(Exception):
    status_code = 400

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)


class NotFoundError(AppError):
    status_code = 404


class ForbiddenError(AppError):
    status_code = 403


class PlanLimitError(AppError):
    """Mirrors the five plan-limit triggers from 20260702121300_billing.sql /
    20260702121500_free_tier_devices.sql / 20260702121600_mpesa_billing.sql. 402 Payment
    Required is the closest honest HTTP status for "this needs a paid plan"."""

    status_code = 402


class ConflictError(AppError):
    status_code = 409
