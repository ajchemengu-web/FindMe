"""Pulls politics/business/markets/security headlines into news_items -- ports
ingest-news/index.ts exactly, including its category->Guardian-section approximation
and "one category failing shouldn't stop the others" behavior. Uses the Guardian Open
Platform because its free tier explicitly permits commercial/production use with
attribution, unlike e.g. NewsAPI.org's free tier."""
import logging

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.threat import NewsItem

logger = logging.getLogger("findme.ingest.news")

GUARDIAN_QUERIES: list[dict] = [
    {"category": "politics", "section": "politics"},
    {"category": "business", "section": "business"},
    {"category": "markets", "section": "business", "q": "markets OR shares OR stocks OR economy"},
    {"category": "security", "section": "world", "q": "security OR conflict OR military"},
]


async def _fetch_headlines() -> list[dict]:
    settings = get_settings()
    if not settings.news_api_key:
        logger.warning("NEWS_API_KEY not set -- returning zero headlines.")
        return []

    headlines: list[dict] = []
    async with httpx.AsyncClient(timeout=15) as client:
        for entry in GUARDIAN_QUERIES:
            params = {
                "api-key": settings.news_api_key,
                "section": entry["section"],
                "page-size": "5",
                "show-fields": "trailText",
                "order-by": "newest",
            }
            if "q" in entry:
                params["q"] = entry["q"]

            res = await client.get("https://content.guardianapis.com/search", params=params)
            if res.status_code != 200:
                logger.error("Guardian API request failed for %s: %s %s", entry["category"], res.status_code, res.text)
                continue

            for result in res.json().get("response", {}).get("results", []):
                headlines.append(
                    {
                        "source": "The Guardian",
                        "category": entry["category"],
                        "headline": result["webTitle"],
                        "summary": result.get("fields", {}).get("trailText"),
                        "url": result.get("webUrl"),
                        "published_at": result["webPublicationDate"],
                    }
                )
    return headlines


async def ingest_news(db: AsyncSession) -> dict:
    headlines = await _fetch_headlines()
    inserted = 0
    for h in headlines:
        # Guardian article URLs are naturally unique -- used as a soft de-dupe key via
        # a plain existence check rather than a DB unique constraint (news_items has
        # none, matching the original schema, which relied on url being incidental
        # rather than a declared uniqueness rule).
        from sqlalchemy import select

        existing = await db.scalar(select(NewsItem.id).where(NewsItem.url == h["url"]))
        if existing is not None:
            continue
        db.add(
            NewsItem(
                source=h["source"], category=h["category"], headline=h["headline"],
                summary=h.get("summary"), url=h.get("url"), sentiment=None, published_at=h["published_at"],
            )
        )
        inserted += 1
    await db.commit()
    return {"ok": True, "fetched": len(headlines), "inserted": inserted}
