import json
from openai import OpenAI
from app.core.config import settings

ANALYSIS_SCHEMA={"type":"object","properties":{"quality_score":{"type":"integer","minimum":0,"maximum":100},"decision":{"type":"string","enum":["accepted","needs_deeper_answer"]},"feedback":{"type":"string"},"follow_up_question":{"type":["string","null"]},"extracted_facts":{"type":"array","items":{"type":"string"}},"risks":{"type":"array","items":{"type":"string"}}},"required":["quality_score","decision","feedback","follow_up_question","extracted_facts","risks"],"additionalProperties":False}
SYNTHESIS_SCHEMA={"type":"object","properties":{"positioning_statement":{"type":"string"},"authority_summary":{"type":"string"},"values_summary":{"type":"string"},"transformation_summary":{"type":"string"},"strengths":{"type":"array","items":{"type":"string"}},"gaps":{"type":"array","items":{"type":"string"}},"next_actions":{"type":"array","items":{"type":"string"}}},"required":["positioning_statement","authority_summary","values_summary","transformation_summary","strengths","gaps","next_actions"],"additionalProperties":False}
RULES="""Avalie o Pilar 1 — Posicionamento Único para educadores financeiros. Nunca invente clientes, resultados, depoimentos, formação, experiência ou autoridade. Diferencie fatos declarados de inferências. Um educador sem clientes pode construir autoridade legítima por formação, trajetória, experiência profissional e transformação pessoal real. Se a resposta for vaga ou genérica, peça aprofundamento. Não avalie estilo de escrita; avalie utilidade estratégica. Não crie promessa de resultado sem evidência."""

def is_configured(): return bool(settings.ai_enabled and settings.openai_api_key and settings.openai_api_key.strip())
def client(): return OpenAI(api_key=settings.openai_api_key)
def analyze_positioning_answer(question,answer,previous_answers):
    if not is_configured(): raise RuntimeError("OPENAI_API_KEY não configurada")
    context={k:v.get("answer_text","") for k,v in previous_answers.items() if v.get("answer_text")}
    payload={"question":question["question"],"question_key":question["key"],"answer":answer,"previous_answers":context}
    r=client().responses.create(model=settings.openai_model,instructions=RULES,input=json.dumps(payload,ensure_ascii=False),text={"format":{"type":"json_schema","name":"positioning_answer_analysis","strict":True,"schema":ANALYSIS_SCHEMA}},store=False)
    data=json.loads(r.output_text);data["model_used"]=settings.openai_model;data["mode"]="openai";return data
def synthesize_positioning(answers):
    if not is_configured(): raise RuntimeError("OPENAI_API_KEY não configurada")
    clean={k:v.get("answer_text","") for k,v in answers.items() if v.get("answer_text")}
    r=client().responses.create(model=settings.openai_model,instructions=RULES+" Gere uma síntese realista do posicionamento, sem inventar persona que só será definida no Pilar 2. Registre lacunas e próximas ações.",input=json.dumps({"answers":clean},ensure_ascii=False),text={"format":{"type":"json_schema","name":"positioning_synthesis","strict":True,"schema":SYNTHESIS_SCHEMA}},store=False)
    data=json.loads(r.output_text);data["model_used"]=settings.openai_model;data["mode"]="openai";return data
