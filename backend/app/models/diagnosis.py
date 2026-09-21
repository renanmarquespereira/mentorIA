import uuid
from datetime import datetime
from sqlalchemy import String, Integer, ForeignKey, Text, DateTime, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class DiagnosisAnswer(Base):
    __tablename__ = "diagnosis_answers"
    __table_args__ = (UniqueConstraint("user_id", "pillar_key", "question_key"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    pillar_key: Mapped[str] = mapped_column(String(50), index=True)
    question_key: Mapped[str] = mapped_column(String(120), index=True)
    answer_text: Mapped[str] = mapped_column(Text)
    score: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(50), default="answered")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class DiagnosisSession(Base):
    __tablename__ = "diagnosis_sessions"
    __table_args__ = (UniqueConstraint("user_id", "pillar_key"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    pillar_key: Mapped[str] = mapped_column(String(50), index=True)
    current_question_key: Mapped[str | None] = mapped_column(String(120), nullable=True)
    completed_questions: Mapped[int] = mapped_column(Integer, default=0)
    total_questions: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(50), default="in_diagnosis")
