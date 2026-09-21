import uuid
from sqlalchemy import String, Integer, Float, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base

class EducatorProfile(Base):
    __tablename__ = "educator_profiles"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    city_state: Mapped[str | None] = mapped_column(String(160), nullable=True)
    education: Mapped[str | None] = mapped_column(Text, nullable=True)
    experience_months: Mapped[int] = mapped_column(Integer, default=0)
    has_clients: Mapped[bool] = mapped_column(default=False)
    sells_mentoring: Mapped[bool] = mapped_column(default=False)
    has_professional_instagram: Mapped[bool] = mapped_column(default=False)
    active_clients: Mapped[int] = mapped_column(Integer, default=0)
    current_ticket: Mapped[float] = mapped_column(Float, default=0)
    monthly_revenue: Mapped[float] = mapped_column(Float, default=0)
    main_difficulty: Mapped[str | None] = mapped_column(Text, nullable=True)
    main_goal: Mapped[str | None] = mapped_column(Text, nullable=True)
    user = relationship("User", back_populates="educator_profile")

class PillarProgress(Base):
    __tablename__ = "pillar_progress"
    __table_args__ = (UniqueConstraint("user_id", "pillar_key"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    pillar_key: Mapped[str] = mapped_column(String(50))
    score: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(50), default="not_started")
    user = relationship("User", back_populates="pillar_progress")
