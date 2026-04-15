"""
WineLayer Database Models

SQLAlchemy ORM models for tracking installed apps, Wine prefixes,
and installation logs.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    Text,
    ForeignKey,
    Enum as SAEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from daemon.db.database import Base


class AppStatus:
    """App lifecycle status constants."""
    PENDING = "pending"
    INSTALLING = "installing"
    INSTALLED = "installed"
    RUNNING = "running"
    ERROR = "error"
    UNINSTALLED = "uninstalled"


class App(Base):
    """
    Represents an installed Windows application managed by WineLayer.
    Each app gets its own isolated Wine prefix.
    """
    __tablename__ = "apps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    app_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    exe_path: Mapped[str] = mapped_column(Text, nullable=False)
    icon_path: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    architecture: Mapped[str] = mapped_column(String(10), default="win64")
    wine_version: Mapped[str] = mapped_column(String(50), default="stable")
    status: Mapped[str] = mapped_column(String(20), default=AppStatus.PENDING)
    install_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    execution_engine: Mapped[str] = mapped_column(String(20), default="wine")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    last_launched: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships — use selectin to eagerly load within async sessions
    prefix: Mapped[Optional["Prefix"]] = relationship(
        "Prefix", back_populates="app", uselist=False, cascade="all, delete-orphan",
        lazy="selectin",
    )
    install_logs: Mapped[list["InstallLog"]] = relationship(
        "InstallLog", back_populates="app", cascade="all, delete-orphan",
        lazy="selectin",
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "app_id": self.app_id,
            "display_name": self.display_name,
            "exe_path": self.exe_path,
            "icon_path": self.icon_path,
            "architecture": self.architecture,
            "wine_version": self.wine_version,
            "status": self.status,
            "install_source": self.install_source,
            "execution_engine": self.execution_engine,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_launched": self.last_launched.isoformat() if self.last_launched else None,
            "prefix_path": self.prefix.path if self.prefix else None,
        }


class Prefix(Base):
    """
    Represents an isolated Wine prefix (a mini Windows environment)
    associated with a specific app.
    """
    __tablename__ = "prefixes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    app_id: Mapped[str] = mapped_column(
        String(255), ForeignKey("apps.app_id", ondelete="CASCADE"), unique=True, nullable=False
    )
    path: Mapped[str] = mapped_column(Text, nullable=False)
    architecture: Mapped[str] = mapped_column(String(10), default="win64")
    wine_version: Mapped[str] = mapped_column(String(50), default="stable")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    app: Mapped["App"] = relationship("App", back_populates="prefix")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "app_id": self.app_id,
            "path": self.path,
            "architecture": self.architecture,
            "wine_version": self.wine_version,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class InstallLog(Base):
    """
    Records installation actions and their results for auditing and debugging.
    """
    __tablename__ = "install_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    app_id: Mapped[str] = mapped_column(
        String(255), ForeignKey("apps.app_id", ondelete="CASCADE"), nullable=False
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    result: Mapped[str] = mapped_column(String(20), default="pending")
    log_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    app: Mapped["App"] = relationship("App", back_populates="install_logs")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "app_id": self.app_id,
            "action": self.action,
            "result": self.result,
            "log_text": self.log_text,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
        }
