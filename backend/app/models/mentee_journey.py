import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, Boolean, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class MenteeCheckIn(Base):
    __tablename__ = 'mentee_checkins'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    progress: Mapped[str] = mapped_column(Text, default='')
    blockers: Mapped[str] = mapped_column(Text, default='')
    next_session_topic: Mapped[str] = mapped_column(Text, default='')
    confidence_level: Mapped[int] = mapped_column(Integer, default=3)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class MenteeNotification(Base):
    __tablename__ = 'mentee_notifications'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'), index=True)
    kind: Mapped[str] = mapped_column(String(40), default='info')
    title: Mapped[str] = mapped_column(String(180))
    message: Mapped[str] = mapped_column(Text, default='')
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
