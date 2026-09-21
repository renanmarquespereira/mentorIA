import json
from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select,delete
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.educator import PillarProgress
from app.models.diagnosis import DiagnosisAnswer
from app.models.ai_analysis import DiagnosisAIAnalysis
from app.models.strategy import PositioningSynthesis,ActionPlanItem
from app.schemas.diagnosis import DiagnosisAnswerRequest,DiagnosisAnswerResponse,PositioningSynthesisResponse
from app.ai.pillar1 import PILLAR_KEY,QUESTIONS,evaluate_answer,progress_percent,next_question
from app.ai.openai_service import is_configured,analyze_positioning_answer,synthesize_positioning
from app.core.config import settings
router=APIRouter(prefix="/diagnosis",tags=["diagnosis"])
def amap(db,uid):
    rows=db.scalars(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id==uid,DiagnosisAnswer.pillar_key==PILLAR_KEY)).all();return {r.question_key:{"answer_text":r.answer_text,"score":r.score,"status":r.status} for r in rows}
@router.get("/positioning")
def getpos(user:User=Depends(current_user),db:Session=Depends(get_db)):
    a=amap(db,user.id);p=progress_percent(a);n=next_question(a);return {"pillar_key":PILLAR_KEY,"pillar_name":"Posicionamento Único","progress":p,"status":"validated" if p==100 and n is None else "in_diagnosis","ai_configured":is_configured(),"next_question":n,"answers":a}
@router.post("/positioning/answer",response_model=DiagnosisAnswerResponse)
def answer(data:DiagnosisAnswerRequest,user:User=Depends(current_user),db:Session=Depends(get_db)):
    q=next((q for q in QUESTIONS if q["key"]==data.question_key),None)
    if not q: raise HTTPException(404,"Pergunta não encontrada")
    prev=amap(db,user.id);bs,bst=evaluate_answer(q,data.answer_text);ai=None;fs,st=bs,bst
    if is_configured():
        try:
            ai=analyze_positioning_answer(q,data.answer_text,prev)
            if ai["decision"]=="accepted": fs=q["weight"];st="answered_ai"
            else: fs=max(1,round(q["weight"]*max(0,min(100,ai["quality_score"]))/100));st="needs_review"
        except Exception as exc:
            ai={"mode":"fallback","quality_score":round((bs/q["weight"])*100) if q["weight"] else 0,"decision":"accepted" if bst!="needs_review" else "needs_deeper_answer","feedback":"A IA ficou temporariamente indisponível; validação local usada.","follow_up_question":q["question"] if bst=="needs_review" else None,"extracted_facts":[],"risks":[f"AI provider error: {type(exc).__name__}"],"model_used":settings.openai_model}
    row=db.scalar(select(DiagnosisAnswer).where(DiagnosisAnswer.user_id==user.id,DiagnosisAnswer.pillar_key==PILLAR_KEY,DiagnosisAnswer.question_key==data.question_key))
    if not row: row=DiagnosisAnswer(user_id=user.id,pillar_key=PILLAR_KEY,question_key=data.question_key,answer_text=data.answer_text,score=fs,status=st);db.add(row)
    else: row.answer_text=data.answer_text;row.score=fs;row.status=st
    if ai: db.add(DiagnosisAIAnalysis(user_id=user.id,pillar_key=PILLAR_KEY,question_key=data.question_key,quality_score=ai["quality_score"],decision=ai["decision"],feedback=ai["feedback"],follow_up_question=ai.get("follow_up_question"),extracted_facts_json=json.dumps(ai.get("extracted_facts",[]),ensure_ascii=False),risks_json=json.dumps(ai.get("risks",[]),ensure_ascii=False),model_used=ai.get("model_used"),mode=ai.get("mode","fallback")))
    db.commit();a=amap(db,user.id);p=progress_percent(a);n=next_question(a)
    pp=db.scalar(select(PillarProgress).where(PillarProgress.user_id==user.id,PillarProgress.pillar_key==PILLAR_KEY))
    if pp: pp.score=p;pp.status="validated" if p==100 and n is None else "in_diagnosis";db.commit()
    return DiagnosisAnswerResponse(saved=True,score=fs,progress=p,status=st,next_question=n,ai_analysis=ai)
@router.get("/positioning/ai-history")
def hist(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(DiagnosisAIAnalysis).where(DiagnosisAIAnalysis.user_id==user.id,DiagnosisAIAnalysis.pillar_key==PILLAR_KEY).order_by(DiagnosisAIAnalysis.created_at.desc())).all();return [{"question_key":r.question_key,"quality_score":r.quality_score,"decision":r.decision,"feedback":r.feedback,"follow_up_question":r.follow_up_question,"extracted_facts":json.loads(r.extracted_facts_json or "[]"),"risks":json.loads(r.risks_json or "[]"),"model_used":r.model_used,"mode":r.mode,"created_at":r.created_at} for r in rows]
@router.post("/positioning/synthesize",response_model=PositioningSynthesisResponse)
def synth(user:User=Depends(current_user),db:Session=Depends(get_db)):
    a=amap(db,user.id)
    if len(a)<len(QUESTIONS): return PositioningSynthesisResponse(ready=False,mode="not_ready",gaps=["Conclua todas as perguntas."],next_actions=["Continue o diagnóstico."])
    if not is_configured(): return PositioningSynthesisResponse(ready=False,mode="ai_not_configured",gaps=["OPENAI_API_KEY não configurada."],next_actions=["Configure a chave no .env e reinicie."],model_used=settings.openai_model)
    try:
        result=synthesize_positioning(a)
        row=db.scalar(select(PositioningSynthesis).where(PositioningSynthesis.user_id==user.id))
        if not row:
            row=PositioningSynthesis(user_id=user.id);db.add(row)
        row.positioning_statement=result["positioning_statement"];row.authority_summary=result["authority_summary"];row.values_summary=result["values_summary"];row.transformation_summary=result["transformation_summary"];row.strengths_json=json.dumps(result.get("strengths",[]),ensure_ascii=False);row.gaps_json=json.dumps(result.get("gaps",[]),ensure_ascii=False);row.next_actions_json=json.dumps(result.get("next_actions",[]),ensure_ascii=False);row.model_used=result.get("model_used");row.mode=result.get("mode","openai")
        db.execute(delete(ActionPlanItem).where(ActionPlanItem.user_id==user.id,ActionPlanItem.pillar_key==PILLAR_KEY))
        for i,action in enumerate(result.get("next_actions",[]),start=1): db.add(ActionPlanItem(user_id=user.id,pillar_key=PILLAR_KEY,title=action[:220],description=action,priority="high" if i<=2 else "medium",status="pending",sort_order=i))
        db.commit();return PositioningSynthesisResponse(ready=True,**result)
    except Exception as exc: return PositioningSynthesisResponse(ready=False,mode="fallback",gaps=[f"Falha na síntese: {type(exc).__name__}"],next_actions=["Confira chave, modelo e logs."],model_used=settings.openai_model)
