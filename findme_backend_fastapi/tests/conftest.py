"""
Shared pytest fixtures. Integration tests need a real PostgreSQL + PostGIS instance
(geography columns, ST_DWithin, etc. have no SQLite equivalent) -- point
FINDME_TEST_DATABASE_URL at one (e.g. the docker-compose `db` service) to run them.
Without it, every test in tests/test_integration_flows.py is skipped rather than
failing, so `pytest` still exits green in an environment with no database (such as the
sandbox this project was originally built in -- see the top-level README's
"Verification" section).
"""
import asyncio
import os

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app import models  # noqa: F401 -- populates Base.metadata

TEST_DATABASE_URL = os.environ.get("FINDME_TEST_DATABASE_URL", "")


def database_available() -> bool:
    return bool(TEST_DATABASE_URL)


@pytest_asyncio.fixture
async def db_session():
    if not database_available():
        pytest.skip(
            "FINDME_TEST_DATABASE_URL not set -- integration tests need a real "
            "Postgres+PostGIS instance (docker compose up db). See README."
        )

    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.execute(__import__("sqlalchemy").text("create extension if not exists postgis"))
        await conn.run_sync(Base.metadata.create_all)

    session_maker = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_maker() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()
