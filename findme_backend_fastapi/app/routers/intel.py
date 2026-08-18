"""/news, /watch-topics -- ports 20260702120600_threat_intel.sql's news_items and
20260702120700_alerts_watchlist.sql's watch_topics."""
import uuid

from fastapi import APIRouter, status
from sqlalchemy import select

from app.core.errors import ForbiddenError, NotFoundError
from app.deps import CurrentUser, DbSession
from app.models.threat import NewsItem
from app.models.watch_topic import WatchTopic
from app.schemas.intel import NewsItemOut, WatchTopicCreate, WatchTopicOut
from app.services import authz

router = APIRouter(tags=["intel"])


@router.get("/news", response_model=list[NewsItemOut])
async def list_news(current_user: CurrentUser, db: DbSession, category: str | None = None, limit: int = 50) -> list[NewsItemOut]:
    query = select(NewsItem).order_by(NewsItem.published_at.desc()).limit(min(limit, 200))
    if category:
        query = query.where(NewsItem.category == category)
    rows = (await db.execute(query)).scalars().all()
    return [NewsItemOut.model_validate(n) for n in rows]


@router.get("/watch-topics", response_model=list[WatchTopicOut])
async def list_watch_topics(current_user: CurrentUser, db: DbSession) -> list[WatchTopicOut]:
    rows = (
        (await db.execute(select(WatchTopic).where(WatchTopic.owner_id == current_user.id)))
        .scalars()
        .all()
    )
    return [WatchTopicOut.model_validate(t) for t in rows]


@router.post("/watch-topics", response_model=WatchTopicOut, status_code=status.HTTP_201_CREATED)
async def add_watch_topic(payload: WatchTopicCreate, current_user: CurrentUser, db: DbSession) -> WatchTopicOut:
    authz.check_watch_topic_create_limit(current_user)
    topic = WatchTopic(
        id=uuid.uuid4(), owner_id=current_user.id, topic_type=payload.topic_type, value=payload.value
    )
    db.add(topic)
    await db.commit()
    await db.refresh(topic)
    return WatchTopicOut.model_validate(topic)


@router.delete("/watch-topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_watch_topic(topic_id: uuid.UUID, current_user: CurrentUser, db: DbSession) -> None:
    topic = await db.get(WatchTopic, topic_id)
    if topic is None:
        raise NotFoundError("Watch topic not found.")
    if topic.owner_id != current_user.id:
        raise ForbiddenError("Not your watch topic.")
    await db.delete(topic)
    await db.commit()
