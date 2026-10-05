# Relatórios refeitos + resumo mensal por IA — design

**Status:** aprovado em conversa (2026-10-03). Implementação autorizada pelo dono
antes da revisão formal da spec; este documento registra a decisão e segue
aberto a correção durante a implementação.

## Problema

Relatórios hoje são nove "lentes" num menu lateral próprio: cada uma uma tabela
ou um gráfico isolado. Nenhuma delas responde "como foi o mês" — o dono abre
nove telas e monta a conclusão na cabeça. O módulo existe, tem dado, e não
agrega valor.

## Objetivo

Que abrir Relatórios responda três perguntas sem o dono precisar saber o que
procurar: **como foi o mês**, **o que saiu da curva** e **o que fazer agora**.
No primeiro dia de cada mês, um resumo escrito chega sozinho — sino e e-mail.

## Decisões tomadas (e por quê)

| Decisão | Escolha | Razão |
|---|---|---|
| Chave do Gemini | Uma, da Orbix, no servidor | O cliente não configura nada; recurso que "simplesmente existe" parece produto, não integração. Custo é nosso, então o teto é estrutural: um resumo por tenant por mês. |
| Navegação | Abas por tema no topo | Decisão do dono. A aba "Visão" continua sendo a leitura do mês, não mais uma lista. |
| Ambição do resumo | Leitura + alertas + recomendações | É o que faz parecer consultoria. Exige calcular os sinais ANTES, em regra pura. |
| Entrega | Sino + e-mail | O e-mail alcança quem não abre o sistema — é onde relatório mensal é lido de verdade. |
| Números no texto | Só os que NÓS calculamos | Cifra alucinada num relatório financeiro queima o recurso na primeira leitura, e é irrecuperável. |

## Arquitetura

### Onde o código mora

Dentro do módulo `report`. Ele já compõe OS, caixa, despesas, estoque e clientes
pelos services públicos; um módulo novo teria de refazer essa composição, e a
regra 1 ("aponta, não invade") seria testada todo dia.

```
back/src/modules/report/monthly/
  monthly-metrics.ts          # REGRA PURA: números + sinais. Sem Nest, sem banco.
  monthly-metrics.spec.ts
  monthly-summary.service.ts  # coleta → regra → IA → grava → avisa
  monthly-summary.job.ts      # cron do dia 1º
back/src/common/ai/
  ai-text.gateway.ts          # abstrato (molde do gateway fiscal/pagamento)
  gemini-text.gateway.ts      # impl real
  noop-ai.gateway.ts          # sem chave / falha → texto determinístico
```

### A regra pura é onde mora a inteligência

`monthly-metrics.ts` recebe os agregados de DOIS meses (o analisado e o
anterior) e devolve KPIs com variação e uma lista de **sinais**. O prompt não
decide nada: ele recebe sinais já calculados e só escreve.

Cada KPI carrega se subir é bom (`maiorEhMelhor`): receita subindo é verde,
despesa subindo é vermelho, fiado subindo é vermelho. Sem isso toda seta vira
enfeite.

Variação contra mês anterior zerado é `null`, nunca infinito ou 100%.

### O gateway de IA

`AiTextGateway.gerarResumo(payload) → Narrativa`, com saída estruturada
(título, leitura, alertas[], recomendações[]). Implementações: Gemini, Noop e o
fake de teste.

**O produto não depende do LLM.** Sem chave, com a API fora do ar ou estourando
o timeout, o Noop monta o mesmo resumo a partir dos mesmos sinais, em texto
determinístico. O resumo sempre existe; a IA deixa ele melhor escrito. O
registro guarda `aiStatus: ok | fallback` e a tela diz honestamente qual foi.

Nunca dentro de transação de banco (regra 6).

### Persistência

Tabela `report_monthly_summary` (RLS + FORCE), migration aditiva nos 3 lugares:

```
id, tenant_id, period (date = 1º dia do mês), metrics jsonb, signals jsonb,
narrative jsonb, ai_model, ai_status, generated_at, created_at
UNIQUE (tenant_id, period)
```

A unique é o que torna o job idempotente: rodar duas vezes não gera dois
resumos nem duas chamadas pagas.

### O cron

Dia 1º às 4h — depois do trial (0h), da recorrência (2h) e do cleanup (3h),
mesma lógica de não competir. Varre tenants com `report` ativo e assinatura
viva; para cada um `runWithTenant` → coleta → calcula → IA (fora de transação)
→ grava → `NotificationsService.notify()` para quem tem `report.read` + e-mail
ao dono. Falha de um tenant não derruba os outros (precedente:
`ExpenseRecurrenceJob`).

Gatilho manual para teste/demo: rota protegida por `ADMIN_API_TOKEN`, fora da UI.

### Config

```
GEMINI_API_KEY   opcional — sem ela, modo fallback
GEMINI_MODEL     default configurável; id de modelo não é fixado no código
                 porque o catálogo do Google muda
```

## Front

`report_screen.dart` tem 3.070 linhas e vira:

```
report/presentation/
  report_screen.dart        # casca + abas + seletor de período
  tabs/visao_tab.dart       # resumo IA, KPIs, gráfico principal
  tabs/dinheiro_tab.dart    # faturamento, caixa, despesas, a receber
  tabs/operacao_tab.dart    # OS, equipe, top itens, estoque
  tabs/clientes_tab.dart    # novos, ativos, ranking
  widgets/kpi_card.dart     # valor + variação honesta
  widgets/resumo_ia_card.dart
```

`report_catalog.dart` (o menu lateral de nove itens) sai.

## Fases

1. **Métricas + tela.** Entrega valor sozinha, sem nenhuma IA.
2. **Resumo IA + cron + entrega.** Gateway, tabela, job, sino e e-mail.

## Testes

- Regra pura: caso a caso, incluindo mês anterior zerado, mês sem movimento e
  cada sinal isolado.
- Gateway: fake que devolve narrativa fixa; teste de que a falha cai no Noop.
- Job: um tenant quebrado não impede os outros; rodar duas vezes não duplica.
- Front: KPI com variação, abas, e o card de resumo no estado `fallback`.
