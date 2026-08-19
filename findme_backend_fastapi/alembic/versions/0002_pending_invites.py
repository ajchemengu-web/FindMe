"""pending_invites -- invite-by-phone for the Add to Watch List "someone else" flow

Revision ID: 0002_pending_invites
Revises: 0001_initial
Create Date: 2026-08-19

New table, no Supabase-era equivalent: lets a consent request wait for its target to
sign up, instead of requiring them to already have an account (GET /auth/lookup could
only ever find existing users). See app/models/pending_invite.py and
app/services/invites.py.
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0002_pending_invites"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        create table pending_invites (
            id uuid primary key default gen_random_uuid(),
            inviter_id uuid not null references users(id) on delete cascade,
            contact_phone text not null,
            scope text not null default 'precise' check (scope in ('precise','city')),
            expires_at timestamptz not null,
            consumed_at timestamptz,
            created_at timestamptz not null default now()
        )
        """
    )
    op.execute("create index pending_invites_inviter_idx on pending_invites (inviter_id)")
    # signup()'s link_pending_invites() looks these up by phone, filtered to
    # unconsumed -- this is the lookup that needs to be fast.
    op.execute(
        "create index pending_invites_contact_unconsumed_idx on pending_invites (contact_phone) "
        "where consumed_at is null"
    )


def downgrade() -> None:
    op.execute("drop table if exists pending_invites")
