from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from app.core.config import settings
from app.db.session import get_db
from app.models.user import User

bearer = HTTPBearer()

def current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = jwt.decode(credentials.credentials, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        user_id = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="Usuário não encontrado")
    return user


def active_mentee_or_mentor(user: User = Depends(current_user)):
    if getattr(user, "role", "mentee") in {"mentor", "admin"}:
        return user
    if getattr(user, "approval_status", "pending_approval") != "active":
        raise HTTPException(status_code=403, detail="Aguardando aprovação da mentora")
    return user
