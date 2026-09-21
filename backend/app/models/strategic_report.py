import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class StrategicReport(Base):
    __tablename__ = "strategic_reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)

    executive_summary: Mapped[str] = mapped_column(Text, default="")
    stage_summary: Mapped[str] = mapped_column(Text, default="")
    strengths_json: Mapped[str] = mapped_column(Text, default="[]")
    gaps_json: Mapped[str] = mapped_column(Text, default="[]")
    priorities_json: Mapped[str] = mapped_column(Text, default="[]")
    positioning_summary: Mapped[str] = mapped_column(Text, default="")
    promise_summary: Mapped[str] = mapped_column(Text, default="")
    funnel_summary: Mapped[str] = mapped_column(Text, default="")
    closing_summary: Mapped[str] = mapped_column(Text, default="")
    recommendations_json: Mapped[str] = mapped_column(Text, default="[]")
    model_used: Mapped[str | None] = mapped_column(String(120), nullable=True)
    mode: Mapped[str] = mapped_column(String(30), default="openai")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
