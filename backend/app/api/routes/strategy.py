import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.strategy import PositioningSynthesis, ActionPlanItem
from app.schemas.strategy import ActionPlanStatusUpdate

router = APIRouter(prefix="/strategy", tags=["strategy"])

@router.get("/positioning")
def get_positioning_strategy(user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(PositioningSynthesis).where(PositioningSynthesis.user_id == user.id))
    if not row:
        raise HTTPException(status_code=404, detail="Síntese de posicionamento ainda não gerada")
    return {
        "positioning_statement": row.positioning_statement,
        "authority_summary": row.authority_summary,
        "values_summary": row.values_summary,
        "transformation_summary": row.transformation_summary,
        "strengths": json.loads(row.strengths_json or "[]"),
        "gaps": json.loads(row.gaps_json or "[]"),
        "next_actions": json.loads(row.next_actions_json or "[]"),
        "model_used": row.model_used,
        "mode": row.mode,
        "updated_at": row.updated_at,
    }

@router.get("/action-plan")
def get_action_plan(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id == user.id).order_by(ActionPlanItem.sort_order.asc())).all()
    return [{
        "id": row.id,
        "pillar_key": row.pillar_key,
        "title": row.title,
        "description": row.description,
        "priority": row.priority,
        "status": row.status,
        "sort_order": row.sort_order,
        "due_date": row.due_date,
        "notes": row.notes or "",
        "completed_at": row.completed_at,
        "progress_percent": row.progress_percent or 0,
    } for row in rows]

@router.patch("/action-plan/{item_id}")
def update_action_plan_item(item_id: str, data: ActionPlanStatusUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(ActionPlanItem).where(ActionPlanItem.id == item_id, ActionPlanItem.user_id == user.id))
    if not row:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada")
    changes = data.model_dump(exclude_unset=True)
    if "status" in changes and changes["status"] != row.status:
        row.completed_at = datetime.utcnow() if changes["status"] == "done" else None
        if changes["status"] == "done":
            changes["progress_percent"] = 100
        elif changes["status"] == "pending" and "progress_percent" not in changes:
            changes["progress_percent"] = 0
    if "progress_percent" in changes and "status" not in changes:
        if changes["progress_percent"] >= 100:
            changes["status"] = "done"; row.completed_at = datetime.utcnow()
        elif changes["progress_percent"] > 0 and row.status == "pending":
            changes["status"] = "in_progress"
    for key, value in changes.items():
        setattr(row, key, value)
    db.commit()
    return {"id": row.id, "status": row.status, "ok": True}
