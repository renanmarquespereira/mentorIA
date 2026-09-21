import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class PillarReport(Base):
    __tablename__ = "pillar_reports"
    __table_args__ = (UniqueConstraint("user_id","pillar_key",name="uq_pillar_report_user_key"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    pillar_key: Mapped[str] = mapped_column(String(40), index=True)

    summary: Mapped[str] = mapped_column(Text, default="")
    perceived_authority: Mapped[str] = mapped_column(Text, default="")
    practical_plan_json: Mapped[str] = mapped_column(Text, default="[]")
    strengths_json: Mapped[str] = mapped_column(Text, default="[]")
    gaps_json: Mapped[str] = mapped_column(Text, default="[]")
    missing_information_json: Mapped[str] = mapped_column(Text, default="[]")
    completion_question: Mapped[str | None] = mapped_column(Text, nullable=True)
    ready_for_next: Mapped[str] = mapped_column(String(10), default="false")
    model_used: Mapped[str | None] = mapped_column(String(120), nullable=True)

    mentor_review_status: Mapped[str] = mapped_column(String(20), default="none")
    mentor_review_note: Mapped[str] = mapped_column(Text, default="")
    mentor_reviewed_by_user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    mentor_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
