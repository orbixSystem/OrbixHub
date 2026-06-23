# Dashboard + Relatórios — Design (OrbixHub)

> Data: 2026-06-22 · Status: aprovado p/ implementação
> Fonte de verdade pro build. Regras-mãe: ver `.claude/skills/orbixhub-arquitetura/SKILL.md`.

## 1. Contexto e decisões

OrbixHub é SaaS multi-tenant **modular**. Hoje o "Início" é estático (lê só `/me`) e
**nenhum módulo expõe agregados** (os/inventory/customers são CRUD). A regra nº1
("aponta, não invade") proíbe um módulo de dashboard/relatório ler a *tabela* alheia.

Decisões (validadas com o usuário):
- **Dashboard role-aware**: dono/gerente veem cockpit de negócio; mecânico/caixa veem o
  operacional do seu papel. Mesmo dashboard, conteúdo decidido por permissão.
- **Empacotamento**: Dashboard = **núcleo** (`is_core`, todo tenant). Relatórios =
  módulo **`report` contratável**, mas **habilitado em todos os planos agora** (trial +
  pro) → grátis hoje; monetização decidida no futuro sem retrabalho.
- **Relatórios MVP**: tela interativa (filtros período/técnico/módulo) + export **CSV e PDF**.

## 2. Arquitetura — camada de métricas + dois hosts

**Princípio:** cada módulo é **dono das próprias métricas**. Dashboard e Relatórios são
duas leituras (alturas diferentes) sobre a mesma camada; nenhum lê tabela alheia.

```
  CAMADA DE MÉTRICAS (dona-por-módulo, sob withTenantTx/RLS)
   os ──────► OsMetricsService.summary(range) + .report(params)  → GET /os/metrics
   inventory► InventoryMetricsService.summary() + .report(...)    → GET /inventory/metrics
   customers► CustomersMetricsService.summary(range) + .report()  → GET /customers/metrics
        ▲                                              ▲
   glanceável (KPI pequeno)                  detalhado/parametrizável
        │                                              │
   DASHBOARD (núcleo, host SÓ front)         RELATÓRIOS (módulo `report`)
   fan-out p/ /metrics dos módulos do        back: controller gated @RequiresModule('report')
   tenant; widgets role-aware via            + @Permissions('report.read'); service CHAMA os
   registry no front. Sem backend novo.      services públicos (nunca tabela) e compõe.
                                             front: tela + filtros + export CSV/PDF.
```

- **Métricas (cada módulo de produto):** novos métodos públicos `summary(range)` (KPIs
  pro dashboard) e `report(params)` (linhas+totais pro relatório), no service do módulo
  (repo faz as queries agregadas sob `withTenantTx`; RLS aplica o tenant). Endpoint
  `GET /<módulo>/metrics?from&to` gated pelo próprio módulo (`@RequiresModule`) + permissão
  de leitura do módulo (`os.read` / `inventory.read` / `customer.read`).
- **Dashboard (núcleo, só front):** evolui o `dashboard_screen.dart`. Fan-out para os
  `/metrics` dos módulos em `me.modules`; **widget registry** no front (espelha
  `nav_items.dart`/`gatedNavItems`): cada widget declara `{ moduleKey, permission, builder }`
  e só renderiza se `me` tiver módulo + permissão. **Sem módulo de backend.**
- **Relatórios (módulo `report`):** backend existe pra **gatear** o recurso (futuro pago).
  `report.controller` (`@RequiresModule('report')` + `@Permissions('report.read')`) →
  `report.service` chama `osService.report(...)`, `inventoryService.report(...)`,
  `customersService.report(...)` (services públicos, **nunca** as tabelas) e compõe. Front
  renderiza tabela + filtros e exporta CSV (novo) + PDF (reusa `printing`, como a OS).

**Por que isso respeita a modularidade:** o dado agregado nasce no módulo dono; dashboard e
report só compõem. Módulo novo no futuro (caixa, financeiro) publica seu `summary`/`report`
e aparece sozinho nos dois lugares — zero acoplamento a tabela alheia.

## 3. Escopo do MVP

### Período (compartilhado)
Seletor: Hoje · 7 dias · 30 dias · Mês atual · Personalizado (range). Default 30 dias.
Resolvido no front; mandado como `?from=ISO&to=ISO`.

### Dashboard — widgets (role-aware)
Núcleo (sem módulo): saudação + cards de plano/status/módulos/função (já existem).

- **OS** (`os.read`):
  - **Gerencial** (tem `report.read` → owner/gerente): faturamento do período
    (Σ `total` de OS `concluida`+`entregue`), nº de OS por status (mini-chart),
    ticket médio, OS em execução, **OS atrasadas** (`scheduled_end` < agora e não
    concluída), tempo médio de ciclo (`finished_at`-`started_at`).
  - **Operacional** (sem `report.read` → mecânico): **minhas OS** (`assigned_to` = eu)
    por status, minhas OS de hoje, minhas atrasadas.
- **Estoque** (`inventory.read`): nº de itens abaixo do mínimo (+ lista curta),
  **valor em estoque** (Σ `current_stock`×`cost_price`), nº de produtos/serviços ativos.
- **Clientes** (`customer.read`): clientes ativos (total), novos no período.

### Relatórios — MVP (módulo `report`, `report.read`)
Tela com seletor de relatório + filtros; cada um com tabela + totais + export CSV/PDF.
- **OS por período**: linhas de OS (nº, cliente, status, técnico, total, abertura,
  conclusão, ciclo); agregados por **status** e por **técnico** (`assigned_to`);
  faturamento, ticket médio, tempo médio de ciclo. Filtros: período, técnico, status.
- **Estoque (posição)**: itens com `current_stock`, `min_stock`, `cost_price`,
  `sale_price`, valor (stock×custo); destaque dos abaixo do mínimo; totalizador de valor.
  (Histórico de movimentos fica fora do MVP — não há tabela `inventory_movement`.)
- **Clientes**: novos clientes por período + total ativo (lista + contagem).

### Visualização
- Charting: **`fl_chart`** (front) — mini-charts no dashboard (pizza de OS por status,
  barra simples) e gráficos no relatório. CSV: **`csv`** (front) p/ gerar e baixar.

## 4. Backend — design

### Métricas por módulo (os, inventory, customers)
- Service: `metricsSummary(range)` e `metricsReport(params)` (ou um `*MetricsService`
  dedicado por módulo, injetado no controller e exportado pro `report`). Repo faz
  `SELECT ... GROUP BY status / assigned_to`, `SUM(total)`, `COUNT(*)`, `AVG(...)` sob
  `withTenantTx` (RLS filtra o tenant; **sem WHERE tenant manual**). Sem I/O externo.
- Controller: `GET /<módulo>/metrics?from&to` — `@RequiresModule('<módulo>')` +
  `@Permissions('<módulo>.read')`. Retorna DTO tipado (formato `{ statusCode,... }` nos erros).
- Índices já existentes ajudam (`idx_service_order_tenant_status`); adicionar índice em
  `(tenant_id, assigned_to)` e `(tenant_id, opened_at)` se necessário (migration aditiva).

### Módulo `report`
- `back/src/modules/report/` (controller→service). **Sem tabela nova** — relatórios são
  computados on-the-fly chamando os services públicos dos módulos do tenant.
- Gate: `@RequiresModule('report')` + `@Permissions('report.read')` em todas as rotas.
- `report.service` descobre os módulos do tenant (via `BillingService.getEnabledModules`)
  e oferece só os relatórios dos módulos habilitados; chama `osService.metricsReport(...)`
  etc. (público; **nunca** a tabela). Auditar geração? Não (leitura). 
- Endpoints: `GET /report/os?from&to&assignedTo&status`, `GET /report/inventory`,
  `GET /report/customers?from&to`. (Export é client-side; backend devolve os dados.)
- Seed (migration aditiva, 3 lugares): `module('report')` + `plan_module` ligando `report`
  a **trial e pro** (grátis agora). `reconcileTenantModules` cuida do resto.

### Modularidade / segurança (checklist regra-a-regra)
- Regra 1: report e dashboard só consomem services públicos. ✓
- Regra 3: tudo sob `withTenantTx`; agregados não burlam RLS. ✓
- Regra 4: métricas genéricas (status/técnico/valor), sem termo de vertical. ✓
- Regra 9: migration aditiva nos 3 lugares (seed do `report` + índices). ✓
- Regra 10: front não hardcoda módulos — widgets/relatórios gated por `me`. ✓

## 5. Frontend — design

- **Dashboard** (`features/shell/presentation/`): `DashboardWidgetRegistry` (lista de
  `{ moduleKey, permission, builder }`), função pura `dashboardWidgets(me)` (testável,
  espelha `gatedNavItems`). Cada widget tem seu provider (repo → `GET /<m>/metrics`),
  com loading/erro/empty elegantes. Charts via `fl_chart`.
- **Relatórios** (`features/report/`): feature-first (domain: modelos freezed + interface
  do repo; data: impl dio + fake; presentation: tela + Notifier selado). Rota `/m/report`
  (gated por módulo `report` + `report.read`). Seletor de relatório + filtros + tabela +
  botões **Exportar CSV** / **Exportar PDF** (PDF reusa `printing`/`pdf`; CSV via `csv`).
  Aparece no menu sozinho (vem de `me.modules`); label/ícone em `nav_items.dart`.
- UI só fala com repository (regra 8); models freezed; strings PT-BR; design tokens atuais.

## 6. Testes (evidência antes de "pronto")
- Backend: isolamento de tenant nas agregações (A não vê números de B); autorização
  (mecânico sem `report.read` não acessa `/report/*`; sem o módulo → 403/404 do guard);
  cálculo correto dos agregados (faturamento, por status, ciclo). `back:lint` 0 warnings +
  `back:test` + `back:test:e2e`.
- Front: `dashboardWidgets(me)` (função pura) por papel/módulo; parse dos DTOs; export CSV
  (conteúdo); `flutter analyze` 0 issues + `flutter test`.

## 7. Fases de entrega
1. **Métricas no backend** (os, inventory, customers): services + `GET /<m>/metrics` +
   índices + testes.
2. **Módulo `report` backend**: seed (module+plan_module em trial/pro), controller gated,
   service compondo via services públicos + testes e2e.
3. **Dashboard front**: registry role-aware + widgets + `fl_chart` + providers/repos + testes.
4. **Relatórios front**: feature `report` + filtros + tabela + export CSV/PDF + testes.

Cada fase: lint/analyze + testes verdes citados antes de "pronto".
