from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse
from app.core.security import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=TokenResponse)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.email == data.email.lower()))
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado")
    user = User(name=data.name, phone=data.phone.strip(), email=data.email.lower(), password_hash=hash_password(data.password), role="mentee", approval_status="pending_approval")
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id), user={"id": user.id, "name": user.name, "email": user.email, "role": getattr(user, "role", "mentee"), "approval_status": getattr(user, "approval_status", "pending_approval")})

@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="E-mail ou senha inválidos")
    return TokenResponse(access_token=create_access_token(user.id), user={"id": user.id, "name": user.name, "email": user.email, "role": getattr(user, "role", "mentee"), "approval_status": getattr(user, "approval_status", "pending_approval")})
