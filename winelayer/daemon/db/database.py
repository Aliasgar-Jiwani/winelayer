"""
WineLayer Database — SQLite connection and session management.

Uses SQLAlchemy async engine with aiosqlite for non-blocking database operations.
Tables are auto-created on first run (no Alembic migrations needed for Phase 1).
"""

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from daemon.config import config


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""
    pass


# Engine and session factory — initialized lazily
_engine = None
_session_factory = None


async def init_db() -> None:
    """
    Initialize the database engine and create all tables.
    Call this once on daemon startup.
    """
    global _engine, _session_factory

    config.ensure_directories()

    _engine = create_async_engine(
        config.db_url,
        echo=False,
        pool_pre_ping=True,
    )
    _session_factory = async_sessionmaker(
        _engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    # Import models so they register with Base.metadata
    from daemon.db import models  # noqa: F401

    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


from contextlib import asynccontextmanager


@asynccontextmanager
async def get_session():
    """Get a new async database session as a context manager."""
    if _session_factory is None:
        await init_db()
    async with _session_factory() as session:
        yield session


async def close_db() -> None:
    """Close the database engine. Call on daemon shutdown."""
    global _engine, _session_factory
    if _engine:
        await _engine.dispose()
        _engine = None
        _session_factory = None
