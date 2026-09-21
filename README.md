# Mentoria AI App — v1.5-dev

Grande avanço sobre a v1.2-dev.

## Mantido
- quatro pilares validados;
- IA por pergunta;
- desbloqueio sequencial;
- CRM;
- vendas;
- métricas;
- CPL, CAC e ROI.

## Novo
- `.env` já vem nomeado (não há `.env.example`);
- base metodológica estruturada em `backend/app/knowledge/methodology.json`;
- endpoint para conferir carregamento da metodologia;
- síntese estratégica dos quatro pilares;
- relatório geral persistido no banco;
- plano de ação automático;
- dashboard pós-diagnóstico corrigido.

## Novos endpoints

- `GET /api/v1/knowledge/status`
- `POST /api/v1/strategy/generate-full`
- `GET /api/v1/strategy/full-report`

Depois de gerar a estratégia, use também:
- `GET /api/v1/strategy/action-plan`
- `PATCH /api/v1/strategy/action-plan/{item_id}`

## Observação do .env
Abra `.env` e cole sua `OPENAI_API_KEY` antes de subir a API.


## Restaurar o estado validado após formatação
Você não precisa refazer os 4 pilares.

1. Suba o backend.
2. Registre/login um usuário.
3. Use Authorize no Swagger.
4. Execute `POST /api/v1/dev/restore-tested-state`.
5. Confira `GET /api/v1/pillars`.
6. Continue em `POST /api/v1/strategy/generate-full`.

O endpoint restaura para o usuário autenticado as respostas e os quatro pilares já validados no nosso teste anterior.


## v2.0-mobile-dev
Flutter integrado ao backend validado: login, dashboard, 4 pilares, estratégia, plano de ação, CRM e métricas.

### Rodar
`cd mobile`
`flutter pub get`
`flutter run`

Emulador Android usa `http://10.0.2.2:8001/api/v1`. Em celular físico, troque `10.0.2.2` pelo IPv4 do computador em `mobile/lib/services/api_service.dart`.


## v2.1-crm-mobile-dev
CRM mobile operacional: criar lead, filtrar, abrir detalhes, mudar estágio, registrar venda; métricas com histórico e lançamento manual de período. O follow-up persistente fica para a próxima evolução.


## v2.2 - Relatório/Plano por Pilar

Mudança de regra:
- responder todas as perguntas não libera automaticamente o próximo pilar;
- ao terminar um pilar, o usuário gera o Plano do Pilar;
- a IA verifica se faltam informações essenciais;
- se faltar algo, o relatório retorna uma pergunta complementar;
- somente quando `ready_for_next=true` o pilar seguinte pode ser desbloqueado.

No Posicionamento foram acrescentadas perguntas sobre:
- contexto de vida pessoal;
- experiências pessoais que a pessoa deseja usar legitimamente como parte da autoridade/conexão.

Isso permite combinar vida profissional + vida pessoal na construção da autoridade percebida, sem forçar informações pessoais irrelevantes.


## v2.2.1
Correção de sintaxe em `mobile/lib/screens/metrics_screen.dart`.


## v2.2.2 - Complementação do Plano do Pilar

Correção do fluxo:
- quando `ready_for_next=false`, o mobile mostra a pergunta complementar;
- existe campo para responder;
- botão `Enviar complemento`;
- a resposta é salva no backend;
- a IA reanalisa o mesmo pilar;
- se ainda faltar algo, gera nova pergunta complementar;
- quando `ready_for_next=true`, aparece `Continuar para o próximo módulo`.


## v2.3 - Mentora/Admin + aprovação + metodologia personalizada

Novidades:
- dois perfis: `mentor/admin` e `mentee`;
- nova mentorada nasce como `pending_approval`;
- tela de espera enquanto aguarda validação;
- painel da mentora com cadastros pendentes;
- aprovar/recusar mentoradas;
- tela de configuração da metodologia da mentora;
- regras de autoridade, certificações, experiências, estratégias, tom e observações livres;
- mobile fixado em `http://192.168.0.10:8001/api/v1`.

### Desenvolvimento
Para transformar a conta atual em mentora:
`POST /api/v1/dev/make-me-mentor`

Em produção, esse endpoint de desenvolvimento deve ser removido/desabilitado.

### Observação sobre .env
Este pacote não depende de substituir seu `.env`. Preserve o arquivo local existente.


## v2.3.1 - correção de banco existente

Ao iniciar a API, o backend agora atualiza bancos existentes adicionando:
- `users.role`
- `users.approval_status`
- `users.approved_by_user_id`

As alterações usam `IF NOT EXISTS`, portanto podem ser executadas em toda inicialização sem apagar dados.

Depois de substituir os arquivos:
`docker compose down`
`docker compose up --build`

Não use `docker compose down -v`, porque `-v` apagaria o volume do PostgreSQL.


## v2.4 - mentoradas permanentes + metodologia aplicada + limites de módulo
- todas as mentoradas permanecem visíveis;
- status permanente: aguardando, aprovado, recusado;
- filtros por status;
- engrenagem para Configurações da Mentora;
- preferências da mentora entram na análise dos Planos dos Pilares;
- lacunas ficam restritas ao módulo atual;
- sugestões opcionais entram no plano prático e não bloqueiam avanço.


## v2.5 - Controle total da mentorada

### Acesso
- terminologia da interface alterada para `Bloqueado` / `Desbloqueado`;
- registros nunca desaparecem da Área da Mentora.

### Painel individual da mentorada
A mentora pode abrir qualquer mentorada e visualizar:
- dados da conta;
- status de acesso;
- progresso dos quatro pilares;
- respostas dadas em cada pilar;
- Plano do Pilar já gerado.

### Resets
- `Resetar Plano do Pilar`: apaga apenas o relatório/plano daquele pilar e preserva as respostas, permitindo gerar novamente.
- `Resetar toda a jornada`: apaga diagnóstico, planos por pilar, estratégia geral e plano de ação; preserva a conta da mentorada.
- CRM, vendas e métricas comerciais não são apagados pelo reset da jornada.


## v2.6 - Revisão humana da mentora

A mentora pode editar um Plano do Pilar já gerado pela IA:
- resumo;
- autoridade percebida;
- pontos fortes;
- lacunas;
- informações faltantes;
- plano prático;
- observação da mentora.

Após salvar:
- o material continua sendo o mesmo Plano do Pilar, mas com revisão humana;
- o backend registra que foi editado pela mentora;
- a mentorada vê uma indicação discreta `Editado pela mentora`;
- uma observação opcional da mentora pode aparecer no plano.

A revisão não apaga as respostas originais da mentorada.


## v2.6.1 - ajustes de clareza e sessão

- a observação da mentora agora aparece com o título explícito `Observação da mentora`;
- a Área da Mentora agora possui botão `Sair` no topo;
- o logout remove o token local e retorna para a tela de login.


## v2.7 - metodologia da mentora em toda a conversa + progresso real

### Metodologia personalizada
As preferências salvas pela mentora agora são enviadas:
- na análise de cada resposta;
- nas perguntas complementares;
- na geração/reanálise do Plano do Pilar.

Assim, a IA passa a considerar a metodologia da mentora durante toda a jornada, e não somente no relatório final do pilar.

### Progresso
O painel da mentora não depende mais apenas da tabela `pillar_progress`.
Ele recalcula o percentual pelas respostas reais da mentorada e usa o maior valor entre o cálculo e o progresso persistido.

### Status em português
- `not_started` → Não iniciado
- `in_diagnosis` → Em andamento
- `needs_review` → Aguardando revisão
- `needs_report_completion` → Aguardando complemento
- `answered_ai` → Respondido
- `validated` → Concluído


## v2.7.1 - três status e filtros combináveis

### Status de acesso
- `pending_approval` → Pendente
- `active` → Desbloqueado
- `rejected` → Bloqueado

Uma usuária recém-cadastrada aparece como `Pendente`.
Depois da primeira decisão, a mentora pode bloquear ou desbloquear novamente quando quiser.

### Filtros
A Área da Mentora agora usa filtros combináveis:
- Pendentes
- Desbloqueadas
- Bloqueadas

É possível selecionar mais de um status simultaneamente, por exemplo:
`Pendentes + Bloqueadas`.

O botão `Mostrar todas` restaura os três filtros.


## v2.8 - busca global + cadastro completo
- cadastro com nome, telefone, e-mail e senha;
- após cadastro, retorno à tela de login;
- mensagem para aguardar permissão da mentora;
- status inicial continua Pendente;
- busca global da mentora por nome, telefone ou e-mail;
- busca funciona junto com filtros combináveis;
- coluna `users.phone` criada automaticamente em bancos existentes.


## v2.8.1 - refinamento visual
- login restaurado ao layout compacto anterior;
- confirmação de senha no cadastro;
- filtro em botão discreto dentro da barra de busca;
- status à direita do cartão e botão único abaixo;
- Pendente laranja, Desbloqueado verde, Bloqueado vermelho.
