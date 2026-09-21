import json
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException
from app.core.config import settings
from sqlalchemy import select, delete
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.educator import PillarProgress
from app.models.diagnosis import DiagnosisAnswer

def require_dev_mode():
    if not settings.enable_dev_tools:
        raise HTTPException(403, "Ferramentas de desenvolvimento desativadas.")

router=APIRouter(prefix="/dev",tags=["dev"],dependencies=[Depends(require_dev_mode)])

@router.post("/restore-tested-state")
def restore_tested_state(user:User=Depends(current_user),db:Session=Depends(get_db)):
    data=json.loads((Path(__file__).parents[2]/"knowledge"/"restore_test_state.json").read_text(encoding="utf-8"))
    db.execute(delete(DiagnosisAnswer).where(DiagnosisAnswer.user_id==user.id))
    db.execute(delete(PillarProgress).where(PillarProgress.user_id==user.id))
    for pillar_key, answers in data.items():
        db.add(PillarProgress(user_id=user.id,pillar_key=pillar_key,score=100,status="validated"))
        for question_key, answer_text in answers.items():
            db.add(DiagnosisAnswer(user_id=user.id,pillar_key=pillar_key,question_key=question_key,
                                   answer_text=answer_text,score=10,status="answered_ai"))
    db.commit()
    return {"ok":True,"restored_for":user.email,"pillars_restored":list(data.keys()),
            "next_step":"POST /api/v1/strategy/generate-full"}


@router.post("/make-me-mentor")
def make_me_mentor(user: User = Depends(current_user), db: Session = Depends(get_db)):
    user.role = "mentor"
    user.approval_status = "active"
    db.commit()
    return {"ok": True, "role": user.role, "approval_status": user.approval_status}
