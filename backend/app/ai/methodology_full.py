QUESTION_RULES={
 "professional_trajectory":"Avalie somente trajetória profissional e transição para educação financeira.",
"personal_context":"Avalie somente aspectos pessoais que possam influenciar posicionamento, identidade, conexão e autoridade percebida. Não exija detalhes íntimos desnecessários.",
"personal_authority":"Avalie somente se existe uma experiência pessoal legítima que a pessoa deseja usar como parte da autoridade/conexão. Não invente autoridade; se não houver, aceite.",
"education_background":"Avalie somente formação, cursos, certificações e experiência profissional relevante. Não exija público, nicho, promessa, dores, diferenciação, clientes ou resultados.",
"client_results":"Avalie somente resultados reais. Se ainda não houver clientes/resultados e isso for dito claramente, aceite.",
"personal_transformation":"Avalie somente transformação financeira pessoal real.",
"values":"Avalie somente valores e princípios profissionais.",
"desired_perception":"Avalie somente percepção profissional desejada.",
"what_you_do":"Avalie somente clareza sobre o que a pessoa faz.",
"transformation":"Avalie somente a transformação declarada, sem exigir persona completa.",
"target_audience":"Avalie somente público-alvo.","persona":"Avalie somente persona.",
"pains":"Avalie somente dores e consequências.","desires":"Avalie somente desejos.",
"objections":"Avalie somente objeções dentro do pilar atual.","point_a":"Avalie somente estado inicial.",
"point_b":"Avalie somente estado desejado.","promise":"Avalie somente clareza e coerência da promessa.",
"super_promise":"Avalie somente concisão e clareza da promessa curta."}
def get_question_rule(key):
    return QUESTION_RULES.get(key,"Avalie somente o conteúdo solicitado pela pergunta atual.")

PILLARS = {
    "positioning": {
        "name": "Posicionamento Único",
        "requires": None,
        "questions": [
            {"key":"professional_trajectory","title":"Trajetória profissional","question":"Conte sua trajetória profissional e como chegou à educação financeira.","min_chars":40,"weight":10},
            {"key":"education_background","title":"Formação","question":"Qual é sua formação e quais experiências relevantes possui?","min_chars":20,"weight":10},
            {"key":"client_results","title":"Resultados","question":"Quais resultados reais você já ajudou clientes a alcançar? Se ainda não possui, diga claramente.","min_chars":10,"weight":10},
            {"key":"personal_transformation","title":"Transformação pessoal","question":"O que a educação financeira mudou na sua própria vida?","min_chars":30,"weight":15},
            {"key":"values","title":"Valores","question":"Quais valores e princípios você quer associar ao seu trabalho?","min_chars":20,"weight":10},
            {"key":"desired_perception","title":"Percepção desejada","question":"Como você quer ser percebido pelo seu público?","min_chars":20,"weight":10},
            {"key":"what_you_do","title":"O que você faz","question":"Explique em uma frase o que você faz como educador financeiro.","min_chars":10,"weight":10},
            {"key":"transformation","title":"Transformação","question":"Qual transformação você consegue gerar na vida do cliente?","min_chars":20,"weight":15}
        ]
    },
    "promise": {
        "name": "Promessa Atrativa",
        "requires": "positioning",
        "questions": [
            {"key":"main_product","title":"Produto principal","question":"Descreva sua mentoria: formato, duração, encontros e entrega.","min_chars":25,"weight":10},
            {"key":"pricing","title":"Precificação","question":"Qual é o ticket atual e por que esse preço faz sentido hoje?","min_chars":20,"weight":10},
            {"key":"target_audience","title":"Público-alvo","question":"Qual público amplo você deseja atender?","min_chars":10,"weight":10},
            {"key":"persona","title":"Persona","question":"Descreva uma pessoa específica: profissão, renda, rotina, família e contexto financeiro.","min_chars":50,"weight":15},
            {"key":"pains","title":"Dores","question":"Quais dores essa persona vive e quais consequências elas geram?","min_chars":40,"weight":15},
            {"key":"desires","title":"Desejos","question":"O que essa persona realmente deseja conquistar?","min_chars":30,"weight":15},
            {"key":"objections","title":"Objeções","question":"Quais razões fariam essa persona adiar a compra?","min_chars":30,"weight":10},
            {"key":"point_a","title":"Ponto A","question":"Como está a vida dela antes de trabalhar com você?","min_chars":30,"weight":10},
            {"key":"point_b","title":"Ponto B","question":"Como ela deve estar após a transformação?","min_chars":30,"weight":15},
            {"key":"promise","title":"Promessa","question":"Escreva sua promessa atual, mesmo que imperfeita.","min_chars":20,"weight":10},
            {"key":"super_promise","title":"Super Promessa","question":"Escreva uma versão curta para bio/comunicação rápida.","min_chars":10,"weight":10}
        ]
    },
    "funnel": {
        "name": "Funil de Venda Poderoso",
        "requires": "promise",
        "questions": [
            {"key":"current_acquisition","title":"Aquisição","question":"Como novos leads chegam até você hoje?","min_chars":20,"weight":10},
            {"key":"organic_actions","title":"Orgânico","question":"Quais estratégias orgânicas você usa ou pretende usar?","min_chars":20,"weight":10},
            {"key":"paid_traffic","title":"Tráfego pago","question":"Você investe em anúncios? Explique valores e resultados.","min_chars":15,"weight":10},
            {"key":"lead_awareness","title":"Consciência","question":"Em qual nível de consciência seus leads normalmente chegam?","min_chars":20,"weight":10},
            {"key":"current_funnel","title":"Funil atual","question":"Qual funil você usa hoje? Se nenhum, diga isso.","min_chars":10,"weight":15},
            {"key":"lead_volume","title":"Leads","question":"Quantos novos leads recebe por semana?","min_chars":2,"weight":10},
            {"key":"calls_volume","title":"Calls","question":"Quantas sessões estratégicas realiza por semana?","min_chars":2,"weight":10},
            {"key":"best_source","title":"Melhor origem","question":"Qual origem trouxe seus melhores clientes?","min_chars":10,"weight":10},
            {"key":"funnel_goal","title":"Objetivo","question":"O que deseja melhorar primeiro: volume, qualificação, conversão ou previsibilidade?","min_chars":15,"weight":15}
        ]
    },
    "closing": {
        "name": "Fechamento Irrecusável",
        "requires": "funnel",
        "questions": [
            {"key":"sales_confidence","title":"Confiança","question":"Como você se sente hoje ao vender sua mentoria?","min_chars":20,"weight":10},
            {"key":"sales_channel","title":"Canal","question":"Você fecha por call, WhatsApp, ligação ou outro formato?","min_chars":10,"weight":10},
            {"key":"spin_situation","title":"SPIN Situação","question":"Quais perguntas você faz para entender a situação atual?","min_chars":20,"weight":10},
            {"key":"spin_problem","title":"SPIN Problema","question":"Como identifica o problema central do lead?","min_chars":20,"weight":10},
            {"key":"spin_implication","title":"SPIN Implicação","question":"Como mostra as consequências de não resolver o problema?","min_chars":20,"weight":10},
            {"key":"spin_need","title":"SPIN Necessidade","question":"Como conecta a necessidade à sua solução?","min_chars":20,"weight":10},
            {"key":"objections","title":"Objeções","question":"Quais objeções você mais escuta?","min_chars":20,"weight":15},
            {"key":"follow_up","title":"Follow-up","question":"Como faz follow-up quando o lead não decide na hora?","min_chars":20,"weight":10},
            {"key":"downgrade","title":"Downgrade","question":"Você possui uma oferta de entrada? Descreva.","min_chars":15,"weight":10},
            {"key":"testimonials","title":"Depoimentos","question":"Como e quando solicita depoimentos?","min_chars":15,"weight":10},
            {"key":"referrals","title":"Indicações","question":"Como pede indicações?","min_chars":15,"weight":10},
            {"key":"metrics","title":"Métricas","question":"Quais métricas comerciais acompanha?","min_chars":20,"weight":15}
        ]
    }
}

def get_pillar(key):
    return PILLARS.get(key)

def evaluate_answer(q, answer):
    text = (answer or "").strip()
    if not text:
        return 0, "needs_review"
    if len(text) < q["min_chars"]:
        return max(1, q["weight"] // 3), "needs_review"
    return q["weight"], "answered"

def progress_percent(answers, questions):
    if not questions: return 0
    completed=sum(1 for q in questions if (answers.get(q["key"]) or {}).get("status") in ("answered","answered_ai"))
    return round(completed*100/len(questions))

def next_question(answers, questions):
    for q in questions:
        item = answers.get(q["key"])
        if not item or item.get("status") == "needs_review":
            return q
    return None
