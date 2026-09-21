from fastapi import HTTPException
from sqlalchemy import select
from app.models.conversation import VoiceAnswer


def attach_voice(db, user_id, pillar_key, question_key, audio_id, answer_key, text):
    if not audio_id:
        return
    row = db.scalar(select(VoiceAnswer).where(VoiceAnswer.id == audio_id).with_for_update())
    if not row or row.user_id != user_id or row.pillar_key != pillar_key or row.question_key != question_key:
        raise HTTPException(422, 'O áudio não pertence a esta resposta.')
    if row.answer_key and (row.answer_key != answer_key or row.submitted_text != text):
        raise HTTPException(409, 'Este áudio já foi enviado. Grave outro para uma nova resposta.')
    row.answer_key = answer_key
    row.submitted_text = text
