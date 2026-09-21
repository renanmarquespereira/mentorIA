from fastapi import APIRouter, Depends
from app.api.deps import current_user
from app.models.user import User
from app.core.config import settings
from app.ai.openai_service import is_configured
router=APIRouter(prefix="/ai",tags=["ai"])
@router.get("/status")
def status(user:User=Depends(current_user)):
    return {"enabled":settings.ai_enabled,"configured":is_configured(),"model":settings.openai_model,"provider":"openai"}
