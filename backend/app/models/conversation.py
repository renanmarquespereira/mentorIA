import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, LargeBinary, Float, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class VoiceAnswer(Base):
    __tablename__ = 'voice_answers'
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    pillar_key: Mapped[str] = mapped_column(String(40), index=True)
    question_key: Mapped[str] = mapped_column(String(120))
    question_text: Mapped[str] = mapped_column(Text)
    audio: Mapped[bytes] = mapped_column(LargeBinary, deferred=True)
    byte_count: Mapped[int] = mapped_column(Integer)
    duration: Mapped[float] = mapped_column(Float)
    transcript: Mapped[str] = mapped_column(Text, default='')
    submitted_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    answer_key: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PlanConversation(Base):
    __tablename__ = 'plan_conversations'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    pillar_key: Mapped[str] = mapped_column(String(40), index=True)
    question: Mapped[str] = mapped_column(Text)
    reply: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
