import json
from app.ai.mentor_voice import MENTOR_VOICE
from openai import OpenAI
from app.core.config import settings
from app.ai.methodology_full import get_question_rule
SCHEMA={"type":"object","properties":{"quality_score":{"type":"integer","minimum":0,"maximum":100},"decision":{"type":"string","enum":["accepted","needs_deeper_answer"]},"feedback":{"type":"string"},"follow_up_question":{"type":["string","null"]},"extracted_facts":{"type":"array","items":{"type":"string"}},"risks":{"type":"array","items":{"type":"string"}}},"required":["quality_score","decision","feedback","follow_up_question","extracted_facts","risks"],"additionalProperties":False}
RULES="""Avalie SOMENTE a pergunta atual e o escopo fornecido. As preferências da mentora, quando presentes, devem orientar a avaliação e o peso relativo de certificações, experiências, autoridade, estratégias e critérios do método, sem inventar fatos. Nunca reprove porque faltam assuntos futuros. Respostas honestas de iniciantes podem ser completas. Use respostas anteriores apenas para contradições diretamente relevantes. Se a pergunta foi suficientemente respondida, aceite. Se precisar aprofundar, faça EXATAMENTE UMA pergunta complementar curta. Nunca coloque duas perguntas no follow_up_question. Nunca invente fatos, clientes, resultados, certificações ou autoridade."""
def configured():
    return bool(settings.ai_enabled and settings.openai_api_key and settings.openai_api_key.strip())
def analyze(pillar_key,pillar_name,question,answer,previous_answers,mentor_context=None):
    if not configured(): raise RuntimeError("OPENAI_API_KEY não configurada")
    payload={
        "pillar":pillar_name,
        "question_key":question["key"],
        "question":question["question"],
        "evaluation_scope":get_question_rule(question["key"]),
        "answer":answer,
        "mentor_preferences":mentor_context or {},
        "previous_answers_for_context_only":{
            k:v.get("answer_text","") for k,v in previous_answers.items()
        }
    }
    r=OpenAI(api_key=settings.openai_api_key).responses.create(model=settings.openai_model,instructions=MENTOR_VOICE + "\n" + RULES,input=json.dumps(payload,ensure_ascii=False),text={"format":{"type":"json_schema","name":"scoped_answer_analysis","strict":True,"schema":SCHEMA}},store=False)
    parsed=json.loads(r.output_text); parsed["mode"]="openai"; parsed["model_used"]=settings.openai_model
    return parsed

COACH_SCHEMA={"type":"object","properties":{"reply":{"type":"string"}},"required":["reply"],"additionalProperties":False}
def coach_answer(pillar_name, question, answer, message, history=None, mentor_context=None):
    if not configured():
        return {"reply":"Explique com mais clareza o que você realmente faz, vive ou pretende fazer em relação a esta pergunta. Use exemplos reais quando tiver e não invente resultados. Depois ajuste sua resposta com suas próprias palavras."}
    payload={"pillar":pillar_name,"question":question["question"],"evaluation_scope":get_question_rule(question["key"]),"current_answer":answer,"mentee_message":message,"conversation_history":(history or [])[-8:],"mentor_preferences":mentor_context or {}}
    instructions=MENTOR_VOICE+"\nVocê é um orientador de resposta. Ajude a mentorada a ENTENDER como melhorar a resposta atual para atender a pergunta. Responda à dúvida dela de forma prática e curta. Pode dar exemplos genéricos de estrutura, mas NUNCA escreva uma resposta pronta para ela copiar, nunca invente fatos e nunca altere os critérios da pergunta. Se a resposta já parece suficiente, diga claramente que ela pode reenviar com pequenos ajustes de clareza."
    r=OpenAI(api_key=settings.openai_api_key).responses.create(model=settings.openai_model,instructions=instructions,input=json.dumps(payload,ensure_ascii=False),text={"format":{"type":"json_schema","name":"answer_coach","strict":True,"schema":COACH_SCHEMA}},store=False)
    return json.loads(r.output_text)
