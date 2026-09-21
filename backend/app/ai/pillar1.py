PILLAR_KEY = "positioning"

QUESTIONS = [
    {"key":"professional_trajectory","title":"Trajetória profissional","question":"Conte sua trajetória profissional até aqui. O que você fazia antes e como chegou à educação financeira?","min_chars":40,"weight":10},
    {"key":"education_background","title":"Formação","question":"Qual é a sua formação em educação financeira e quais cursos, certificações ou experiências relevantes você possui?","min_chars":20,"weight":10},
    {"key":"experience_time","title":"Tempo de atuação","question":"Há quanto tempo você atua, mesmo que informalmente, com educação financeira?","min_chars":5,"weight":5},
    {"key":"audiences_served","title":"Públicos já atendidos","question":"Quais tipos de pessoas você já atendeu ou ajudou? Se ainda não atendeu ninguém, diga isso claramente.","min_chars":10,"weight":10},
    {"key":"client_results","title":"Resultados de clientes","question":"Quais resultados reais você já ajudou clientes a alcançar? Se ainda não possui resultados de clientes, responda que ainda não possui.","min_chars":10,"weight":10},
    {"key":"personal_transformation","title":"Transformação pessoal","question":"Como era sua vida financeira antes e o que a educação financeira mudou na sua própria vida? Cite conquistas reais.","min_chars":30,"weight":15},
    {"key":"values","title":"Valores","question":"Quais valores e princípios você quer que as pessoas associem ao seu trabalho?","min_chars":20,"weight":10},
    {"key":"desired_perception","title":"Percepção desejada","question":"Como você gostaria que uma pessoa descrevesse você depois de acompanhar seu conteúdo por 30 dias?","min_chars":20,"weight":10},
    {"key":"what_you_do","title":"O que você faz","question":"Explique em uma frase o que você faz hoje como educador financeiro.","min_chars":10,"weight":10},
    {"key":"transformation","title":"Transformação","question":"Qual transformação você acredita que consegue gerar na vida do seu cliente?","min_chars":20,"weight":10},
]

def evaluate_answer(question, answer):
    text = (answer or "").strip()
    if not text:
        return 0, "needs_review"
    if len(text) < question["min_chars"]:
        return max(1, question["weight"] // 3), "needs_review"
    if question["key"] == "client_results":
        lowered = text.lower()
        markers = ["não atendi", "nunca atendi", "não possuo", "não tenho clientes", "ainda não tenho"]
        if any(x in lowered for x in markers):
            return question["weight"], "valid_no_clients"
    return question["weight"], "answered"

def progress_percent(answers):
    total = sum(q["weight"] for q in QUESTIONS)
    score = sum((answers.get(q["key"]) or {}).get("score", 0) for q in QUESTIONS)
    return min(100, round(score * 100 / total)) if total else 0

def next_question(answers):
    for q in QUESTIONS:
        current = answers.get(q["key"])
        if not current or current.get("status") == "needs_review":
            return q
    return None
