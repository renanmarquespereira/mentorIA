import json
from app.ai.mentor_voice import MENTOR_VOICE
from openai import OpenAI
from app.core.config import settings
from app.knowledge.loader import compact_methodology

SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "perceived_authority": {"type": "string"},
        "strengths": {"type": "array", "items": {"type": "string"}},
        "gaps": {"type": "array", "items": {"type": "string"}},
        "missing_information": {"type": "array", "items": {"type": "string"}},
        "ready_for_next": {"type": "boolean"},
        "completion_question": {"type": ["string", "null"]},
        "practical_plan": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "priority": {"type": "string", "enum": ["high", "medium", "low"]}
                },
                "required": ["title", "description", "priority"],
                "additionalProperties": False
            }
        }
    },
    "required": [
        "summary","perceived_authority","strengths","gaps","missing_information",
        "ready_for_next","completion_question","practical_plan"
    ],
    "additionalProperties": False
}

PILLAR_BOUNDARIES = {
    "positioning": """
Analise SOMENTE Posicionamento Único: trajetória, formação, experiência, resultados reais,
transformação pessoal, vida pessoal relevante ao posicionamento, valores, percepção desejada,
diferenciais, história, autoridade percebida, coerência pessoal/profissional, o que faz e a
transformação que pode comunicar legitimamente.

NÃO peça persona detalhada, dores/desejos comerciais, promessa final, precificação, funil,
tráfego, conteúdo, SPIN, objeções de venda, follow-up ou métricas.
""",
    "promise": """
Analise SOMENTE Promessa Atrativa: produto principal, ticket, público, persona, dores,
desejos, objeções, Ponto A, Ponto B, promessa e super promessa.
NÃO avance para funil, aquisição, tráfego, SPIN, follow-up ou métricas.
""",
    "funnel": """
Analise SOMENTE Funil de Venda Poderoso: aquisição, orgânico, tráfego pago, consciência,
funil atual, volume, calls, origem e previsibilidade.
NÃO transforme em roteiro de fechamento, SPIN detalhado, follow-up ou tratamento de objeções.
""",
    "closing": """
Analise SOMENTE Fechamento Irrecusável: confiança em vendas, canal, SPIN, objeções,
follow-up, downgrade, depoimentos, indicações e métricas comerciais.
"""
}

BASE_RULES = """
Você avalia UM pilar por vez.
- Só bloqueie avanço por informação ESSENCIAL ao pilar atual.
- Se faltar algo essencial: ready_for_next=false e faça EXATAMENTE UMA pergunta complementar.
- Não antecipe módulos futuros.
- Otimizações opcionais vão para o plano prático, não para lacunas bloqueantes.
- No Posicionamento, combine vida pessoal e profissional apenas quando isso for legítimo e desejado.
- Se a pessoa disser que transformou clientes, mas não explicar resultados, aprofunde antes de concluir autoridade.
- Nunca invente clientes, resultados, certificações, história pessoal ou autoridade.
- As preferências da mentora têm prioridade sobre heurísticas genéricas, desde que não contrariem fatos.
"""

def configured():
    return bool(settings.ai_enabled and settings.openai_api_key and settings.openai_api_key.strip())

def generate_pillar_report(pillar_key, answers, mentor_context=None):
    if not configured():
        raise RuntimeError("OPENAI_API_KEY não configurada")

    methodology = compact_methodology()
    payload = {
        "pillar_key": pillar_key,
        "pillar_boundary": PILLAR_BOUNDARIES.get(pillar_key, ""),
        "methodology": methodology["pillars"].get(pillar_key, {}),
        "mentor_preferences": mentor_context or {},
        "answers": answers
    }

    response = OpenAI(api_key=settings.openai_api_key).responses.create(
        model=settings.openai_model,
        instructions=MENTOR_VOICE + "\n" + BASE_RULES + "\n" + PILLAR_BOUNDARIES.get(pillar_key, ""),
        input=json.dumps(payload, ensure_ascii=False),
        text={"format":{
            "type":"json_schema",
            "name":"pillar_report",
            "strict":True,
            "schema":SCHEMA
        }},
        store=False
    )
    data = json.loads(response.output_text)
    data["model_used"] = settings.openai_model
    return data
