"""
SQLAlchemy models -- the schema previously defined across findme_backend's 17 Supabase
SQL migrations, ported table-for-table. Row Level Security and triggers don't exist
here; every table comment below says which service-layer function
(app/services/authz.py, app/services/geofence_eval.py) now does that job instead.

Notable structural change: Supabase split identity across `auth.users` (email,
password hash, phone OTP state -- managed by Supabase Auth) and `public.profiles`
(everything product-specific). There is no separate managed auth layer here, so both
are merged into one `users` table.
"""
from app.models.alert import Alert
from app.models.consent import Consent, ConsentAuditLog
from app.models.device import Device
from app.models.geofence import Geofence, GeofenceEvent
from app.models.location import LocationPing
from app.models.mpesa import MpesaTransaction
from app.models.pending_invite import PendingInvite
from app.models.phone_otp import PhoneOtp
from app.models.referral import Referral, ReferralCommission
from app.models.refresh_token import RefreshToken
from app.models.threat import NewsItem, ThreatZone
from app.models.user import User
from app.models.watch_topic import WatchTopic

__all__ = [
    "Alert",
    "Consent",
    "ConsentAuditLog",
    "Device",
    "Geofence",
    "GeofenceEvent",
    "LocationPing",
    "MpesaTransaction",
    "PendingInvite",
    "PhoneOtp",
    "Referral",
    "ReferralCommission",
    "RefreshToken",
    "NewsItem",
    "ThreatZone",
    "User",
    "WatchTopic",
]
