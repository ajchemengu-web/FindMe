"""Pulls conflict/unrest/disaster events into threat_zones -- ports
ingest-conflict-events/index.ts, including the TODO left unfinished in the original:
fetchEvents() is a safe no-op until ACLED_API_KEY is set and a real client is wired up
(ACLED requires registration: https://acleddata.com/data-export-tool/; GDELT's
GKG/Events CSV format has no simple JSON endpoint and needs its own parser -- neither
was in scope for this rewrite, which focused on infrastructure parity, not adding new
data-source integrations that didn't exist before)."""
import logging

from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.threat import ThreatZone

logger = logging.getLogger("findme.ingest.conflict")


async def _fetch_events() -> list[dict]:
    settings = get_settings()
    if not settings.acled_api_key:
        logger.warning("ACLED_API_KEY not set -- returning zero events.")
        return []
    # TODO: real fetch() against ACLED's /acled/read endpoint, mapped into the same
    # dict shape ingest_conflict_events() below expects. Left unimplemented, same as
    # the Supabase original -- see this module's docstring.
    return []


async def ingest_conflict_events(db: AsyncSession) -> dict:
    events = await _fetch_events()
    upserted = 0
    for e in events:
        stmt = (
            pg_insert(ThreatZone)
            .values(
                external_id=e["external_id"], source=e["source"], category=e["category"],
                severity=e["severity"], title=e["title"], summary=e.get("summary"),
                location=from_shape(Point(e["lon"], e["lat"]), srid=4326),
                radius_km=e.get("radius_km"), event_date=e.get("event_date"), raw=e.get("raw", {}),
            )
            .on_conflict_do_update(
                index_elements=["source", "external_id"],
                set_={
                    "category": e["category"], "severity": e["severity"], "title": e["title"],
                    "summary": e.get("summary"), "location": from_shape(Point(e["lon"], e["lat"]), srid=4326),
                    "radius_km": e.get("radius_km"), "event_date": e.get("event_date"), "raw": e.get("raw", {}),
                },
            )
        )
        await db.execute(stmt)
        upserted += 1
    await db.commit()
    return {"ok": True, "fetched": len(events), "upserted": upserted}
