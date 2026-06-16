# OrbixHub — Pendências (backlog para consumir depois)

> Itens conscientemente adiados durante o design. Cada um vira (quando chegar a hora)
> seu próprio spec → plano → implementação. Não é compromisso de escopo; é memória.

## Plataforma — Entitlements por feature (gating intra-módulo por plano)

Hoje o billing gateia **módulo inteiro** (`tenant_module` + `plan_module`). Não há
"feature dentro do módulo liberada por plano". Para suportar **freemium** (ex.: estoque
básico no trial, avançado no pro) precisamos de uma camada análoga à de módulos:

- Tabela `plan_feature` (plan → chaves de feature) + opcional `tenant_feature` (override/addon).
- `/me` passa a expor `features[]` (além de `modules[]`).
- Guard `@RequiresFeature('inventory.reports')` no back; no front, `me.features` decide UI
  (mesma lógica de `gatedNavItems`). Esconder ≠ proteger — back é a verdade.
- Construir **junto com o primeiro lote de features "pro"** (provavelmente o avançado do estoque),
  não antes (YAGNI).

## Módulo Estoque & Serviços (`inventory`) — avançado (pro/futuro)

- **Alerta/dashboard de estoque mínimo** — card no dashboard + notificação proativa
  (o v1 já guarda `min_qty` e tem filtro simples "abaixo do mínimo").
- **Precificação automática com IA** — sugerir preço de venda a partir de custo + mercado/histórico
  (o v1 tem só o markup manual custo+margem→preço sugerido).
- **Valorização de estoque** — custo médio / última compra; **valor total do estoque** de produtos.
- **Relatórios de estoque** — giro, curva ABC, consumo por período/OS/técnico.
- **Fornecedores** como entidade leve — entrada de estoque vinculada a fornecedor + custo histórico.
- **Importação em massa (CSV)** do catálogo — onboarding rápido (diferencial de conversão).
- **Kits/combos** — item composto por outros (ex.: "revisão completa" = óleo + filtro + mão de obra);
  ao usar na OS, explode nos componentes e dá baixa de cada um.
- **Código de barras por leitor** — busca rápida por barcode no PDV/OS.
- **Unidades e conversão** — compra em caixa/fardo, consome em unidade.
- **Múltiplos depósitos/locais** — saldo por local (provavelmente fora do público-alvo inicial).

## Módulo Ordens de Serviço (`os`) — a detalhar em spec próprio

- Baixa automática de estoque ao consumir produto na OS (liga em `InventoryService.applyMovement`).
- Envio do link público por **WhatsApp** e **e-mail** (no v1 os ícones aparecem desabilitados;
  só "copiar link" funciona).
- (mais itens entram quando brainstormarmos a OS)
