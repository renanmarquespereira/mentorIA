import io, json
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from app.ai.methodology_full import get_pillar

PILLAR_NAMES = {
    'positioning': 'Posicionamento Único',
    'promise': 'Promessa Atrativa',
    'funnel': 'Funil de Venda Poderoso',
    'closing': 'Fechamento Irrecusável',
}

def _safe(value):
    return str(value or '').replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')

def _json_list(value):
    try: return json.loads(value or '[]')
    except Exception: return []

def build_pillar_pdf(*, mentee, pillar_key, answers, report, round_label='Avaliação atual'):
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, rightMargin=42, leftMargin=42, topMargin=42, bottomMargin=42,
                            title=f"{PILLAR_NAMES.get(pillar_key,pillar_key)} - {mentee.name}")
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='TitleCenter', parent=styles['Title'], alignment=TA_CENTER, spaceAfter=14))
    styles.add(ParagraphStyle(name='Section', parent=styles['Heading2'], spaceBefore=14, spaceAfter=8))
    styles.add(ParagraphStyle(name='SmallMuted', parent=styles['BodyText'], textColor=colors.HexColor('#666666'), fontSize=9))
    story = [
        Paragraph('Relatório do Pilar', styles['TitleCenter']),
        Paragraph(_safe(PILLAR_NAMES.get(pillar_key, pillar_key)), styles['Heading1']),
        Paragraph(f"Mentorada: <b>{_safe(mentee.name)}</b>", styles['BodyText']),
        Paragraph(f"{_safe(round_label)}", styles['SmallMuted']), Spacer(1, 12),
    ]
    definition = get_pillar(pillar_key) or {}
    qmap = {q.get('key'): q.get('question') or q.get('title') or q.get('key') for q in definition.get('questions', [])}
    story.append(Paragraph('Perguntas e respostas', styles['Section']))
    if not answers:
        story.append(Paragraph('Nenhuma resposta registrada.', styles['BodyText']))
    for idx, row in enumerate(answers, 1):
        q = qmap.get(getattr(row,'question_key','')) or ('Pergunta complementar da IA' if str(getattr(row,'question_key','')).startswith('report_followup_') else getattr(row,'question_key','Pergunta'))
        story += [Paragraph(f"<b>{idx}. {_safe(q)}</b>", styles['BodyText']), Spacer(1,4), Paragraph(_safe(getattr(row,'answer_text','')), styles['BodyText']), Spacer(1,10)]
    if report:
        story += [Paragraph('Resumo da análise', styles['Section']), Paragraph(_safe(report.summary), styles['BodyText'])]
        if report.perceived_authority:
            story += [Paragraph('Autoridade percebida', styles['Section']), Paragraph(_safe(report.perceived_authority), styles['BodyText'])]
        for title, values in [('Pontos fortes', _json_list(report.strengths_json)), ('Pontos de atenção', _json_list(report.gaps_json)), ('Informações a aprofundar', _json_list(report.missing_information_json))]:
            if values:
                story.append(Paragraph(title, styles['Section']))
                for item in values: story.append(Paragraph(f"• {_safe(item)}", styles['BodyText']))
        plan = _json_list(report.practical_plan_json)
        if plan:
            story.append(Paragraph('Plano prático / recomendações', styles['Section']))
            for item in plan:
                if isinstance(item, dict):
                    title = item.get('title') or item.get('action') or item.get('name') or 'Ação'
                    detail = item.get('description') or item.get('detail') or item.get('why') or ''
                    story.append(Paragraph(f"• <b>{_safe(title)}</b>{': ' + _safe(detail) if detail else ''}", styles['BodyText']))
                else: story.append(Paragraph(f"• {_safe(item)}", styles['BodyText']))
        story += [Spacer(1,12), Paragraph('Status: ' + ('Pilar validado' if report.ready_for_next == 'true' else 'Pilar em evolução'), styles['SmallMuted'])]
        if report.mentor_review_note:
            story += [Paragraph('Observação da mentora', styles['Section']), Paragraph(_safe(report.mentor_review_note), styles['BodyText'])]
    doc.build(story)
    return buf.getvalue()
