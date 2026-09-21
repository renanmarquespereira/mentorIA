import json
from datetime import datetime
from app.services.voice_answers import attach_voice
from app.models.conversation import VoiceAnswer
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.diagnosis import DiagnosisAnswer
from app.models.educator import PillarProgress
from app.models.pillar_report import PillarReport
from app.models.pillar_assessment import PillarAssessmentRound
from app.models.mentee_journey import MenteeNotification
from app.ai.pillar_report_service import generate_pillar_report, configured
from app.services.mentor_context import mentor_context_for_user
from app.services.pillar_pdf import build_pillar_pdf

router=APIRouter(prefix="/pillar-reports",tags=["pillar-reports"])


class PillarCompletionRequest(BaseModel):
    answer_text: str
    audio_id: str | None = Field(default=None, max_length=36)

VALID=["positioning","promise","funnel","closing"]

def _answers(db,user_id,pillar_key):
    rows=db.scalars(select(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id==user_id,
        DiagnosisAnswer.pillar_key==pillar_key
    )).all()
    return {r.question_key:r.answer_text for r in rows}

def _active_round(db, user_id, pillar_key):
    return db.scalar(select(PillarAssessmentRound).where(
        PillarAssessmentRound.user_id == user_id,
        PillarAssessmentRound.pillar_key == pillar_key,
        PillarAssessmentRound.status == "in_progress",
    ).order_by(PillarAssessmentRound.started_at.desc()))

def _promote(row, data):
    row.summary=data["summary"]
    row.perceived_authority=data["perceived_authority"]
    row.strengths_json=json.dumps(data["strengths"],ensure_ascii=False)
    row.gaps_json=json.dumps(data["gaps"],ensure_ascii=False)
    row.missing_information_json=json.dumps(data["missing_information"],ensure_ascii=False)
    row.completion_question=data.get("completion_question")
    row.practical_plan_json=json.dumps(data["practical_plan"],ensure_ascii=False)
    row.ready_for_next="true" if data["ready_for_next"] else "false"
    row.model_used=data["model_used"]

def _draft_payload(pillar_key, data):
    return {
      "pillar_key": pillar_key, "summary": data["summary"],
      "perceived_authority": data["perceived_authority"],
      "strengths": data["strengths"], "gaps": data["gaps"],
      "missing_information": data["missing_information"],
      "completion_question": data.get("completion_question"),
      "complement_answers": [], "ready_for_next": bool(data["ready_for_next"]),
      "practical_plan": data["practical_plan"], "model_used": data.get("model_used"),
      "updated_at": datetime.utcnow().isoformat(), "mentor_review_status": "none",
      "mentor_review_note": "", "mentor_reviewed_at": None, "redo_draft": True,
    }


@router.get("/{pillar_key}/pdf")
def pillar_report_pdf(pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if pillar_key not in VALID:
        raise HTTPException(404, "Pilar inválido")
    report = db.scalar(select(PillarReport).where(PillarReport.user_id == user.id, PillarReport.pillar_key == pillar_key))
    if not report:
        raise HTTPException(404, "Plano do pilar ainda não foi gerado")
    answers = db.scalars(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id == user.id, DiagnosisAnswer.pillar_key == pillar_key).order_by(DiagnosisAnswer.created_at)).all()
    content = build_pillar_pdf(mentee=user, pillar_key=pillar_key, answers=answers, report=report)
    filename = f"pilar-{pillar_key}.pdf"
    return Response(content=content, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{filename}"'})

@router.post("/{pillar_key}/generate")
def generate_report(pillar_key:str,user:User=Depends(current_user),db:Session=Depends(get_db)):
    if pillar_key not in VALID:
        raise HTTPException(404,"Pilar inválido")
    if not configured():
        raise HTTPException(503,"IA não configurada")

    answers=_answers(db,user.id,pillar_key)
    if not answers:
        raise HTTPException(409,"Responda o diagnóstico deste pilar primeiro")

    mentor_ctx = mentor_context_for_user(db, getattr(user, 'approved_by_user_id', None))
    data=generate_pillar_report(pillar_key,answers,mentor_ctx)

    row=db.scalar(select(PillarReport).where(
        PillarReport.user_id==user.id,
        PillarReport.pillar_key==pillar_key
    ))
    if not row:
        row=PillarReport(user_id=user.id,pillar_key=pillar_key)
        db.add(row)
    redo = _active_round(db, user.id, pillar_key)
    if redo and not data["ready_for_next"]:
        redo.draft_report_json = json.dumps(_draft_payload(pillar_key, data), ensure_ascii=False, default=str)
    else:
        _promote(row, data)
        if redo:
            redo.status = "completed"
            redo.completed_at = datetime.utcnow()
            redo.draft_report_json = "{}"

    prog=db.scalar(select(PillarProgress).where(
        PillarProgress.user_id==user.id,
        PillarProgress.pillar_key==pillar_key
    ))
    if prog is None:
        prog = PillarProgress(user_id=user.id, pillar_key=pillar_key, score=0)
        db.add(prog)
    prog.status="validated" if data["ready_for_next"] else "needs_report_completion"
    if data["ready_for_next"]:
        prog.score = 100
    db.add(MenteeNotification(user_id=user.id, kind="report", title="Relatório do pilar disponível", message=f"O relatório de {pillar_key} foi atualizado e já pode ser consultado em Meus relatórios."))

    db.commit()

    if redo and not data["ready_for_next"]:
        return _draft_payload(pillar_key, data)
    return {**get_report(pillar_key, user, db),
            "completion_question": data.get("completion_question")}

@router.get("/{pillar_key}")
def get_report(pillar_key:str,user:User=Depends(current_user),db:Session=Depends(get_db)):
    redo = _active_round(db, user.id, pillar_key)
    if redo and redo.draft_report_json and redo.draft_report_json != "{}":
        draft = json.loads(redo.draft_report_json)
        draft["complement_answers"] = [
            {"answer_text": answer.answer_text, "created_at": answer.created_at}
            for answer in db.scalars(select(DiagnosisAnswer).where(
                DiagnosisAnswer.user_id == user.id, DiagnosisAnswer.pillar_key == pillar_key,
                DiagnosisAnswer.question_key.like("report_followup_%"),
            ).order_by(DiagnosisAnswer.created_at, DiagnosisAnswer.question_key)).all()
        ]
        return draft
    row=db.scalar(select(PillarReport).where(
        PillarReport.user_id==user.id,
        PillarReport.pillar_key==pillar_key
    ))
    if not row:
        raise HTTPException(404,"Relatório do pilar ainda não gerado")
    return {
      "pillar_key":pillar_key,
      "summary":row.summary,
      "perceived_authority":row.perceived_authority,
      "strengths":json.loads(row.strengths_json or "[]"),
      "gaps":json.loads(row.gaps_json or "[]"),
      "missing_information":json.loads(row.missing_information_json or "[]"),
      "completion_question":row.completion_question,
      "complement_answers": [
          {"answer_text": answer.answer_text, "created_at": answer.created_at}
          for answer in db.scalars(select(DiagnosisAnswer).where(
              DiagnosisAnswer.user_id == user.id,
              DiagnosisAnswer.pillar_key == pillar_key,
              DiagnosisAnswer.question_key.like("report_followup_%"),
          ).order_by(DiagnosisAnswer.created_at, DiagnosisAnswer.question_key)).all()
      ],
      "ready_for_next":row.ready_for_next=="true",
      "practical_plan":json.loads(row.practical_plan_json or "[]"),
      "model_used":row.model_used,
      "updated_at":row.updated_at,
      "mentor_review_status":row.mentor_review_status,
      "mentor_review_note":row.mentor_review_note,
      "mentor_reviewed_at":row.mentor_reviewed_at
    }


@router.post("/{pillar_key}/complete")
def complete_pillar_report(
    pillar_key: str,
    payload: PillarCompletionRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if pillar_key not in VALID:
        raise HTTPException(404, "Pilar inválido")

    current = db.scalar(select(PillarReport).where(
        PillarReport.user_id == user.id,
        PillarReport.pillar_key == pillar_key
    ))
    if not current:
        raise HTTPException(409, "Gere primeiro o relatório do pilar")

    redo = _active_round(db, user.id, pillar_key)
    if current.ready_for_next == "true" and not redo:
        return {"ok": True, "already_ready": True, **get_report(pillar_key, user, db)}
    draft = json.loads(redo.draft_report_json or "{}") if redo else {}
    completion_question = draft.get("completion_question") if redo else current.completion_question

    answer = (payload.answer_text or "").strip()
    if len(answer) < 10:
        raise HTTPException(422, "A resposta complementar está muito curta")

    existing = db.scalars(select(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user.id,
        DiagnosisAnswer.pillar_key == pillar_key,
        DiagnosisAnswer.question_key.like("report_followup_%")
    )).all()

    question_key = f"report_followup_{len(existing)+1}"
    already_saved = False
    if getattr(payload, 'audio_id', None):
        recording = db.get(VoiceAnswer, payload.audio_id)
        if (recording and recording.user_id == user.id and not recording.answer_key
                and recording.question_text != (completion_question or 'Complemento do plano')):
            raise HTTPException(409, 'A pergunta do plano mudou. Remova este áudio e responda à pergunta atual.')
        if recording and recording.user_id == user.id and recording.answer_key:
            question_key = recording.answer_key
            already_saved = True
        attach_voice(db, user.id, pillar_key, 'report_complement',
                     payload.audio_id, question_key, answer)
    if not already_saved:
        db.add(DiagnosisAnswer(
        user_id=user.id,
        pillar_key=pillar_key,
        question_key=question_key,
        answer_text=answer,
        score=0,
        status="answered_ai"
        ))
    db.commit()

    answers = _answers(db, user.id, pillar_key)
    mentor_ctx = mentor_context_for_user(db, getattr(user, 'approved_by_user_id', None))
    data = generate_pillar_report(pillar_key, answers, mentor_ctx)

    if redo and not data["ready_for_next"]:
        redo.draft_report_json = json.dumps(_draft_payload(pillar_key, data), ensure_ascii=False, default=str)
    else:
        _promote(current, data)
        if redo:
            redo.status = "completed"
            redo.completed_at = datetime.utcnow()
            redo.draft_report_json = "{}"

    prog = db.scalar(select(PillarProgress).where(
        PillarProgress.user_id == user.id,
        PillarProgress.pillar_key == pillar_key
    ))
    if prog is None:
        prog = PillarProgress(user_id=user.id, pillar_key=pillar_key, score=0)
        db.add(prog)
    prog.status = "validated" if data["ready_for_next"] else "needs_report_completion"
    if data["ready_for_next"]:
        prog.score = 100

    db.commit()

    return {
        "ok": True,
        **get_report(pillar_key, user, db),
        "completion_question": data.get("completion_question"),
    }


@router.post("/{pillar_key}/recover-completion-question")
def recover_completion_question(pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Reformulate only a missing legacy question, preserving the report and gate."""
    saved = get_report(pillar_key, user, db)
    if saved["ready_for_next"] or saved["completion_question"]:
        return saved
    if not configured():
        raise HTTPException(503, "IA não configurada")
    context = mentor_context_for_user(db, getattr(user, "approved_by_user_id", None))
    data = generate_pillar_report(pillar_key, _answers(db, user.id, pillar_key), context)
    question = (data.get("completion_question") or "").strip()
    if not question:
        raise HTTPException(409, "A IA não formulou uma pergunta complementar. Peça à mentora para revisar as lacunas do plano.")
    row = db.scalar(select(PillarReport).where(
        PillarReport.user_id == user.id, PillarReport.pillar_key == pillar_key))
    row.completion_question = question
    db.commit()
    return get_report(pillar_key, user, db)
