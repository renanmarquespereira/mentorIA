import json
from app.ai.mentor_voice import MENTOR_VOICE
from openai import OpenAI
from app.core.config import settings
from app.knowledge.loader import compact_methodology

REPORT_SCHEMA = {
    "type": "object",
    "properties": {
        "executive_summary": {"type": "string"},
        "stage_summary": {"type": "string"},
        "strengths": {"type": "array", "items": {"type": "string"}},
        "gaps": {"type": "array", "items": {"type": "string"}},
        "priorities": {"type": "array", "items": {"type": "string"}},
        "pillar_summaries": {
            "type": "object",
            "properties": {
                "positioning": {"type": "string"},
                "promise": {"type": "string"},
                "funnel": {"type": "string"},
                "closing": {"type": "string"}
            },
            "required": ["positioning","promise","funnel","closing"],
            "additionalProperties": False
        },
        "recommendations": {"type": "array", "items": {"type": "string"}},
        "action_plan": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "pillar_key": {"type": "string", "enum": ["positioning","promise","funnel","closing","general"]},
                    "priority": {"type": "string", "enum": ["high","medium","low"]}
                },
                "required": ["title","description","pillar_key","priority"],
                "additionalProperties": False
            }
        }
    },
    "required": [
        "executive_summary","stage_summary","strengths","gaps","priorities",
        "pillar_summaries","recommendations","action_plan"
    ],
    "additionalProperties": False
}

RULES = """Você é a mentora estratégica do aplicativo.
Use como fonte principal a metodologia estruturada fornecida e as respostas reais do educador.
Nunca invente fatos, clientes, resultados, depoimentos, faturamento, autoridade ou certificações.
Diferencie claramente situação atual de intenção futura.
Priorize ações compatíveis com o estágio real do educador.
Se o educador ainda não possui clientes, não recomende prova social como se já existisse: recomende conquistar primeiros resultados e depois coletar depoimentos.
Não recomende tráfego pago como prioridade se oferta, aquisição orgânica ou processo comercial ainda não estiverem minimamente estruturados.
As recomendações devem respeitar os quatro pilares e transformar diagnóstico em execução prática.
Evite conselhos genéricos. Use os dados informados pelo educador.
Escreva os textos em português. Considere os planos validados e as revisões humanas da mentora.
Respeite a metodologia personalizada da mentora sem inventar fatos.
Crie ações concretas e verificáveis. Não invente prazos ou compromissos assumidos pela pessoa.
"""

def configured():
    return bool(settings.ai_enabled and settings.openai_api_key and settings.openai_api_key.strip())

def generate_report(answers_by_pillar, commercial_context, pillar_reports=None, mentor_context=None):
    if not configured():
        raise RuntimeError("OPENAI_API_KEY não configurada")

    payload = {
        "methodology": compact_methodology(),
        "educator_answers": answers_by_pillar,
        "commercial_context": commercial_context,
        "validated_pillar_reports": pillar_reports or {},
        "mentor_preferences": mentor_context or {},
    }

    response = OpenAI(api_key=settings.openai_api_key).responses.create(
        model=settings.openai_model,
        instructions=MENTOR_VOICE + "\n" + RULES,
        input=json.dumps(payload, ensure_ascii=False),
        text={
            "format": {
                "type": "json_schema",
                "name": "strategic_report",
                "strict": True,
                "schema": REPORT_SCHEMA
            }
        },
        store=False
    )
    result = json.loads(response.output_text)
    result["model_used"] = settings.openai_model
    result["mode"] = "openai"
    return result
