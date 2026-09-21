import uuid
from datetime import datetime, date
from sqlalchemy import String, Integer, ForeignKey, Text, DateTime, Date, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class PositioningSynthesis(Base):
    __tablename__ = "positioning_syntheses"
    __table_args__ = (UniqueConstraint("user_id", name="uq_positioning_synthesis_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True, unique=True)
    positioning_statement: Mapped[str] = mapped_column(Text, default="")
    authority_summary: Mapped[str] = mapped_column(Text, default="")
    values_summary: Mapped[str] = mapped_column(Text, default="")
    transformation_summary: Mapped[str] = mapped_column(Text, default="")
    strengths_json: Mapped[str] = mapped_column(Text, default="[]")
    gaps_json: Mapped[str] = mapped_column(Text, default="[]")
    next_actions_json: Mapped[str] = mapped_column(Text, default="[]")
    model_used: Mapped[str | None] = mapped_column(String(120), nullable=True)
    mode: Mapped[str] = mapped_column(String(30), default="openai")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ActionPlanItem(Base):
    __tablename__ = "action_plan_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    pillar_key: Mapped[str] = mapped_column(String(50), index=True)
    title: Mapped[str] = mapped_column(String(220))
    description: Mapped[str] = mapped_column(Text, default="")
    priority: Mapped[str] = mapped_column(String(20), default="medium")
    status: Mapped[str] = mapped_column(String(30), default="pending")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str] = mapped_column(Text, default="")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0)
    linked_session_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("mentor_sessions.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
