import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.pillar_report import PillarReport
from app.models.diagnosis import DiagnosisAnswer
from app.models.strategy import ActionPlanItem
from app.models.strategic_report import StrategicReport
from app.models.crm import Lead, Sale
from app.ai.strategy_service import generate_report, configured
from app.services.mentor_context import mentor_context_for_user

router = APIRouter(prefix="/strategy", tags=["strategy"])

PILLARS = ["positioning","promise","funnel","closing"]

def all_validated(db, user_id):
    rows = db.scalars(select(PillarReport).where(PillarReport.user_id == user_id)).all()
    status = {r.pillar_key: r.ready_for_next for r in rows}
    return all(status.get(key) == "true" for key in PILLARS)

def answers_by_pillar(db, user_id):
    rows = db.scalars(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id == user_id)).all()
    result = {key: {} for key in PILLARS}
    for r in rows:
        if r.pillar_key in result:
            result[r.pillar_key][r.question_key] = r.answer_text
    return result

def commercial_context(db, user_id):
    leads = db.scalar(select(func.count()).select_from(Lead).where(Lead.user_id == user_id)) or 0
    sales = db.scalar(select(func.count()).select_from(Sale).where(Sale.user_id == user_id)) or 0
    revenue = db.scalar(select(func.coalesce(func.sum(Sale.amount),0)).where(Sale.user_id == user_id)) or 0
    return {
        "registered_leads": leads,
        "registered_sales": sales,
        "registered_revenue": float(revenue)
    }

@router.post("/generate-full")
def generate_full_strategy(user: User = Depends(current_user), db: Session = Depends(get_db)):
    # Serialize generation per user, preserving an existing strategy and tasks.
    db.scalar(select(User).where(User.id == user.id).with_for_update())
    existing = db.scalar(select(StrategicReport).where(StrategicReport.user_id == user.id))
    if existing:
        return {"ok": True, "already_generated": True, "report": full_report(user, db)}
    if not all_validated(db, user.id):
        raise HTTPException(status_code=409, detail="Conclua e valide os quatro pilares antes de gerar a estratégia completa")
    if not configured():
        raise HTTPException(status_code=503, detail="IA não configurada")

    plans = db.scalars(select(PillarReport).where(PillarReport.user_id == user.id)).all()
    plan_context = {p.pillar_key: {
        "summary": p.summary,
        "perceived_authority": p.perceived_authority,
        "practical_plan": json.loads(p.practical_plan_json or "[]"),
        "strengths": json.loads(p.strengths_json or "[]"),
        "gaps": json.loads(p.gaps_json or "[]"),
        "mentor_review_note": p.mentor_review_note,
    } for p in plans}
    report = generate_report(
        answers_by_pillar(db, user.id),
        commercial_context(db, user.id),
        plan_context,
        mentor_context_for_user(db, getattr(user, "approved_by_user_id", None)),
    )

    row = db.scalar(select(StrategicReport).where(StrategicReport.user_id == user.id))
    if not row:
        row = StrategicReport(user_id=user.id)
        db.add(row)

    row.executive_summary = report["executive_summary"]
    row.stage_summary = report["stage_summary"]
    row.strengths_json = json.dumps(report["strengths"], ensure_ascii=False)
    row.gaps_json = json.dumps(report["gaps"], ensure_ascii=False)
    row.priorities_json = json.dumps(report["priorities"], ensure_ascii=False)
    row.positioning_summary = report["pillar_summaries"]["positioning"]
    row.promise_summary = report["pillar_summaries"]["promise"]
    row.funnel_summary = report["pillar_summaries"]["funnel"]
    row.closing_summary = report["pillar_summaries"]["closing"]
    row.recommendations_json = json.dumps(report["recommendations"], ensure_ascii=False)
    row.model_used = report["model_used"]
    row.mode = report["mode"]

    existing_actions = db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id == user.id)).all()
    known = {(a.pillar_key, a.title.strip().casefold()) for a in existing_actions}
    order = max((a.sort_order for a in existing_actions), default=0)

    for idx, item in enumerate(report["action_plan"], start=1):
        identity = (item["pillar_key"], item["title"][:220].strip().casefold())
        if identity in known:
            continue
        known.add(identity)
        db.add(ActionPlanItem(
            user_id=user.id,
            pillar_key=item["pillar_key"],
            title=item["title"][:220],
            description=item["description"],
            priority=item["priority"],
            status="pending",
            sort_order=order + idx
        ))

    db.commit()
    return {"ok": True, "report": report}

@router.get("/full-report")
def full_report(user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(StrategicReport).where(StrategicReport.user_id == user.id))
    if not row:
        raise HTTPException(status_code=404, detail="Relatório estratégico ainda não gerado")
    return {
        "executive_summary": row.executive_summary,
        "stage_summary": row.stage_summary,
        "strengths": json.loads(row.strengths_json or "[]"),
        "gaps": json.loads(row.gaps_json or "[]"),
        "priorities": json.loads(row.priorities_json or "[]"),
        "pillar_summaries": {
            "positioning": row.positioning_summary,
            "promise": row.promise_summary,
            "funnel": row.funnel_summary,
            "closing": row.closing_summary
        },
        "recommendations": json.loads(row.recommendations_json or "[]"),
        "model_used": row.model_used,
        "mode": row.mode,
        "updated_at": row.updated_at
    }
