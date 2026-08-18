"""/alerts -- ports 20260702120700_alerts_watchlist.sql's alerts_select_own /
alerts_update_own_read_state. Rows are only ever written server-side (geofence_eval,
future threat-proximity checks) -- there is intentionally no POST here."""
import uuid

from fastapi import APIRouter
from sqlalchemy import select

from app.core.errors import ForbiddenError, NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.alert import Alert
from app.schemas.alert import AlertOut, AlertUpdate

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=list[AlertOut])
async def list_alerts(current_user: CurrentUser, db: DbSession, limit: int = 100) -> list[AlertOut]:
    rows = (
        (
            await db.execute(
                select(Alert)
                .where(Alert.owner_id == current_user.id)
                .order_by(Alert.created_at.desc())
                .limit(min(limit, 500))
            )
        )
        .scalars()
        .all()
    )
    return [AlertOut.model_validate(a) for a in rows]


@router.patch("/{alert_id}", response_model=AlertOut)
async def update_alert(alert_id: uuid.UUID, payload: AlertUpdate, current_user: CurrentUser, db: DbSession) -> AlertOut:
    alert = await db.get(Alert, alert_id)
    if alert is None:
        raise NotFoundError("Alert not found.")
    if alert.owner_id != current_user.id:
        raise ForbiddenError("Not your alert.")
    alert.read = payload.read
    await db.commit()
    await db.refresh(alert)
    return AlertOut.model_validate(alert)
