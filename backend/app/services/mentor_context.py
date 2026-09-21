import json
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.mentor_settings import MentorSettings

def mentor_context_for_user(db: Session, mentor_user_id: str | None):
    if not mentor_user_id:
        return {}
    row = db.scalar(select(MentorSettings).where(MentorSettings.mentor_user_id == mentor_user_id))
    if not row:
        return {}
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
