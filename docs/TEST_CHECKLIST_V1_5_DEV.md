# Checklist v1.5-dev

## 1. Subir
`docker compose down`
`docker compose up --build`

## 2. Health
`GET /health`
Esperado: `1.5.0-dev`

## 3. Base metodológica
`GET /api/v1/knowledge/status`
Esperado:
- loaded = true
- quatro pilares
- princípios carregados

## 4. Dashboard pós-diagnóstico
`GET /api/v1/dashboard`
Como os quatro pilares já estão validados:
- journey_status = diagnosis_completed
- current_pillar = null
- next_action = Gerar estratégia completa
- strategy_generated = false (antes da geração)

## 5. Gerar estratégia
`POST /api/v1/strategy/generate-full`
Sem body.

A IA deve:
- usar respostas dos 4 pilares;
- usar a metodologia estruturada;
- não inventar clientes/resultados;
- distinguir atual x futuro;
- gerar prioridades e plano de ação.

## 6. Relatório salvo
`GET /api/v1/strategy/full-report`

## 7. Plano de ação
`GET /api/v1/strategy/action-plan`

## 8. Dashboard depois da estratégia
`GET /api/v1/dashboard`
Esperado:
- strategy_generated = true
- next_action = Executar plano de ação
- pending_actions > 0

## 9. Marcar tarefa
`PATCH /api/v1/strategy/action-plan/{item_id}`
Body:
{"status":"done"}

## 10. Regressão rápida
- CRM
- vendas
- metrics/summary
- metrics/history
