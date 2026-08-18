"""/ingest -- cron-secret-gated data ingestion. Replaces the ingest-news/
ingest-conflict-events Edge Functions (deployed --no-verify-jwt, gated by
assertCronSecret() -- same x-cron-secret header contract, now enforced by
app.deps.require_cron_secret). Point an external scheduler (cron, GitHub Actions, a
Render/Fly.io cron job -- anything that can POST with a header) at these on whatever
interval you want fresh headlines/threat data."""
from fastapi import APIRouter, Depends

from app.database import get_db
from app.deps import require_cron_secret
from app.services.conflict_ingest import ingest_conflict_events
from app.services.news_ingest import ingest_news

router = APIRouter(prefix="/ingest", tags=["ingest"], dependencies=[Depends(require_cron_secret)])


@router.post("/news")
async def run_news_ingest(db=Depends(get_db)) -> dict:
    return await ingest_news(db)


@router.post("/conflict-events")
async def run_conflict_ingest(db=Depends(get_db)) -> dict:
    return await ingest_conflict_events(db)
