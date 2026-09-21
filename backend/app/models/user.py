import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="mentee", index=True)
    approval_status: Mapped[str] = mapped_column(String(30), default="pending_approval", index=True)
    phone: Mapped[str] = mapped_column(String(40), default="", index=True)
    profile_photo: Mapped[str] = mapped_column(Text, default="")
    approved_by_user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    educator_profile = relationship("EducatorProfile", back_populates="user", uselist=False)
    pillar_progress = relationship("PillarProgress", back_populates="user")
