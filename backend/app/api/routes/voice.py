import io
import wave
from uuid import UUID
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from openai import OpenAI
from sqlalchemy import select, delete, func
from sqlalchemy.orm import Session
from app.api.deps import active_mentee_or_mentor
from app.db.session import get_db
from app.core.config import settings
from app.models.user import User
from app.models.conversation import VoiceAnswer
from app.models.pillar_report import PillarReport
from app.ai.methodology_full import get_pillar
from app.api.routes.pillars import unlocked

router = APIRouter(prefix='/voice', tags=['voice'])
MAX_BYTES = 10 * 1024 * 1024


def audio_duration(raw):
    try:
        with wave.open(io.BytesIO(raw), 'rb') as audio:
            duration = audio.getnframes() / audio.getframerate()
            valid = (audio.getnchannels() == 1 and audio.getsampwidth() == 2
                     and audio.getframerate() == 16000 and 0.5 <= duration <= 301)
            frames = audio.readframes(audio.getnframes())
            valid = valid and len(frames) == audio.getnframes() * 2
    except (wave.Error, EOFError, ZeroDivisionError):
        valid = False
    if not valid:
        raise HTTPException(422, 'Grave um áudio de até 5 minutos pelo aplicativo.')
    return duration


def metadata(row):
    return dict(id=row.id, pillar_key=row.pillar_key, question_key=row.question_key,
                question_text=row.question_text, duration=row.duration,
                transcript=row.transcript, submitted_text=row.submitted_text,
                created_at=row.created_at)


def authorized_owner(db, user, owner_id):
    if owner_id == user.id:
        return
    owner = db.get(User, owner_id)
    if not owner or user.role not in {'mentor', 'admin'} or (
        user.role != 'admin' and owner.approved_by_user_id != user.id
    ):
        raise HTTPException(403, 'Sem acesso a este áudio.')


@router.put('/{audio_id}')
async def upload(audio_id: UUID, pillar_key: str, question_key: str, request: Request,
                 user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    pillar = get_pillar(pillar_key)
    if not pillar or not unlocked(db, user.id, pillar):
        raise HTTPException(409, 'Este pilar ainda não está disponível.')
    if question_key == 'plan_chat':
        report = db.scalar(select(PillarReport).where(PillarReport.user_id == user.id, PillarReport.pillar_key == pillar_key))
        if not report:
            raise HTTPException(409, 'Gere o plano antes de conversar sobre ele.')
        question_text = 'Dúvida sobre o plano'
    elif question_key == 'report_complement':
        report = db.scalar(select(PillarReport).where(PillarReport.user_id == user.id, PillarReport.pillar_key == pillar_key))
        if not report or report.ready_for_next == 'true':
            raise HTTPException(409, 'Não há complemento pendente neste plano.')
        question_text = report.completion_question or 'Complemento do plano'
    else:
        question = next((q for q in pillar['questions'] if q['key'] == question_key), None)
        if not question:
            raise HTTPException(404, 'Pergunta não encontrada.')
        question_text = question['question']
    # Serialize quotas and retry keys per owner without exposing another user's record.
    db.scalar(select(User).where(User.id == user.id).with_for_update())
    previous = db.get(VoiceAnswer, str(audio_id))
    if previous:
        if previous.user_id != user.id or previous.pillar_key != pillar_key or previous.question_key != question_key:
            raise HTTPException(409, 'Identificação de gravação inválida.')
        return metadata(previous)
    db.execute(delete(VoiceAnswer).where(VoiceAnswer.user_id == user.id,
        VoiceAnswer.answer_key.is_(None), VoiceAnswer.created_at < datetime.utcnow() - timedelta(days=1)))
    pending = db.scalar(select(func.count()).select_from(VoiceAnswer).where(
        VoiceAnswer.user_id == user.id, VoiceAnswer.answer_key.is_(None))) or 0
    total = db.scalar(select(func.sum(VoiceAnswer.byte_count)).where(VoiceAnswer.user_id == user.id)) or 0
    if pending >= 5 or total >= 200 * 1024 * 1024:
        raise HTTPException(409, 'Limite de gravações atingido. Remova rascunhos antes de gravar novamente.')
    raw = bytearray()
    async for chunk in request.stream():
        raw.extend(chunk)
        if len(raw) > MAX_BYTES or len(raw) + total > 200 * 1024 * 1024:
            raise HTTPException(413, 'O áudio excede o limite de armazenamento.')
    duration = audio_duration(bytes(raw))
    row = VoiceAnswer(id=str(audio_id), user_id=user.id, pillar_key=pillar_key,
        question_key=question_key, question_text=question_text, audio=bytes(raw),
        byte_count=len(raw), duration=duration)
    db.add(row)
    db.commit()
    db.refresh(row)
    return metadata(row)


@router.post('/{audio_id}/transcribe')
def transcribe(audio_id: UUID, user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    row = db.scalar(select(VoiceAnswer).where(VoiceAnswer.id == str(audio_id), VoiceAnswer.user_id == user.id).with_for_update())
    if not row:
        raise HTTPException(404, 'Gravação não encontrada.')
    if row.transcript:
        return metadata(row)
    if not settings.ai_enabled or not settings.openai_api_key:
        raise HTTPException(503, 'Transcrição indisponível. O áudio está salvo; você pode digitar a resposta ou tentar novamente.')
    try:
        result = OpenAI(api_key=settings.openai_api_key, timeout=90, max_retries=0).audio.transcriptions.create(
            model=settings.openai_transcription_model, file=('resposta.wav', row.audio, 'audio/wav'), language='pt')
        row.transcript = result.text.strip()
        if not row.transcript:
            raise ValueError('empty')
    except Exception:
        db.rollback()
        raise HTTPException(503, 'Não consegui transcrever. Seu áudio foi mantido. Tente novamente ou digite a resposta.')
    db.commit()
    return metadata(row)


@router.get('')
def list_audio(pillar_key: str, owner_id: str | None = None,
               user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    owner_id = owner_id or user.id
    authorized_owner(db, user, owner_id)
    rows = db.scalars(select(VoiceAnswer).where(VoiceAnswer.user_id == owner_id,
        VoiceAnswer.pillar_key == pillar_key, VoiceAnswer.answer_key.is_not(None))
        .order_by(VoiceAnswer.created_at)).all()
    return [metadata(row) for row in rows]


@router.get('/drafts')
def drafts(pillar_key: str, question_key: str,
           user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    rows = db.scalars(select(VoiceAnswer).where(VoiceAnswer.user_id == user.id,
        VoiceAnswer.pillar_key == pillar_key, VoiceAnswer.question_key == question_key,
        VoiceAnswer.answer_key.is_(None)).order_by(VoiceAnswer.created_at.desc())).all()
    return [metadata(row) for row in rows]


@router.get('/{audio_id}/audio')
def play(audio_id: UUID, user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    row = db.get(VoiceAnswer, str(audio_id))
    if not row:
        raise HTTPException(404, 'Gravação não encontrada.')
    authorized_owner(db, user, row.user_id)
    if row.user_id != user.id and row.answer_key is None:
        raise HTTPException(403, 'Esta gravação ainda não foi enviada.')
    return Response(content=row.audio, media_type='audio/wav', headers={'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'})


@router.delete('/{audio_id}')
def discard(audio_id: UUID, user: User = Depends(active_mentee_or_mentor), db: Session = Depends(get_db)):
    row = db.scalar(select(VoiceAnswer).where(VoiceAnswer.id == str(audio_id), VoiceAnswer.user_id == user.id).with_for_update())
    if row and row.answer_key:
        raise HTTPException(409, 'Esta gravação já faz parte de uma resposta enviada.')
    if row:
        db.delete(row)
        db.commit()
    return {'ok': True}
