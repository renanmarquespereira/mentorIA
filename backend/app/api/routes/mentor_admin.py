import json
from datetime import datetime, date
from app.models.conversation import VoiceAnswer, PlanConversation
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel
from sqlalchemy import select, delete
from sqlalchemy.orm import Session

from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.mentor_settings import MentorSettings
from app.models.strategic_report import StrategicReport
from app.ai.methodology_full import get_pillar, progress_percent
from app.ai.pillar1 import QUESTIONS as POSITIONING_QUESTIONS
from app.models.strategy import ActionPlanItem
from app.models.pillar_report import PillarReport
from app.models.diagnosis import DiagnosisAnswer
from app.models.educator import PillarProgress
from app.models.reset_request import ResetRequest
from app.models.mentor_note import MentorMenteeNote
from app.models.mentor_intelligence import MentorMenteeIntelligence
from app.models.mentee_journey import MenteeCheckIn, MenteeNotification
from app.models.mentor_session import MentorSession
from app.models.ai_analysis import DiagnosisAIAnalysis
from app.models.pillar_assessment import PillarAssessmentRound
from app.models.crm import Lead, Sale, LeadFollowUp
from app.models.metrics import CommercialMetric
from app.models.strategy import PositioningSynthesis
from app.models.diagnosis import DiagnosisSession
from app.models.educator import EducatorProfile
from app.ai.mentor_brief_service import generate_mentor_brief, configured as mentor_brief_configured
from app.services.mentor_context import mentor_context_for_user
from app.services.pillar_pdf import build_pillar_pdf

router = APIRouter(prefix="/mentor", tags=["mentor-admin"])

class MentorPrivateNotePayload(BaseModel):
    note: str

class ApprovalUpdate(BaseModel):
    status: str

class MentorPillarReportUpdate(BaseModel):
    summary: str
    perceived_authority: str = ""
    strengths: list[str] = []
    gaps: list[str] = []
    missing_information: list[str] = []
    practical_plan: list[dict] = []
    mentor_review_note: str = ""

class MentorSettingsPayload(BaseModel):
    authority_strong: list[str] = []
    authority_weak: list[str] = []
    relevant_certifications: list[str] = []
    low_relevance_certifications: list[str] = []
    valued_experiences: list[str] = []
    recommended_strategies: list[str] = []
    avoided_strategies: list[str] = []
    tone_of_voice: str = ""
    ideal_client_profile: str = ""
    freeform_methodology_notes: str = ""
    pillar_rules: dict = {}

def require_mentor(user: User):
    if getattr(user, "role", "mentee") not in {"mentor", "admin"}:
        raise HTTPException(status_code=403, detail="Acesso restrito à mentora")
    return user

@router.get("/mentees")
def list_mentees(
    status: str | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db)
):
    require_mentor(user)
    q = select(User).where(User.role == "mentee")
    if status:
        q = q.where(User.approval_status == status)
    rows = db.scalars(q.order_by(User.created_at.desc())).all()
    today = date.today()
    result = []
    for r in rows:
        actions = db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id == r.id)).all()
        latest_checkin = db.scalar(select(MenteeCheckIn).where(
            MenteeCheckIn.user_id == r.id
        ).order_by(MenteeCheckIn.created_at.desc()).limit(1))
        overdue = sum(1 for a in actions if a.status != "done" and a.due_date and a.due_date < today)
        in_progress = sum(1 for a in actions if a.status == "in_progress")
        completed = sum(1 for a in actions if a.status == "done")
        attention = "high" if overdue else ("medium" if latest_checkin and (latest_checkin.blockers or '').strip() else "normal")
        next_session = db.scalar(select(MentorSession).where(
            MentorSession.mentee_user_id == r.id, MentorSession.mentor_user_id == user.id,
            MentorSession.status == "scheduled", MentorSession.scheduled_at >= datetime.utcnow(),
        ).order_by(MentorSession.scheduled_at.asc()).limit(1))
        last_session = db.scalar(select(MentorSession).where(
            MentorSession.mentee_user_id == r.id, MentorSession.mentor_user_id == user.id,
            MentorSession.status == "completed",
        ).order_by(MentorSession.scheduled_at.desc()).limit(1))
        result.append({
            "id": r.id, "name": r.name, "email": r.email,
            "phone": getattr(r, "phone", ""),
            "profile_photo": getattr(r, "profile_photo", "") or "",
            "approval_status": r.approval_status,
            "status_label": {"active":"Desbloqueado","rejected":"Bloqueado","pending_approval":"Pendente"}.get(r.approval_status, r.approval_status),
            "created_at": r.created_at,
            "active_summary": {
                "total_actions": len(actions), "completed_actions": completed,
                "in_progress_actions": in_progress, "overdue_actions": overdue,
                "attention": attention,
                "latest_checkin_at": latest_checkin.created_at if latest_checkin else None,
                "latest_blockers": latest_checkin.blockers if latest_checkin else "",
                "next_session_topic": latest_checkin.next_session_topic if latest_checkin else "",
                "confidence_level": latest_checkin.confidence_level if latest_checkin else None,
                "next_mentoring_at": next_session.scheduled_at if next_session else None,
                "last_mentoring_at": last_session.scheduled_at if last_session else None,
            },
        })
    return result

@router.patch("/mentees/{user_id}/approval")
def update_approval(
    user_id: str,
    payload: ApprovalUpdate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db)
):
    require_mentor(user)
    if payload.status not in {"active", "rejected", "pending_approval"}:
        raise HTTPException(422, "Status inválido")
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Usuária não encontrada")
    target.approval_status = payload.status
    target.approved_by_user_id = user.id if payload.status == "active" else None
    db.commit()
    return {
        "ok": True,
        "user_id": target.id,
        "approval_status": target.approval_status
    }

@router.get("/settings")
def get_settings(
    user: User = Depends(current_user),
    db: Session = Depends(get_db)
):
    require_mentor(user)
    row = db.scalar(select(MentorSettings).where(MentorSettings.mentor_user_id == user.id))
    if not row:
        return {
            "authority_strong": [],
            "authority_weak": [],
            "relevant_certifications": [],
            "low_relevance_certifications": [],
            "valued_experiences": [],
            "recommended_strategies": [],
            "avoided_strategies": [],
            "tone_of_voice": "",
            "ideal_client_profile": "",
            "freeform_methodology_notes": "",
            "pillar_rules": {}
        }
    return {
        "authority_strong": json.loads(row.authority_strong_json or "[]"),
        "authority_weak": json.loads(row.authority_weak_json or "[]"),
        "relevant_certifications": json.loads(row.relevant_certifications_json or "[]"),
        "low_relevance_certifications": json.loads(row.low_relevance_certifications_json or "[]"),
        "valued_experiences": json.loads(row.valued_experiences_json or "[]"),
        "recommended_strategies": json.loads(row.recommended_strategies_json or "[]"),
        "avoided_strategies": json.loads(row.avoided_strategies_json or "[]"),
        "tone_of_voice": row.tone_of_voice,
        "ideal_client_profile": row.ideal_client_profile,
        "freeform_methodology_notes": row.freeform_methodology_notes,
        "pillar_rules": json.loads(row.pillar_rules_json or "{}"),
    }

@router.put("/settings")
def save_settings(
    payload: MentorSettingsPayload,
    user: User = Depends(current_user),
    db: Session = Depends(get_db)
):
    require_mentor(user)
    row = db.scalar(select(MentorSettings).where(MentorSettings.mentor_user_id == user.id))
    if not row:
        row = MentorSettings(mentor_user_id=user.id)
        db.add(row)
    row.authority_strong_json = json.dumps(payload.authority_strong, ensure_ascii=False)
    row.authority_weak_json = json.dumps(payload.authority_weak, ensure_ascii=False)
    row.relevant_certifications_json = json.dumps(payload.relevant_certifications, ensure_ascii=False)
    row.low_relevance_certifications_json = json.dumps(payload.low_relevance_certifications, ensure_ascii=False)
    row.valued_experiences_json = json.dumps(payload.valued_experiences, ensure_ascii=False)
    row.recommended_strategies_json = json.dumps(payload.recommended_strategies, ensure_ascii=False)
    row.avoided_strategies_json = json.dumps(payload.avoided_strategies, ensure_ascii=False)
    row.tone_of_voice = payload.tone_of_voice
    row.ideal_client_profile = payload.ideal_client_profile
    row.freeform_methodology_notes = payload.freeform_methodology_notes
    row.pillar_rules_json = json.dumps(payload.pillar_rules, ensure_ascii=False)
    db.commit()
    return {"ok": True}


@router.get("/mentees/{user_id}/overview")
def mentee_overview(
    user_id: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_mentor(user)

    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")

    progresses = db.scalars(
        select(PillarProgress)
        .where(PillarProgress.user_id == target.id)
    ).all()

    answers = db.scalars(
        select(DiagnosisAnswer)
        .where(DiagnosisAnswer.user_id == target.id)
    ).all()

    reports = db.scalars(
        select(PillarReport)
        .where(PillarReport.user_id == target.id)
    ).all()

    # Normaliza as perguntas para que todos os pilares usem a mesma estrutura
    # de acordeao no painel da mentora. O primeiro pilar possui um conjunto
    # historico de 10 perguntas em pillar1.py; usar apenas methodology_full
    # fazia perguntas antigas perderem titulo/texto e parecerem um bloco solto.
    def questions_for(pillar_key: str):
        if pillar_key == "positioning":
            return POSITIONING_QUESTIONS
        definition = get_pillar(pillar_key)
        return definition["questions"] if definition else []

    answer_groups = {}
    for row in answers:
        questions = questions_for(row.pillar_key)
        question = next((q for q in questions if q["key"] == row.question_key), None)
        is_followup = str(row.question_key).startswith("report_followup_")
        answer_groups.setdefault(row.pillar_key, []).append({
            "question_key": row.question_key,
            "question_title": (question["title"] if question else
                               "Pergunta complementar" if is_followup else
                               "Pergunta registrada"),
            "question_text": (question["question"] if question else
                              "Pergunta complementar da IA" if is_followup else
                              "Pergunta registrada anteriormente"),
            "answer_text": row.answer_text,
            "score": row.score,
            "status": row.status,
        })

    # Mantem as perguntas principais na ordem natural de cada pilar e deixa
    # complementares ao final. Isso tambem padroniza registros antigos.
    for pillar_key, items in answer_groups.items():
        order = {q["key"]: i for i, q in enumerate(questions_for(pillar_key))}
        items.sort(key=lambda item: (
            1 if str(item["question_key"]).startswith("report_followup_") else 0,
            order.get(item["question_key"], 999),
        ))

    report_map = {}
    for row in reports:
        report_map[row.pillar_key] = {
            "summary": row.summary,
            "perceived_authority": row.perceived_authority,
            "strengths": json.loads(row.strengths_json or "[]"),
            "gaps": json.loads(row.gaps_json or "[]"),
            "missing_information": json.loads(row.missing_information_json or "[]"),
            "practical_plan": json.loads(row.practical_plan_json or "[]"),
            "ready_for_next": row.ready_for_next == "true",
            "model_used": row.model_used,
            "updated_at": row.updated_at,
            "mentor_review_status": row.mentor_review_status,
            "mentor_review_note": row.mentor_review_note,
            "mentor_reviewed_at": row.mentor_reviewed_at,
        }

    stored_progress_map = {
        row.pillar_key: {
            "score": row.score,
            "status": row.status,
        }
        for row in progresses
    }

    progress_map = {}
    for key in ["positioning", "promise", "funnel", "closing"]:
        pillar_def = get_pillar(key)
        group = {
            item["question_key"]: {
                "answer_text": item["answer_text"],
                "score": item["score"],
                "status": item["status"],
            }
            for item in answer_groups.get(key, [])
            if not str(item["question_key"]).startswith("report_followup_")
        }

        calculated = progress_percent(
            group,
            pillar_def["questions"] if pillar_def else [],
        ) if pillar_def else 0

        stored = stored_progress_map.get(
            key,
            {"score": 0, "status": "not_started"},
        )

        final_score = max(calculated, stored.get("score", 0) or 0)

        report = report_map.get(key)

        if report and report.get("ready_for_next"):
            status = "validated"
            final_score = 100
        elif report and not report.get("ready_for_next"):
            status = "needs_report_completion"
        elif final_score > 0:
            status = "in_diagnosis"
        else:
            status = "not_started"

        progress_map[key] = {
            "score": final_score,
            "status": status,
        }

    return {
        "user": {
            "id": target.id,
            "name": target.name,
            "email": target.email,
            "phone": getattr(target, "phone", ""),
            "profile_photo": getattr(target, "profile_photo", "") or "",
            "access_status": (
                "unlocked" if target.approval_status == "active"
                else "pending" if target.approval_status == "pending_approval"
                else "blocked"
            ),
            "access_status_label": (
                "Desbloqueado" if target.approval_status == "active"
                else "Pendente" if target.approval_status == "pending_approval"
                else "Bloqueado"
            ),
            "created_at": target.created_at,
        },
        "latest_checkin": (lambda x: {
            "progress": x.progress, "blockers": x.blockers,
            "next_session_topic": x.next_session_topic,
            "confidence_level": x.confidence_level or 3, "created_at": x.created_at,
        } if x else None)(db.scalar(select(MenteeCheckIn).where(
            MenteeCheckIn.user_id == target.id
        ).order_by(MenteeCheckIn.created_at.desc()).limit(1))),
        "pending_reset_requests": [{
            "id": r.id,
            "reset_type": r.reset_type,
            "pillar_key": r.pillar_key,
            "status": r.status,
            "created_at": r.created_at,
        } for r in db.scalars(select(ResetRequest).where(
            ResetRequest.mentee_user_id == target.id,
            ResetRequest.mentor_user_id == user.id,
            ResetRequest.status == "pending",
        ).order_by(ResetRequest.created_at.desc())).all()],
        "pillars": {
            key: {
                "progress": progress_map.get(key, {"score": 0, "status": "not_started"}),
                "answers": answer_groups.get(key, []),
                "report": report_map.get(key),
            }
            for key in ["positioning", "promise", "funnel", "closing"]
        }
    }




def _mentor_target(user_id: str, user: User, db: Session) -> User:
    require_mentor(user)
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")
    return target

@router.get("/mentees/{user_id}/intelligence-cache")
def mentor_intelligence_cache(user_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = _mentor_target(user_id, user, db)
    row = db.scalar(select(MentorMenteeIntelligence).where(MentorMenteeIntelligence.mentee_user_id == target.id, MentorMenteeIntelligence.mentor_user_id == user.id))
    if not row:
        return {"brief": None, "evolution": None, "brief_updated_at": None, "evolution_updated_at": None}
    def decoded(raw):
        if not raw: return None
        try: return json.loads(raw)
        except Exception: return None
    return {"brief": decoded(row.brief_json), "evolution": decoded(row.evolution_json), "brief_updated_at": row.brief_updated_at, "evolution_updated_at": row.evolution_updated_at}

def _save_intelligence(db: Session, mentor_id: str, mentee_id: str, *, brief=None, evolution=None):
    row = db.scalar(select(MentorMenteeIntelligence).where(MentorMenteeIntelligence.mentee_user_id == mentee_id, MentorMenteeIntelligence.mentor_user_id == mentor_id))
    if not row:
        row = MentorMenteeIntelligence(mentor_user_id=mentor_id, mentee_user_id=mentee_id); db.add(row)
    now = datetime.utcnow()
    if brief is not None:
        row.brief_json = json.dumps(brief, ensure_ascii=False, default=str); row.brief_updated_at = now
    if evolution is not None:
        row.evolution_json = json.dumps(evolution, ensure_ascii=False, default=str); row.evolution_updated_at = now
    row.updated_at = now; db.commit()

@router.get("/mentees/{user_id}/private-notes")
def mentor_private_notes(user_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = _mentor_target(user_id, user, db)
    rows = db.scalars(select(MentorMenteeNote).where(
        MentorMenteeNote.mentee_user_id == target.id,
        MentorMenteeNote.mentor_user_id == user.id,
    ).order_by(MentorMenteeNote.created_at.desc()).limit(30)).all()
    return [{"id": r.id, "note": r.note, "created_at": r.created_at} for r in rows]

@router.post("/mentees/{user_id}/private-notes")
def add_mentor_private_note(user_id: str, payload: MentorPrivateNotePayload, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = _mentor_target(user_id, user, db)
    note = payload.note.strip()
    if not note:
        raise HTTPException(422, "Escreva uma anotação antes de salvar")
    row = MentorMenteeNote(mentor_user_id=user.id, mentee_user_id=target.id, note=note)
    db.add(row); db.commit(); db.refresh(row)
    return {"id": row.id, "note": row.note, "created_at": row.created_at}

@router.delete("/mentees/{user_id}/private-notes/{note_id}")
def delete_mentor_private_note(user_id: str, note_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = _mentor_target(user_id, user, db)
    row = db.scalar(select(MentorMenteeNote).where(
        MentorMenteeNote.id == note_id,
        MentorMenteeNote.mentee_user_id == target.id,
        MentorMenteeNote.mentor_user_id == user.id,
    ))
    if not row:
        raise HTTPException(404, "Anotação não encontrada")
    db.delete(row)
    db.commit()
    return {"ok": True}

@router.delete("/mentees/{user_id}")
def permanently_delete_mentee(user_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    target = _mentor_target(user_id, user, db)
    uid = target.id
    # Apaga primeiro registros dependentes para respeitar as FKs do PostgreSQL.
    lead_ids = list(db.scalars(select(Lead.id).where(Lead.user_id == uid)).all())
    if lead_ids:
        db.execute(delete(LeadFollowUp).where(LeadFollowUp.lead_id.in_(lead_ids)))
        db.execute(delete(Sale).where(Sale.lead_id.in_(lead_ids)))
    for model in [
        LeadFollowUp, Sale, CommercialMetric, DiagnosisAIAnalysis, VoiceAnswer, PlanConversation,
        DiagnosisAnswer, DiagnosisSession, PillarProgress, PillarReport, PillarAssessmentRound,
        ActionPlanItem, PositioningSynthesis, StrategicReport, MenteeCheckIn, MenteeNotification, MentorSession,
        MentorMenteeIntelligence, MentorMenteeNote, ResetRequest, EducatorProfile, Lead,
    ]:
        if hasattr(model, 'user_id'):
            db.execute(delete(model).where(model.user_id == uid))
        elif hasattr(model, 'mentee_user_id'):
            db.execute(delete(model).where(model.mentee_user_id == uid))
    db.delete(target)
    db.commit()
    return {"ok": True, "deleted_user_id": uid}

@router.get("/mentees/{user_id}/evolution")
def mentee_evolution(
    user_id: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Painel objetivo de evolução usando apenas eventos já registrados no produto."""
    require_mentor(user)
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")

    reports = db.scalars(select(PillarReport).where(PillarReport.user_id == target.id)).all()
    progresses = db.scalars(select(PillarProgress).where(PillarProgress.user_id == target.id)).all()
    actions = db.scalars(
        select(ActionPlanItem).where(ActionPlanItem.user_id == target.id)
        .order_by(ActionPlanItem.created_at.desc())
    ).all()
    conversations = db.scalars(
        select(PlanConversation).where(PlanConversation.user_id == target.id)
        .order_by(PlanConversation.created_at.desc()).limit(30)
    ).all()
    strategic = db.scalar(select(StrategicReport).where(StrategicReport.user_id == target.id))

    pillar_labels = {
        "positioning": "Posicionamento Único", "promise": "Promessa Atrativa",
        "funnel": "Funil de Venda Poderoso", "closing": "Fechamento Irrecusável",
    }
    report_map = {r.pillar_key: r for r in reports}
    progress_map = {r.pillar_key: r for r in progresses}
    pillars = []
    for key, label in pillar_labels.items():
        report = report_map.get(key)
        progress = progress_map.get(key)
        score = 100 if report and report.ready_for_next == "true" else int(getattr(progress, "score", 0) or 0)
        pillars.append({
            "key": key, "label": label, "score": score,
            "status": "validated" if report and report.ready_for_next == "true" else getattr(progress, "status", "not_started"),
            "updated_at": report.updated_at if report else None,
        })

    today = date.today()
    completed = [a for a in actions if a.status == "done"]
    in_progress = [a for a in actions if a.status == "in_progress"]
    pending = [a for a in actions if a.status not in {"done", "in_progress"}]
    overdue = [a for a in actions if a.status != "done" and a.due_date and a.due_date < today]

    timeline = []
    for r in reports:
        timeline.append({"at": r.updated_at, "type": "pillar", "title": f"Plano atualizado: {pillar_labels.get(r.pillar_key, r.pillar_key)}", "detail": "Pilar validado" if r.ready_for_next == "true" else "Plano em evolução"})
    for a in actions:
        at = a.completed_at or a.created_at
        timeline.append({"at": at, "type": "action", "title": a.title, "detail": "Ação concluída" if a.status == "done" else "Ação adicionada ao plano"})
    # Agrupa conversas para a atividade recente ser útil, sem repetir "Conversa com a IA" várias vezes.
    conversation_groups = {}
    for c in conversations:
        group = conversation_groups.setdefault(c.pillar_key, {"count": 0, "at": c.created_at})
        group["count"] += 1
        if c.created_at and (not group["at"] or c.created_at > group["at"]):
            group["at"] = c.created_at
    for pillar_key, group in conversation_groups.items():
        count = group["count"]
        timeline.append({
            "at": group["at"], "type": "conversation",
            "title": f"Conversou com a IA sobre {pillar_labels.get(pillar_key, pillar_key)}",
            "detail": f"{count} interação(ões) recente(s) registrada(s) neste pilar.",
        })
    if strategic:
        timeline.append({"at": strategic.updated_at, "type": "strategy", "title": "Estratégia consolidada atualizada", "detail": strategic.stage_summary or "Relatório estratégico"})
    timeline = sorted(timeline, key=lambda x: x["at"] or datetime.min, reverse=True)[:20]

    alerts = []
    if overdue:
        alerts.append({"level": "high", "title": f"{len(overdue)} ação(ões) vencida(s)", "detail": "Revisar prazos, bloqueios e prioridade na próxima mentoria."})
    if actions and not completed:
        alerts.append({"level": "medium", "title": "Nenhuma ação concluída ainda", "detail": "Confirmar se há impedimentos ou se o plano precisa ser simplificado."})
    if len(conversations) >= 8:
        alerts.append({"level": "info", "title": "Uso frequente da IA", "detail": f"Há {len(conversations)} conversas recentes disponíveis para contextualizar a mentoria."})
    # "O que mudou desde a última vez": a última anotação privada funciona como marco da sessão anterior.
    last_note = db.scalar(select(MentorMenteeNote).where(
        MentorMenteeNote.mentee_user_id == target.id,
        MentorMenteeNote.mentor_user_id == user.id,
    ).order_by(MentorMenteeNote.created_at.desc()).limit(1))
    since = last_note.created_at if last_note else None
    changes_since_last = []
    if since:
        for r in reports:
            if r.updated_at and r.updated_at > since:
                changes_since_last.append({"type": "pillar", "text": f"{pillar_labels.get(r.pillar_key, r.pillar_key)} foi atualizado."})
        for a in actions:
            if a.completed_at and a.completed_at > since:
                changes_since_last.append({"type": "action", "text": f"Ação concluída: {a.title}"})
            elif a.created_at and a.created_at > since:
                changes_since_last.append({"type": "action", "text": f"Nova ação: {a.title}"})
        new_conversations = sum(1 for c in conversations if c.created_at and c.created_at > since)
        if new_conversations:
            changes_since_last.append({"type": "conversation", "text": f"{new_conversations} nova(s) conversa(s) com a IA."})

    validated = sum(1 for p in pillars if p["status"] == "validated")
    if validated == 4:
        alerts.append({"level": "positive", "title": "Todos os pilares validados", "detail": "A próxima sessão pode priorizar execução, métricas e ajustes de estratégia."})

    result = {
        "summary": {
            "validated_pillars": validated, "total_pillars": 4,
            "total_actions": len(actions), "completed_actions": len(completed),
            "in_progress_actions": len(in_progress), "pending_actions": len(pending),
            "overdue_actions": len(overdue), "recent_ai_conversations": len(conversations),
        },
        "since_last_session": {"baseline_at": since, "items": changes_since_last[:12]},
        "pillars": pillars,
        "actions": {
            "completed": [{"id": a.id, "title": a.title, "pillar": a.pillar_key, "due_date": a.due_date, "completed_at": a.completed_at} for a in completed],
            "in_progress": [{"id": a.id, "title": a.title, "pillar": a.pillar_key, "due_date": a.due_date} for a in in_progress],
            "pending": [{"id": a.id, "title": a.title, "pillar": a.pillar_key, "due_date": a.due_date, "overdue": bool(a.due_date and a.due_date < today)} for a in pending],
        },
        "alerts": alerts,
        "timeline": timeline,
        "note": "O painel reflete os registros atuais do app; não presume resultados externos não informados pela mentorada.",
    }
    _save_intelligence(db, user.id, target.id, evolution=result)
    return result


@router.post("/mentees/{user_id}/intelligent-brief")
def generate_intelligent_mentee_brief(
    user_id: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_mentor(user)
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")
    if not mentor_brief_configured():
        raise HTTPException(503, "IA não configurada no backend")

    answers = db.scalars(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id == target.id)).all()
    reports = db.scalars(select(PillarReport).where(PillarReport.user_id == target.id)).all()
    actions = db.scalars(
        select(ActionPlanItem).where(ActionPlanItem.user_id == target.id)
        .order_by(ActionPlanItem.created_at.desc())
    ).all()
    conversations = db.scalars(
        select(PlanConversation).where(PlanConversation.user_id == target.id)
        .order_by(PlanConversation.created_at.desc()).limit(40)
    ).all()
    strategic = db.scalar(select(StrategicReport).where(StrategicReport.user_id == target.id))
    mentor_notes = db.scalars(select(MentorMenteeNote).where(
        MentorMenteeNote.mentee_user_id == target.id,
        MentorMenteeNote.mentor_user_id == user.id,
    ).order_by(MentorMenteeNote.created_at.desc()).limit(10)).all()
    mentee_checkins = db.scalars(select(MenteeCheckIn).where(MenteeCheckIn.user_id == target.id).order_by(MenteeCheckIn.created_at.desc()).limit(5)).all()
    mentor_sessions = db.scalars(select(MentorSession).where(MentorSession.mentee_user_id == target.id, MentorSession.mentor_user_id == user.id).order_by(MentorSession.scheduled_at.desc()).limit(10)).all()

    answer_payload = []
    for row in answers:
        definition = get_pillar(row.pillar_key)
        question = next((q for q in definition["questions"] if q["key"] == row.question_key), None) if definition else None
        answer_payload.append({
            "pillar": row.pillar_key,
            "question": question["question"] if question else row.question_key,
            "answer": row.answer_text,
            "score": row.score,
            "status": row.status,
        })

    context = {
        "mentee": {"name": target.name, "created_at": target.created_at},
        "diagnosis_answers": answer_payload,
        "validated_pillar_plans": [{
            "pillar": r.pillar_key,
            "summary": r.summary,
            "strengths": json.loads(r.strengths_json or "[]"),
            "gaps": json.loads(r.gaps_json or "[]"),
            "practical_plan": json.loads(r.practical_plan_json or "[]"),
            "validated": r.ready_for_next == "true",
            "mentor_review_note": r.mentor_review_note,
        } for r in reports],
        "strategic_report": None if not strategic else {
            "executive_summary": strategic.executive_summary,
            "stage_summary": strategic.stage_summary,
            "strengths": json.loads(strategic.strengths_json or "[]"),
            "gaps": json.loads(strategic.gaps_json or "[]"),
            "priorities": json.loads(strategic.priorities_json or "[]"),
            "recommendations": json.loads(strategic.recommendations_json or "[]"),
        },
        "action_plan": [{
            "pillar": a.pillar_key, "title": a.title, "description": a.description,
            "priority": a.priority, "status": a.status, "due_date": a.due_date,
            "notes": a.notes, "completed_at": a.completed_at,
        } for a in actions],
        "recent_ai_conversations": [{
            "pillar": c.pillar_key, "ai_question": c.question,
            "mentee_reply": c.reply, "created_at": c.created_at,
        } for c in reversed(conversations)],
        "mentor_private_notes": [{"note": n.note, "created_at": n.created_at} for n in reversed(mentor_notes)],
        "mentee_pre_session_checkins": [{"progress": x.progress, "blockers": x.blockers, "next_session_topic": x.next_session_topic, "confidence_level": x.confidence_level or 3, "created_at": x.created_at} for x in reversed(mentee_checkins)],
        "mentoring_sessions": [{"scheduled_at": x.scheduled_at, "status": x.status, "summary": x.summary, "decisions": x.decisions, "next_steps": x.next_steps} for x in reversed(mentor_sessions)],
        "mentor_methodology": mentor_context_for_user(db, user.id),
    }
    try:
        brief = generate_mentor_brief(context)
        # Fontes visíveis em acordeão no painel: a mentora pode conferir a análise sem poluir a tela.
        brief["source_answers"] = answer_payload
        _save_intelligence(db, user.id, target.id, brief=brief)
        return brief
    except RuntimeError as exc:
        raise HTTPException(503, str(exc))
    except Exception:
        raise HTTPException(502, "Não foi possível gerar o resumo inteligente agora. Tente novamente.")


@router.get("/mentees/{user_id}/pillar-report/{pillar_key}/pdf")
def mentor_pillar_report_pdf(
    user_id: str, pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db),
):
    require_mentor(user)
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")
    report = db.scalar(select(PillarReport).where(PillarReport.user_id == target.id, PillarReport.pillar_key == pillar_key))
    if not report:
        raise HTTPException(404, "Plano do pilar ainda não foi gerado")
    answers = db.scalars(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id == target.id, DiagnosisAnswer.pillar_key == pillar_key).order_by(DiagnosisAnswer.created_at)).all()
    content = build_pillar_pdf(mentee=target, pillar_key=pillar_key, answers=answers, report=report)
    return Response(content=content, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="pilar-{pillar_key}.pdf"'})


@router.post("/mentees/{user_id}/reset-pillar-report/{pillar_key}")
def request_reset_pillar_report(
    user_id: str, pillar_key: str,
    user: User = Depends(current_user), db: Session = Depends(get_db),
):
    require_mentor(user)
    if pillar_key not in {"positioning", "promise", "funnel", "closing"}:
        raise HTTPException(404, "Pilar inválido")
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")
    pending = db.scalar(select(ResetRequest).where(
        ResetRequest.mentee_user_id == target.id,
        ResetRequest.reset_type == "pillar_report",
        ResetRequest.pillar_key == pillar_key,
        ResetRequest.status == "pending",
    ))
    if pending:
        return {"ok": True, "request_id": pending.id, "status": "pending", "message": "Solicitação já aguardando autorização."}
    row = ResetRequest(mentee_user_id=target.id, mentor_user_id=user.id,
                       reset_type="pillar_report", pillar_key=pillar_key)
    db.add(row); db.commit(); db.refresh(row)
    return {"ok": True, "request_id": row.id, "status": "pending", "message": "Reset solicitado. Aguardando autorização da mentorada."}


@router.post("/mentees/{user_id}/reset-journey")
def request_reset_mentee_journey(
    user_id: str, user: User = Depends(current_user), db: Session = Depends(get_db),
):
    require_mentor(user)
    target = db.scalar(select(User).where(User.id == user_id, User.role == "mentee"))
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")
    if user.role != "admin" and target.approved_by_user_id != user.id:
        raise HTTPException(403, "Esta mentorada não está vinculada a você")
    pending = db.scalar(select(ResetRequest).where(
        ResetRequest.mentee_user_id == target.id,
        ResetRequest.reset_type == "journey",
        ResetRequest.status == "pending",
    ))
    if pending:
        return {"ok": True, "request_id": pending.id, "status": "pending", "message": "Solicitação já aguardando autorização."}
    row = ResetRequest(mentee_user_id=target.id, mentor_user_id=user.id, reset_type="journey")
    db.add(row); db.commit(); db.refresh(row)
    return {"ok": True, "request_id": row.id, "status": "pending", "message": "Reset solicitado. Aguardando autorização da mentorada."}


@router.get("/reset-requests")
def my_reset_requests(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if getattr(user, "role", "mentee") != "mentee":
        raise HTTPException(403, "Acesso restrito à mentorada")
    rows = db.scalars(select(ResetRequest).where(
        ResetRequest.mentee_user_id == user.id,
        ResetRequest.status == "pending",
    ).order_by(ResetRequest.created_at.desc())).all()
    return [{"id": r.id, "reset_type": r.reset_type, "pillar_key": r.pillar_key,
             "status": r.status, "created_at": r.created_at} for r in rows]


class ResetDecision(BaseModel):
    decision: str


@router.post("/reset-requests/{request_id}/respond")
def respond_reset_request(
    request_id: str, payload: ResetDecision,
    user: User = Depends(current_user), db: Session = Depends(get_db),
):
    if getattr(user, "role", "mentee") != "mentee":
        raise HTTPException(403, "Acesso restrito à mentorada")
    if payload.decision not in {"approve", "reject"}:
        raise HTTPException(422, "Decisão inválida")
    row = db.scalar(select(ResetRequest).where(ResetRequest.id == request_id).with_for_update())
    if not row or row.mentee_user_id != user.id:
        raise HTTPException(404, "Solicitação não encontrada")
    if row.status != "pending":
        raise HTTPException(409, "Esta solicitação já foi respondida")
    row.responded_at = datetime.utcnow()
    if payload.decision == "reject":
        row.status = "rejected"; db.commit()
        return {"ok": True, "status": "rejected", "message": "Reset recusado. Nenhum dado foi alterado."}

    if row.reset_type == "pillar_report":
        db.execute(delete(PillarReport).where(PillarReport.user_id == user.id,
                                              PillarReport.pillar_key == row.pillar_key))
        progress = db.scalar(select(PillarProgress).where(PillarProgress.user_id == user.id,
                                                          PillarProgress.pillar_key == row.pillar_key))
        if progress:
            progress.status = "answered_ai"
    elif row.reset_type == "journey":
        db.execute(delete(VoiceAnswer).where(VoiceAnswer.user_id == user.id))
        db.execute(delete(PlanConversation).where(PlanConversation.user_id == user.id))
        db.execute(delete(DiagnosisAnswer).where(DiagnosisAnswer.user_id == user.id))
        db.execute(delete(PillarProgress).where(PillarProgress.user_id == user.id))
        db.execute(delete(PillarReport).where(PillarReport.user_id == user.id))
        db.execute(delete(ActionPlanItem).where(ActionPlanItem.user_id == user.id))
        db.execute(delete(StrategicReport).where(StrategicReport.user_id == user.id))
    else:
        raise HTTPException(409, "Tipo de reset inválido")
    row.status = "approved"
    db.commit()
    return {"ok": True, "status": "approved", "message": "Reset autorizado e concluído."}


@router.put("/mentees/{user_id}/pillar-report/{pillar_key}")
def mentor_edit_pillar_report(
    user_id: str,
    pillar_key: str,
    payload: MentorPillarReportUpdate,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_mentor(user)

    if pillar_key not in {"positioning", "promise", "funnel", "closing"}:
        raise HTTPException(404, "Pilar inválido")

    target = db.scalar(
        select(User).where(User.id == user_id, User.role == "mentee")
    )
    if not target:
        raise HTTPException(404, "Mentorada não encontrada")

    report = db.scalar(
        select(PillarReport).where(
            PillarReport.user_id == target.id,
            PillarReport.pillar_key == pillar_key,
        )
    )
    if not report:
        raise HTTPException(404, "Plano do pilar ainda não foi gerado")

    report.summary = payload.summary.strip()
    report.perceived_authority = payload.perceived_authority.strip()
    report.strengths_json = json.dumps(payload.strengths, ensure_ascii=False)
    report.gaps_json = json.dumps(payload.gaps, ensure_ascii=False)
    report.missing_information_json = json.dumps(
        payload.missing_information, ensure_ascii=False
    )
    report.practical_plan_json = json.dumps(
        payload.practical_plan, ensure_ascii=False
    )
    report.mentor_review_note = payload.mentor_review_note.strip()
    report.mentor_review_status = "edited"
    report.mentor_reviewed_by_user_id = user.id
    report.mentor_reviewed_at = datetime.utcnow()
    db.add(MenteeNotification(user_id=target.id, kind="mentor", title="Orientação da mentora atualizada", message=f"Sua mentora atualizou o relatório de {pillar_key}."))

    db.commit()

    return {
        "ok": True,
        "pillar_key": pillar_key,
        "mentor_review_status": report.mentor_review_status,
        "mentor_review_note": report.mentor_review_note,
        "mentor_reviewed_at": report.mentor_reviewed_at,
    }

# v2.26.0 - Gestão das Sessões de Mentoria
class MentorSessionPayload(BaseModel):
    scheduled_at: datetime
    status: str = "scheduled"
    summary: str = ""
    decisions: str = ""
    next_steps: str = ""
    action_ids: list[str] = []


def _session_dict(row, db: Session):
    linked = db.scalars(select(ActionPlanItem).where(ActionPlanItem.linked_session_id == row.id).order_by(ActionPlanItem.sort_order)).all()
    return {
        "id": row.id, "scheduled_at": row.scheduled_at, "status": row.status,
        "summary": row.summary, "decisions": row.decisions, "next_steps": row.next_steps,
        "created_at": row.created_at, "updated_at": row.updated_at,
        "actions": [{"id": a.id, "title": a.title, "status": a.status, "progress_percent": a.progress_percent} for a in linked],
    }


def _apply_session_actions(db: Session, target_id: str, session_id: str, action_ids: list[str]):
    db.execute(
        ActionPlanItem.__table__.update()
        .where(ActionPlanItem.user_id == target_id, ActionPlanItem.linked_session_id == session_id)
        .values(linked_session_id=None)
    )
    if action_ids:
        db.execute(
            ActionPlanItem.__table__.update()
            .where(ActionPlanItem.user_id == target_id, ActionPlanItem.id.in_(action_ids))
            .values(linked_session_id=session_id)
        )


@router.get("/sessions")
def mentor_agenda(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if getattr(user, "role", "mentee") not in {"mentor", "admin"}:
        raise HTTPException(403, "Acesso restrito à mentora")
    rows = db.scalars(select(MentorSession).where(MentorSession.mentor_user_id == user.id).order_by(MentorSession.scheduled_at.asc())).all()
    user_ids = {r.mentee_user_id for r in rows}
    names = {u.id: u.name for u in db.scalars(select(User).where(User.id.in_(user_ids))).all()} if user_ids else {}
    return [{"id": r.id, "mentee_user_id": r.mentee_user_id, "mentee_name": names.get(r.mentee_user_id, "Mentorada"), "scheduled_at": r.scheduled_at, "status": r.status} for r in rows if r.status == "scheduled"]


@router.get("/mentees/{user_id}/sessions")
def list_mentor_sessions(user_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.models.mentor_session import MentorSession
    target = _mentor_target(user_id, user, db)
    rows = db.scalars(select(MentorSession).where(
        MentorSession.mentee_user_id == target.id,
        MentorSession.mentor_user_id == user.id,
    ).order_by(MentorSession.scheduled_at.desc())).all()
    now = datetime.utcnow()
    completed = [r for r in rows if r.status == "completed"]
    upcoming = sorted([r for r in rows if r.status == "scheduled" and r.scheduled_at >= now], key=lambda r: r.scheduled_at)
    actions = db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id == target.id).order_by(ActionPlanItem.sort_order)).all()
    return {
        "sessions": [_session_dict(r, db) for r in rows],
        "last_session": _session_dict(max(completed, key=lambda r: r.scheduled_at), db) if completed else None,
        "next_session": _session_dict(upcoming[0], db) if upcoming else None,
        "available_actions": [{"id": a.id, "title": a.title, "status": a.status, "linked_session_id": a.linked_session_id} for a in actions],
    }


@router.post("/mentees/{user_id}/sessions")
def create_mentor_session(user_id: str, payload: MentorSessionPayload, user: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.models.mentor_session import MentorSession
    target = _mentor_target(user_id, user, db)
    if payload.status not in {"scheduled", "completed", "canceled"}:
        raise HTTPException(422, "Status de sessão inválido")
    row = MentorSession(
        mentee_user_id=target.id, mentor_user_id=user.id, scheduled_at=payload.scheduled_at,
        status=payload.status, summary=payload.summary.strip(), decisions=payload.decisions.strip(), next_steps=payload.next_steps.strip(),
    )
    db.add(row)
    db.flush()
    _apply_session_actions(db, target.id, row.id, payload.action_ids)
    db.add(MenteeNotification(user_id=target.id, kind="session", title="Mentoria agendada", message=f"Sua próxima mentoria foi agendada para {payload.scheduled_at.strftime('%d/%m/%Y às %H:%M')}."))
    db.commit()
    db.refresh(row)
    return _session_dict(row, db)


@router.put("/mentees/{user_id}/sessions/{session_id}")
def update_mentor_session(user_id: str, session_id: str, payload: MentorSessionPayload, user: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.models.mentor_session import MentorSession
    target = _mentor_target(user_id, user, db)
    row = db.scalar(select(MentorSession).where(MentorSession.id == session_id, MentorSession.mentee_user_id == target.id, MentorSession.mentor_user_id == user.id))
    if not row:
        raise HTTPException(404, "Sessão não encontrada")
    if payload.status not in {"scheduled", "completed", "canceled"}:
        raise HTTPException(422, "Status de sessão inválido")
    row.scheduled_at = payload.scheduled_at
    row.status = payload.status
    row.summary = payload.summary.strip()
    row.decisions = payload.decisions.strip()
    row.next_steps = payload.next_steps.strip()
    _apply_session_actions(db, target.id, row.id, payload.action_ids)
    db.commit()
    db.refresh(row)
    return _session_dict(row, db)


@router.delete("/mentees/{user_id}/sessions/{session_id}")
def delete_mentor_session(user_id: str, session_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.models.mentor_session import MentorSession
    target = _mentor_target(user_id, user, db)
    row = db.scalar(select(MentorSession).where(MentorSession.id == session_id, MentorSession.mentee_user_id == target.id, MentorSession.mentor_user_id == user.id))
    if not row:
        raise HTTPException(404, "Sessão não encontrada")
    db.execute(ActionPlanItem.__table__.update().where(ActionPlanItem.linked_session_id == row.id).values(linked_session_id=None))
    db.delete(row)
    db.commit()
    return {"ok": True}
