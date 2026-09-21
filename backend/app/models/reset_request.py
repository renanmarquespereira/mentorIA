import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class ResetRequest(Base):
    __tablename__ = 'reset_requests'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    mentee_user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    mentor_user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    reset_type: Mapped[str] = mapped_column(String(30))  # pillar_report | journey
    pillar_key: Mapped[str | None] = mapped_column(String(40), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default='pending', index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
