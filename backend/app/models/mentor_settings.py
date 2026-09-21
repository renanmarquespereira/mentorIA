import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class MentorSettings(Base):
    __tablename__ = "mentor_settings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    mentor_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)

    authority_strong_json: Mapped[str] = mapped_column(Text, default="[]")
    authority_weak_json: Mapped[str] = mapped_column(Text, default="[]")
    relevant_certifications_json: Mapped[str] = mapped_column(Text, default="[]")
    low_relevance_certifications_json: Mapped[str] = mapped_column(Text, default="[]")
    valued_experiences_json: Mapped[str] = mapped_column(Text, default="[]")
    recommended_strategies_json: Mapped[str] = mapped_column(Text, default="[]")
    avoided_strategies_json: Mapped[str] = mapped_column(Text, default="[]")
    tone_of_voice: Mapped[str] = mapped_column(Text, default="")
    ideal_client_profile: Mapped[str] = mapped_column(Text, default="")
    freeform_methodology_notes: Mapped[str] = mapped_column(Text, default="")
    pillar_rules_json: Mapped[str] = mapped_column(Text, default="{}")

    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
