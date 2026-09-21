import json
from datetime import datetime
from app.services.voice_answers import attach_voice
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, delete
from sqlalchemy.orm import Session

from app.api.deps import current_user
from app.db.session import get_db
from app.models.pillar_report import PillarReport
from app.models.user import User
from app.models.educator import PillarProgress
from app.models.diagnosis import DiagnosisAnswer
from app.models.ai_analysis import DiagnosisAIAnalysis
from app.models.pillar_assessment import PillarAssessmentRound
from app.schemas.diagnosis import DiagnosisAnswerRequest, DiagnosisAnswerResponse, AnswerCoachRequest
from app.ai.methodology_full import get_pillar, evaluate_answer, progress_percent, next_question
from app.ai.mentor_service import configured, analyze, coach_answer
from app.core.config import settings
from app.services.mentor_context import mentor_context_for_user

router = APIRouter(prefix="/pillars", tags=["pillars"])


def active_round(db: Session, user_id: str, pillar_key: str):
    return db.scalar(select(PillarAssessmentRound).where(
        PillarAssessmentRound.user_id == user_id,
        PillarAssessmentRound.pillar_key == pillar_key,
        PillarAssessmentRound.status == "in_progress",
    ).order_by(PillarAssessmentRound.started_at.desc()))


def answers_map(db: Session, user_id: str, pillar_key: str):
    rows = db.scalars(select(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user_id,
        DiagnosisAnswer.pillar_key == pillar_key,
    )).all()
    return {
        r.question_key: {
            "answer_text": r.answer_text,
            "score": r.score,
            "status": r.status,
        }
        for r in rows
    }


def progress_row(db: Session, user_id: str, pillar_key: str):
    return db.scalar(select(PillarProgress).where(
        PillarProgress.user_id == user_id,
        PillarProgress.pillar_key == pillar_key,
    ))


def unlocked(db: Session, user_id: str, pillar: dict) -> bool:
    required = pillar.get("requires")
    if not required:
        return True
    report = db.scalar(select(PillarReport).where(
        PillarReport.user_id == user_id,
        PillarReport.pillar_key == required,
    ))
    return bool(report and report.ready_for_next == "true")


@router.get("/{pillar_key}")
def get_diagnosis(
    pillar_key: str,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(status_code=404, detail="Pilar não encontrado")

    is_open = unlocked(db, user.id, pillar)
    answers = answers_map(db, user.id, pillar_key)
    calculated = progress_percent(answers, pillar["questions"])
    pp = progress_row(db, user.id, pillar_key)
    progress = max(calculated, pp.score if pp else 0)
    nxt = next_question(answers, pillar["questions"])

    report = db.scalar(select(PillarReport).where(
        PillarReport.user_id == user.id,
        PillarReport.pillar_key == pillar_key,
    ))

    return {
        "pillar_key": pillar_key,
        "pillar_name": pillar["name"],
        "unlocked": is_open,
        "requires": pillar.get("requires"),
        "progress": progress,
        "status": "validated" if nxt is None else "in_diagnosis",
        "ai_configured": configured(),
        "next_question": nxt if is_open else None,
        "questions": pillar["questions"] if is_open else [],
        "answers": answers,
        "report_generated": report is not None,
        "redo_in_progress": active_round(db, user.id, pillar_key) is not None,
    }


@router.post("/{pillar_key}/answer", response_model=DiagnosisAnswerResponse)
def answer_pillar(
    pillar_key: str,
    data: DiagnosisAnswerRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(status_code=404, detail="Pilar não encontrado")
    if not unlocked(db, user.id, pillar):
        raise HTTPException(
            status_code=409,
            detail=f"Conclua primeiro o pilar {pillar.get('requires')}",
        )

    question = next(
        (q for q in pillar["questions"] if q["key"] == data.question_key),
        None,
    )
    if not question:
        raise HTTPException(status_code=404, detail="Pergunta não encontrada")

    if getattr(data, 'audio_id', None):
        attach_voice(db, user.id, pillar_key, data.question_key,
                     data.audio_id, data.question_key, data.answer_text)
    previous = answers_map(db, user.id, pillar_key)
    local_score, local_status = evaluate_answer(question, data.answer_text)
    final_score, final_status = local_score, local_status
    ai_analysis = None

    # Só chama IA quando a resposta passou no mínimo local. Assim evitamos
    # gastar uma chamada para respostas vazias/curtíssimas.
    if configured() and local_status != "needs_review":
        try:
            mentor_ctx = mentor_context_for_user(
                db,
                getattr(user, "approved_by_user_id", None),
            )
            ai_analysis = analyze(
                pillar_key,
                pillar["name"],
                question,
                data.answer_text,
                previous,
                mentor_ctx,
            )
            if ai_analysis["decision"] == "accepted" or int(ai_analysis.get("quality_score", 0)) >= 65:
                final_score = question["weight"]
                final_status = "answered_ai"
                if ai_analysis["decision"] != "accepted":
                    ai_analysis["decision"] = "accepted"
                    ai_analysis["follow_up_question"] = None
                    ai_analysis["feedback"] = ai_analysis.get("feedback") or "Resposta suficiente para avançar."
            else:
                ratio = max(0, min(100, ai_analysis["quality_score"])) / 100
                final_score = max(1, round(question["weight"] * ratio))
                final_status = "needs_review"
        except Exception as exc:
            ai_analysis = {
                "mode": "fallback",
                "quality_score": 100,
                "decision": "accepted",
                "feedback": "A avaliação por IA ficou temporariamente indisponível; a validação local foi usada.",
                "follow_up_question": None,
                "extracted_facts": [],
                "risks": [f"AI provider error: {type(exc).__name__}"],
                "model_used": settings.openai_model,
            }
            final_score = question["weight"]
            final_status = "answered"

    row = db.scalar(select(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user.id,
        DiagnosisAnswer.pillar_key == pillar_key,
        DiagnosisAnswer.question_key == data.question_key,
    ))

    if not row:
        row = DiagnosisAnswer(
            user_id=user.id,
            pillar_key=pillar_key,
            question_key=data.question_key,
            answer_text=data.answer_text,
            score=final_score,
            status=final_status,
        )
        db.add(row)
    else:
        row.answer_text = data.answer_text
        row.score = final_score
        row.status = final_status

    if ai_analysis:
        db.add(DiagnosisAIAnalysis(
            user_id=user.id,
            pillar_key=pillar_key,
            question_key=data.question_key,
            quality_score=ai_analysis["quality_score"],
            decision=ai_analysis["decision"],
            feedback=ai_analysis["feedback"],
            follow_up_question=ai_analysis.get("follow_up_question"),
            extracted_facts_json=json.dumps(ai_analysis.get("extracted_facts", []), ensure_ascii=False),
            risks_json=json.dumps(ai_analysis.get("risks", []), ensure_ascii=False),
            model_used=ai_analysis.get("model_used"),
            mode=ai_analysis.get("mode", "fallback"),
        ))

    db.commit()

    answers = answers_map(db, user.id, pillar_key)
    calculated = progress_percent(answers, pillar["questions"])
    nxt = next_question(answers, pillar["questions"])

    pp = progress_row(db, user.id, pillar_key)
    if pp is None:
        pp = PillarProgress(user_id=user.id, pillar_key=pillar_key, score=0, status="not_started")
        db.add(pp)
    if pp:
        # Progresso nunca retrocede.
        pp.score = max(pp.score or 0, calculated)
        if nxt is None:
            pp.score = 100
            pp.status = "validated"
        elif pp.status != "validated":
            pp.status = "in_diagnosis"
        db.commit()
        progress = pp.score
    else:
        progress = calculated

    return DiagnosisAnswerResponse(
        saved=True,
        score=final_score,
        progress=progress,
        status=final_status,
        next_question=nxt,
        ai_analysis=ai_analysis,
    )


@router.post("/{pillar_key}/answer-coach")
def answer_coach(pillar_key: str, data: AnswerCoachRequest, user: User = Depends(current_user), db: Session = Depends(get_db)):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(404, "Pilar não encontrado")
    question = next((q for q in pillar["questions"] if q["key"] == data.question_key), None)
    if not question:
        raise HTTPException(404, "Pergunta não encontrada")
    mentor_ctx = mentor_context_for_user(db, getattr(user, "approved_by_user_id", None))
    try:
        return coach_answer(pillar["name"], question, data.answer_text, data.message, data.history, mentor_ctx)
    except Exception:
        return {"reply":"Posso te ajudar a tornar essa resposta mais específica. Explique o que você já faz hoje, dê um exemplo real quando existir e diga o que pretende melhorar. Não precisa buscar uma resposta perfeita; precisamos apenas de informação suficiente e verdadeira para este pilar."}


PILLAR_ORDER=["positioning","promise","funnel","closing"]
def previous_pillar_report_ready(db,user_id,pillar_key):
    if pillar_key=="positioning":
        return True
    idx=PILLAR_ORDER.index(pillar_key)
    prev=PILLAR_ORDER[idx-1]
    rep=db.scalar(select(PillarReport).where(
        PillarReport.user_id==user_id,
        PillarReport.pillar_key==prev
    ))
    return bool(rep and rep.ready_for_next=="true")


def _report_snapshot(report):
    if not report:
        return {}
    return {
        "summary": report.summary,
        "perceived_authority": report.perceived_authority,
        "practical_plan": json.loads(report.practical_plan_json or "[]"),
        "strengths": json.loads(report.strengths_json or "[]"),
        "gaps": json.loads(report.gaps_json or "[]"),
        "missing_information": json.loads(report.missing_information_json or "[]"),
        "completion_question": report.completion_question,
        "ready_for_next": report.ready_for_next == "true",
        "model_used": report.model_used,
        "updated_at": report.updated_at.isoformat() if report.updated_at else None,
    }


@router.post("/{pillar_key}/redo")
def redo_pillar(pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(404, "Pilar não encontrado")
    if active_round(db, user.id, pillar_key):
        raise HTTPException(409, "Já existe uma nova avaliação deste pilar em andamento")

    current_answers = answers_map(db, user.id, pillar_key)
    report = db.scalar(select(PillarReport).where(
        PillarReport.user_id == user.id, PillarReport.pillar_key == pillar_key))
    if not current_answers and not report:
        raise HTTPException(409, "Este pilar ainda não possui uma avaliação para refazer")

    round_row = PillarAssessmentRound(
        user_id=user.id,
        pillar_key=pillar_key,
        status="in_progress",
        previous_answers_json=json.dumps(current_answers, ensure_ascii=False),
        previous_report_json=json.dumps(_report_snapshot(report), ensure_ascii=False),
    )
    db.add(round_row)
    db.execute(delete(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user.id, DiagnosisAnswer.pillar_key == pillar_key))
    db.execute(delete(DiagnosisAIAnalysis).where(
        DiagnosisAIAnalysis.user_id == user.id, DiagnosisAIAnalysis.pillar_key == pillar_key))
    pp = progress_row(db, user.id, pillar_key)
    if pp:
        pp.score = 0
        pp.status = "in_diagnosis"
    db.commit()
    return {"ok": True, "round_id": round_row.id, "message": "Nova avaliação iniciada. A avaliação anterior permanece preservada até a conclusão."}


@router.post("/{pillar_key}/cancel-redo")
def cancel_redo_pillar(pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(404, "Pilar não encontrado")
    round_row = active_round(db, user.id, pillar_key)
    if not round_row:
        raise HTTPException(409, "Não existe uma nova avaliação em andamento")

    previous = json.loads(round_row.previous_answers_json or "{}")
    db.execute(delete(DiagnosisAnswer).where(
        DiagnosisAnswer.user_id == user.id, DiagnosisAnswer.pillar_key == pillar_key))
    db.execute(delete(DiagnosisAIAnalysis).where(
        DiagnosisAIAnalysis.user_id == user.id, DiagnosisAIAnalysis.pillar_key == pillar_key))
    for question_key, saved in previous.items():
        db.add(DiagnosisAnswer(
            user_id=user.id,
            pillar_key=pillar_key,
            question_key=question_key,
            answer_text=saved.get("answer_text", ""),
            score=saved.get("score", 0),
            status=saved.get("status", "answered"),
        ))

    pp = progress_row(db, user.id, pillar_key)
    restored_progress = progress_percent(previous, pillar["questions"])
    if pp is None:
        pp = PillarProgress(user_id=user.id, pillar_key=pillar_key, score=restored_progress, status="not_started")
        db.add(pp)
    pp.score = restored_progress
    pp.status = "validated" if next_question(previous, pillar["questions"]) is None else ("in_diagnosis" if restored_progress else "not_started")
    round_row.status = "cancelled"
    round_row.completed_at = datetime.utcnow()
    db.commit()
    return {"ok": True, "message": "Nova avaliação cancelada. As respostas anteriores foram restauradas."}


@router.get("/{pillar_key}/history")
def pillar_history(pillar_key: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    pillar = get_pillar(pillar_key)
    if not pillar:
        raise HTTPException(404, "Pilar não encontrado")
    rounds = db.scalars(select(PillarAssessmentRound).where(
        PillarAssessmentRound.user_id == user.id,
        PillarAssessmentRound.pillar_key == pillar_key,
    ).order_by(PillarAssessmentRound.started_at.desc())).all()
    items=[]
    for r in rounds:
        items.append({
            "id": r.id, "status": r.status,
            "started_at": r.started_at, "completed_at": r.completed_at,
            "answers": json.loads(r.previous_answers_json or "{}"),
            "report": json.loads(r.previous_report_json or "{}"),
        })
    return {"pillar_key": pillar_key, "pillar_name": pillar["name"], "history": items}
