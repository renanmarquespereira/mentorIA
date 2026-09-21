# Teste v1.1-dev
1. `docker compose up --build`
2. `GET /health` -> 1.1.0-dev
3. Login + Authorize
4. `GET /api/v1/pillars/positioning`
5. `POST /api/v1/pillars/positioning/answer`
6. Teste `education_background`: não deve exigir público, promessa, dores ou diferenciação.
7. Se houver follow-up, deve haver só uma pergunta complementar.
8. Confira que o progresso representa perguntas concluídas.
9. Conclua Posicionamento e confira `GET /api/v1/pillars/promise` desbloqueado.
10. Depois teste `promise`, `funnel` e `closing`.
11. Faça regressão rápida de CRM, vendas e métricas.
