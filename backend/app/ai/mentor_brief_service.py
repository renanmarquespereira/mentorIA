import json
from openai import OpenAI

from app.ai.mentor_voice import MENTOR_VOICE
from app.core.config import settings

BRIEF_SCHEMA = {
    "type": "object",
    "properties": {
        "intelligent_summary": {"type": "string"},
        "current_moment": {"type": "string"},
        "progress_highlights": {"type": "array", "items": {"type": "string"}},
        "attention_points": {"type": "array", "items": {"type": "string"}},
        "next_mentoring_objective": {"type": "string"},
        "suggested_agenda": {"type": "array", "items": {"type": "string"}},
        "questions_to_ask": {"type": "array", "items": {"type": "string"}},
        "actions_to_review": {"type": "array", "items": {"type": "string"}},
        "mentor_notes": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "intelligent_summary", "current_moment", "progress_highlights",
        "attention_points", "next_mentoring_objective", "suggested_agenda",
        "questions_to_ask", "actions_to_review", "mentor_notes",
    ],
    "additionalProperties": False,
}

RULES = """Gere um briefing privado para a mentora preparar a próxima sessão com a mentorada.
Use somente os dados fornecidos. Nunca invente resultados, clientes, faturamento, decisões, compromissos ou fatos.
O resumo inteligente deve condensar evolução, momento atual, decisões e bloqueios relevantes.
A preparação da próxima mentoria deve ser prática: objetivo principal, pauta sugerida, perguntas de aprofundamento e ações que merecem revisão.
Diferencie fato registrado de ponto que precisa ser confirmado na sessão. Quando faltar informação, formule uma pergunta em vez de assumir.
Dê prioridade ao que mudou, ao que está pendente, atrasado, em andamento ou contraditório com os planos validados.
Considere as conversas com a IA como contexto, sem tratar sugestões da IA como decisões já tomadas pela mentorada.
Quando houver check-in pré-sessão, dê destaque aos avanços, bloqueios, tema desejado e nível de confiança informado pela própria mentorada.
Respeite a metodologia e as preferências da mentora fornecidas no contexto.
Escreva em português do Brasil, de forma objetiva e útil para condução de uma mentoria humana.
"""


def configured():
    return bool(settings.ai_enabled and settings.openai_api_key and settings.openai_api_key.strip())


def generate_mentor_brief(context: dict):
    if not configured():
        raise RuntimeError("OPENAI_API_KEY não configurada")
    response = OpenAI(api_key=settings.openai_api_key).responses.create(
        model=settings.openai_model,
        instructions=MENTOR_VOICE + "\n" + RULES,
        input=json.dumps(context, ensure_ascii=False, default=str),
        text={
            "format": {
                "type": "json_schema",
                "name": "mentor_mentee_brief",
                "strict": True,
                "schema": BRIEF_SCHEMA,
            }
        },
        store=False,
    )
    result = json.loads(response.output_text)
    result["model_used"] = settings.openai_model
    return result
