# Checklist v2.2

1. Responder todas as perguntas de `positioning`.
2. Ao finalizar, o mobile deve mostrar `Gerar / abrir Plano do Pilar`.
3. Gerar o plano.
4. Se faltar informação essencial, `ready_for_next=false` e deve aparecer UMA pergunta complementar.
5. Enquanto `ready_for_next=false`, `promise` permanece bloqueado.
6. Completar a informação faltante e gerar novamente.
7. Quando `ready_for_next=true`, abrir `promise`.
8. Repetir a lógica em promise, funnel e closing.
9. No final dos 4 pilares, continuar usando o relatório estratégico total.
