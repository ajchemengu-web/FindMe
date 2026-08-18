"""Unit tests for the parts of app/services/authz.py that don't need a database --
effective_plan_tier() and the synchronous plan-limit checks. The DB-dependent half
(visibility queries, consent transitions) is covered by tests/test_integration_flows.py
against a real Postgres+PostGIS, skipped automatically if one isn't reachable (see that
file's module-level skip condition)."""
from datetime import datetime, timedelta, timezone

import pytest

from app.core.errors import PlanLimitError
from app.models.user import User
from app.services.authz import check_geofence_create_limit, check_watch_topic_create_limit, effective_plan_tier


def _user(plan_tier: str, plan_renews_at=None) -> User:
    return User(
        email="x@example.com", hashed_password="x", username="x", referral_code="X",
        plan_tier=plan_tier, plan_renews_at=plan_renews_at,
    )


def test_effective_plan_tier_free_stays_free():
    assert effective_plan_tier(_user("free")) == "free"


def test_effective_plan_tier_paid_with_no_renewal_date_stays_paid():
    # Shouldn't happen in practice (a real M-Pesa payment always sets plan_renews_at),
    # but a plan with no expiry recorded should not be treated as lapsed.
    assert effective_plan_tier(_user("plus", None)) == "plus"


def test_effective_plan_tier_paid_but_lapsed_is_free():
    past = datetime.now(timezone.utc) - timedelta(days=1)
    assert effective_plan_tier(_user("pro", past)) == "free"


def test_effective_plan_tier_paid_still_active():
    future = datetime.now(timezone.utc) + timedelta(days=10)
    assert effective_plan_tier(_user("plus", future)) == "plus"


def test_geofence_plan_limit_blocks_free():
    with pytest.raises(PlanLimitError):
        check_geofence_create_limit(_user("free"))


def test_geofence_plan_limit_allows_paid():
    future = datetime.now(timezone.utc) + timedelta(days=10)
    check_geofence_create_limit(_user("plus", future))  # should not raise


def test_watch_topic_plan_limit_blocks_free():
    with pytest.raises(PlanLimitError):
        check_watch_topic_create_limit(_user("free"))
