import uuid
from datetime import datetime
from sqlalchemy import String, Integer, ForeignKey, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class DiagnosisAIAnalysis(Base):
    __tablename__ = "diagnosis_ai_analyses"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    pillar_key: Mapped[str] = mapped_column(String(50), index=True)
    question_key: Mapped[str] = mapped_column(String(120), index=True)
    quality_score: Mapped[int] = mapped_column(Integer, default=0)
    decision: Mapped[str] = mapped_column(String(50), default="needs_review")
    feedback: Mapped[str] = mapped_column(Text, default="")
    follow_up_question: Mapped[str | None] = mapped_column(Text, nullable=True)
    extracted_facts_json: Mapped[str] = mapped_column(Text, default="[]")
    risks_json: Mapped[str] = mapped_column(Text, default="[]")
    model_used: Mapped[str | None] = mapped_column(String(120), nullable=True)
    mode: Mapped[str] = mapped_column(String(30), default="fallback")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
