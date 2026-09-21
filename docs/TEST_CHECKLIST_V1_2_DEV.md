# Teste v1.2-dev

1. `docker compose down`
2. `docker compose up --build`
3. `GET /health` => `1.2.0-dev`
4. Confirme que não existe mais o grupo antigo `/diagnosis/positioning` no Swagger.
5. `GET /api/v1/pillars/positioning`
6. `POST /api/v1/pillars/positioning/answer` com `education_background`.
7. Esperado: a análise se limita a formação/cursos/experiência; não cobra público, promessa, dores ou diferenciação.
8. Se pedir aprofundamento, deve haver apenas uma pergunta complementar.
9. Confirme que o progresso não diminui.
10. Faça regressão rápida em CRM e métricas.
