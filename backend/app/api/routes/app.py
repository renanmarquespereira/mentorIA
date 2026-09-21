from datetime import date
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.educator import EducatorProfile, PillarProgress
from app.models.strategic_report import StrategicReport
from app.models.strategy import ActionPlanItem
from app.schemas.onboarding import OnboardingRequest
from app.models.diagnosis import DiagnosisAnswer
from app.models.pillar_report import PillarReport
from app.models.mentor_session import MentorSession
from app.models.mentee_journey import MenteeNotification
from app.ai.methodology_full import get_pillar, progress_percent

router = APIRouter(tags=["app"])

PILLARS = [
    ("positioning", "Posicionamento Único"),
    ("promise", "Promessa Atrativa"),
    ("funnel", "Funil de Venda Poderoso"),
    ("closing", "Fechamento Irrecusável"),
]

@router.get("/me")
def me(user: User = Depends(current_user)):
    return {"id": user.id, "name": user.name, "email": user.email, "role": getattr(user, "role", "mentee"), "approval_status": getattr(user, "approval_status", "pending_approval"), "profile_photo": getattr(user, "profile_photo", "") or ""}

@router.post("/onboarding")
def onboarding(data: OnboardingRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    profile = db.scalar(select(EducatorProfile).where(EducatorProfile.user_id == user.id))
    if not profile:
        profile = EducatorProfile(user_id=user.id)
        db.add(profile)
    for key, value in data.model_dump().items():
        setattr(profile, key, value)

    existing = {p.pillar_key: p for p in db.scalars(
        select(PillarProgress).where(PillarProgress.user_id == user.id)
    ).all()}
    for key, _ in PILLARS:
        if key not in existing:
            db.add(PillarProgress(user_id=user.id, pillar_key=key))
    db.commit()
    return {"ok": True, "recommended_pillar": "positioning"}

@router.get("/pillars")
def pillars(user: User = Depends(current_user), db: Session = Depends(get_db)):
    progress = {p.pillar_key: p for p in db.scalars(
        select(PillarProgress).where(PillarProgress.user_id == user.id)
    ).all()}
    answers = db.scalars(select(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user.id
    )).all()
    reports = {r.pillar_key: r for r in db.scalars(
        select(PillarReport).where(PillarReport.user_id == user.id)
    ).all()}
    items = []
    for key, name in PILLARS:
        group = {a.question_key: {"status": a.status} for a in answers
                 if a.pillar_key == key}
        calculated = progress_percent(group, get_pillar(key)["questions"])
        stored = progress.get(key)
        score = min(100, max(calculated, (stored.score or 0) if stored else 0))
        report = reports.get(key)
        if report:
            status = "validated" if report.ready_for_next == "true" else "needs_report_completion"
            if status == "validated":
                score = 100
        elif calculated == 100:
            status = "answered_ai"
        elif group or score > 0:
            status = "in_diagnosis"
        else:
            status = "not_started"
        items.append({"key": key, "name": name, "score": score, "status": status})
    return items



def _my_session_dict(row):
    return {"id": row.id, "scheduled_at": row.scheduled_at, "status": row.status,
            "summary": row.summary, "decisions": row.decisions, "next_steps": row.next_steps,
            "canceled_by": getattr(row, "canceled_by", "") or ""}

@router.get("/my-mentoring-sessions")
def my_mentoring_sessions(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(MentorSession).where(MentorSession.mentee_user_id == user.id).order_by(MentorSession.scheduled_at.desc())).all()
    return [_my_session_dict(r) for r in rows]

@router.post("/my-mentoring-sessions/{session_id}/cancel")
def cancel_my_mentoring_session(session_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(MentorSession).where(MentorSession.id == session_id, MentorSession.mentee_user_id == user.id))
    if not row:
        from fastapi import HTTPException
        raise HTTPException(404, "Mentoria não encontrada")
    if row.status != "scheduled":
        from fastapi import HTTPException
        raise HTTPException(409, "Somente uma mentoria agendada pode ser cancelada")
    row.status = "canceled"
    row.canceled_by = "mentee"
    db.add(MenteeNotification(user_id=row.mentor_user_id, kind="mentoring_session", title="Mentoria cancelada", message=f"{user.name} cancelou a mentoria agendada."))
    db.commit(); db.refresh(row)
    return _my_session_dict(row)

@router.get("/dashboard")
def dashboard(user: User = Depends(current_user), db: Session = Depends(get_db)):
    items = pillars(user, db)
    all_done = bool(items) and all(p["status"] == "validated" for p in items)
    actions = db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id == user.id)).all()
    completed = sum(a.status == "done" for a in actions)
    in_progress = sum(a.status == "in_progress" for a in actions)
    pending = sum(a.status not in {"done", "in_progress"} for a in actions)
    overdue = sum(a.status != "done" and a.due_date and a.due_date < date.today() for a in actions)
    action_counts = {"user_name": user.name, "profile_photo": getattr(user, "profile_photo", "") or "",
                     "total_actions": len(actions), "completed_actions": completed,
                     "in_progress_actions": in_progress, "pending_actions": pending,
                     "overdue_actions": overdue}
    active_actions = sorted(
        [a for a in actions if a.status != "done"],
        key=lambda a: (0 if a.due_date and a.due_date < date.today() else 1, a.due_date or date.max, a.sort_order),
    )
    focus = active_actions[0] if active_actions else None
    action_counts["action_focus"] = None if not focus else {
        "id": focus.id, "title": focus.title, "status": focus.status,
        "due_date": focus.due_date, "progress_percent": focus.progress_percent or 0,
    }
    next_mentoring = db.scalar(select(MentorSession).where(
        MentorSession.mentee_user_id == user.id, MentorSession.status == "scheduled",
        MentorSession.scheduled_at >= __import__("datetime").datetime.utcnow(),
    ).order_by(MentorSession.scheduled_at.asc()).limit(1))
    action_counts["next_mentoring"] = _my_session_dict(next_mentoring) if next_mentoring else None


    if all_done:
        strategy = db.scalar(select(StrategicReport).where(StrategicReport.user_id == user.id))
        return {
            "greeting": f"Olá, {user.name}",
            "journey_status": "diagnosis_completed",
            "current_pillar": None,
            "pillars": items,
            "next_action": "Gerar estratégia completa" if not strategy else "Executar plano de ação",
            "strategy_generated": strategy is not None,
            **action_counts,
        }

    current = next((p for p in items if p["status"] != "validated"), items[-1])
    return {
        "greeting": f"Olá, {user.name}",
        "journey_status": "in_diagnosis",
        "current_pillar": current,
        "pillars": items,
        "next_action": (f"Gerar Plano do Pilar: {current['name']}"
                        if current["status"] == "answered_ai"
                        else f"Continuar {current['name']}"),
        "strategy_generated": False,
        **action_counts,
    }
