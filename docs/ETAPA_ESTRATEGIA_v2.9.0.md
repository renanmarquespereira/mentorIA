# Mentoria AI v2.9.0 — estratégia e plano de ação

## Para a mentorada
1. Responda os quatro pilares e conclua os complementos dos planos. Ter 100% das perguntas não basta: os quatro planos precisam estar validados.
2. Abra Estratégia e toque em Gerar estratégia completa. A geração considera suas respostas, os planos dos pilares, as revisões e a metodologia da mentora, além do contexto comercial existente.
3. Consulte resumo executivo, momento atual, prioridades, sínteses dos quatro pilares, pontos fortes, lacunas e recomendações.
4. Toque em Acompanhar plano de ação.
5. Em cada ação, defina Pendente, Em andamento ou Concluída. Em Prioridade, prazo e observações, ajuste Alta/Média/Baixa, escolha ou remova o prazo e registre o acompanhamento.
6. Use os filtros por situação e pilar. As ações vencidas vêm primeiro, seguidas pela prioridade e pelo prazo; as concluídas ficam ao final. O resumo mostra o progresso de todo o plano, independentemente dos filtros.
7. A Home atualiza a quantidade de ações concluídas ao retornar do acompanhamento.

Prazos são escolhidos pela pessoa. A IA não atribui compromissos de agenda automaticamente. Os calendários e controles padrão estão em português do Brasil.

## Preservação de dados
Uma estratégia já gerada continua disponível. Clicar ou repetir a requisição de geração retorna a estratégia salva: não apaga tarefas, prazos, anotações ou conclusões. Na primeira geração, ações antigas são mantidas; uma ação com o mesmo pilar e título não é duplicada.

As estratégias antigas não são recalculadas automaticamente com o novo contexto da mentora. Essa geração com contexto ampliado aplica-se às novas estratégias. Não é necessário resetar sua jornada para usar prioridades, prazos, observações e acompanhamento em ações existentes.

Se o salvamento falhar, a tela de observações fica aberta com o texto para nova tentativa. Uma alteração de andamento só permanece quando confirmada pelo servidor. Erros de carregamento oferecem Tentar novamente, sem fingir que o plano está vazio.

## Atualização da instalação
Atualize mobile e backend conforme ARQUIVOS_ALTERADOS_v2.9.0.txt. Preserve suas configurações locais (.env), o banco existente e as pastas nativas Android/iOS; elas não fazem parte do ZIP original.

Se usa o Docker Compose incluído, na raiz do projeto execute:

    docker compose up -d --build api

A inicialização executa a migração aditiva em action_plan_items, criando due_date (DATE), notes (TEXT) e completed_at (TIMESTAMP) se ainda não existirem. Os dados anteriores permanecem. A migração segue o PostgreSQL já utilizado pelo projeto.

Na pasta mobile, execute:

    flutter pub get
    flutter run

A dependência flutter_localizations vem do próprio SDK Flutter.

## Conferência manual
- Estratégia só é liberada com os quatro planos validados.
- Ao gerar, aparecem as sínteses dos pilares e o botão de acompanhamento.
- Uma ação pode passar de pendente para em andamento, concluir e reabrir.
- Prazo e observações continuam após fechar/reabrir o aplicativo.
- Remover prazo não altera o andamento ou a prioridade.
- Filtros combinados exibem as ações corretas; tarefas vencidas têm indicação visível.
- A Home atualiza o total concluído ao voltar.

## Validação técnica e limites
Testes de banco usam SQLite temporário e funções/modelos reais carregados em isolamento. Respostas da IA e requisições HTTP são simuladas nos testes. Não foi executada uma geração paga, migração em PostgreSQL real ou instalação no aparelho. As regras de bloqueio entre pilares e as funcionalidades anteriores continuam cobertas por regressão.

Testes incluídos: no backend, python -m unittest discover -s tests; no mobile, flutter test.
