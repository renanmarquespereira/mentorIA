import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, Text, DateTime, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class MentorMenteeIntelligence(Base):
    __tablename__ = "mentor_mentee_intelligence"
    __table_args__ = (UniqueConstraint("mentor_user_id", "mentee_user_id", name="uq_mentor_mentee_intelligence"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    mentor_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    mentee_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    brief_json: Mapped[str] = mapped_column(Text, default="")
    evolution_json: Mapped[str] = mapped_column(Text, default="")
    brief_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    evolution_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
