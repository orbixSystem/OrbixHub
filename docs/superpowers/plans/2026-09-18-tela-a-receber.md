# Tela "A receber" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar a aba "Fiado" do Caixa numa tela própria "A receber" (`/m/cashier/a-receber`), com filtro/ordenação/paginação no servidor, a MESMA regra reproduzida offline e verificada por uma tabela de casos única, e um modal de venda a prazo.

**Architecture:** O backend continua um orquestrador puro (compõe OS + Sale + Cashier via services públicos — regra 1). A regra "vencimento do devedor" vira um arquivo puro em TS (`receivables.filtro.ts`) e um irmão em Dart (`receivables_filtro.dart`); os dois testes leem `back/src/modules/receivables/receivables-filtro.casos.json`. O front reusa os widgets da aba (movidos, não reescritos) numa tela nova; a aba sai do Caixa e vira item de menu + botão.

**Tech Stack:** NestJS + Prisma (back) · Flutter/Riverpod 3/go_router/freezed (front) · jest · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-18-tela-a-receber-design.md`

## Global Constraints

- Regra 1 (aponta, não invade): `receivables` NUNCA lê tabela de OS/venda/caixa — só `OsService`, `SaleService`, `CashierService`.
- Regra 2: todo acesso tenant-scoped sob `withTenantTx`/`runWithTenant` (já é assim nos services chamados).
- Sem migration: tabela `receivable_installment` já existe.
- Regra 4/5: nada de módulo hardcoded no front; UI só via repository.
- Strings de usuário em PT-BR **com acento**. Nome da tela: **"A receber"** (nunca "Fiado" em texto novo).
- Padrão SysOne: nenhum texto de tela abaixo de 12px; título 18 / componente 16 / operacional 14 / caption 12 (pisos).
- Debounce de busca de 350ms no estado da query (padrão de `OrderListQueryNotifier`).
- Commits: mensagem em PT-BR no escopo (`feat(receivables): …`), terminando com `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- **Nunca** `git push` neste plano — o dono decide quando sobe.
- Antes de cada commit: `npm run lint --workspace back` (0 warnings) e/ou `flutter analyze` (0 issues) conforme o lado tocado.

## Desvio consciente da spec (registre, não esconda)

A spec diz que `truncated` "deixa de existir". Não dá: `receivables` deriva a carteira varrendo `OsService.listOrders` e `SaleService.listSales` por páginas (teto `MAX_PAGINAS = 10 × 100`), porque "saldo" é conhecimento do caixa e não existe filtro "com saldo" na fonte. Filtro/ordenação/paginação passam a acontecer **no servidor**, sobre o conjunto varrido — e `truncated` **continua** como sinal raro, exibido como aviso. É o que dá para fazer sem violar a regra 1.

## Achado herdado (corrigir no Task 6)

Offline, `_osFinalizadas = {'concluida','entregue'}` em `local_first_receivables_repository.dart` está sem `a_receber`; o servidor usa `FATURAVEIS` (que inclui). É a classe de divergência que a tabela de casos existe para impedir — entra na correção do offline.

---

## File Structure

**Backend (criar)**
- `back/src/modules/receivables/receivables.filtro.ts` — regra pura: vencimento do devedor, classificação (`vencido`/`vence7`/`a_vencer`/`sem_data`), filtro, ordenação, paginação.
- `back/src/modules/receivables/receivables-filtro.casos.json` — tabela de casos compartilhada com o front.
- `back/src/modules/receivables/receivables.filtro.spec.ts` — roda a tabela.
- `back/src/modules/receivables/dto/list-debtors.dto.ts` — query DTO.

**Backend (modificar)**
- `back/src/modules/receivables/receivables.service.ts` — `listCustomers(user, query)`: enriquece com telefone e próxima parcela; aplica filtro/sort/page.
- `back/src/modules/receivables/receivables.controller.ts` — `@Query()` no `GET /receivables`.
- `back/src/modules/receivables/receivables.module.ts` — importa `CashierModule` e `CustomersModule`.
- `back/src/modules/cashier/cashier.service.ts` + `cashier.service.impl.ts` — novo contrato `proximasParcelasEmAberto(tenantId, refs[])`.
- `back/src/modules/customers/customers.service.ts` + `customers.repository.ts` — `getCustomersByIds(user, ids)`.

**Front (criar)**
- `front/lib/features/receivables/domain/receivables_filtro.dart` — irmã Dart da regra pura.
- `front/lib/features/receivables/domain/receivables_query.dart` — `DebtorsQuery` (filtros) + enums.
- `front/lib/features/receivables/presentation/widgets/debtor_tile.dart` — movido da aba.
- `front/lib/features/receivables/presentation/widgets/debtor_titles_dialog.dart` — movido (`showDebtorTitlesDialog`, `_DebtorTitles`, `_TitleCard`, `_ScheduleList`, `_StatusDot`).
- `front/lib/features/receivables/presentation/widgets/pending_settlement.dart` — movido (`_AvisoPendenteAcerto`, `_PendentesDialog`, `_PendenteTile`).
- `front/lib/features/receivables/presentation/receivables_screen.dart` — a tela.
- `front/lib/features/receivables/presentation/receivables_filters_bar.dart` — busca + chips + ordenação.
- `front/lib/features/receivables/presentation/credit_sale_dialog.dart` — modal "Registrar venda a prazo".
- `front/test/receivables_filtro_test.dart` — roda a MESMA tabela de casos.
- `front/test/receivables_screen_test.dart` — tela: chips, busca, modal.

**Front (modificar)**
- `domain/receivables_repository.dart`, `data/receivables_repository_impl.dart`, `data/local_first_receivables_repository.dart`, `data/fake_receivables_repository.dart` — `listDebtors(DebtorsQuery)`.
- `domain/receivables_models.dart` — `Debtor` ganha `phone`, `nextDueAt`, `overdue`; `DebtorsPage` ganha `total`, `page`, `pageSize`, `overdueTotal`.
- `presentation/receivables_providers.dart` — `debtorsQueryProvider` (Notifier com debounce) + `debtorsProvider` reagindo a ele.
- `presentation/receivables_tab.dart` — **removido** ao final (Task 11).
- `features/cashier/presentation/cashier_screen.dart` — sai a aba Fiado; entra ação "A receber".
- `features/shell/presentation/nav_items.dart` — `addAReceber()` após `addModule('cashier')`.
- `core/router/app_router.dart` — rota literal `/m/cashier/a-receber` antes de `/m/:moduleKey`.
- `features/shell/presentation/screen_tutorials.dart` — passo do tour do Caixa que citava a aba.
- `test/receivables_test.dart`, `test/receivables_impl_test.dart`, `test/receivables_offline_test.dart`, `test/cashier_sem_sessao_test.dart`, `test/coach_targets_test.dart` — adaptar.

---

### Task 1: Regra pura no backend + tabela de casos compartilhada

**Files:**
- Create: `back/src/modules/receivables/receivables-filtro.casos.json`
- Create: `back/src/modules/receivables/receivables.filtro.ts`
- Create: `back/src/modules/receivables/receivables.filtro.spec.ts`

**Interfaces:**
- Produces:
  ```ts
  export type Vencimento = 'todos' | 'vencidos' | 'vence7' | 'a_vencer';
  export type Origem = 'todos' | 'os' | 'sale';
  export type OrdemDevedores = 'valor' | 'mais_antigo' | 'nome' | 'vencimento';
  export interface TituloParaFiltro { origin: 'os'|'sale'; createdAt: string|null; balance: number; proximaParcelaEm: string|null; }
  export interface DevedorParaFiltro { customerId: string|null; customerName: string; totalDue: number; titleCount: number; oldestAt: string|null; titulos: TituloParaFiltro[]; }
  export interface DevedorClassificado extends DevedorParaFiltro { nextDueAt: string|null; overdue: boolean; }
  export function classificar(d: DevedorParaFiltro, hoje: Date): DevedorClassificado
  export function filtrarDevedores(lista: DevedorClassificado[], f: { q?: string; vencimento: Vencimento; origem: Origem }, hoje: Date): DevedorClassificado[]
  export function ordenarDevedores(lista: DevedorClassificado[], ordem: OrdemDevedores): DevedorClassificado[]
  export function paginar<T>(lista: T[], page: number, pageSize: number): { items: T[]; total: number }
  export function semAcento(s: string): string
  ```

- [ ] **Step 1: Escrever a tabela de casos (é o contrato dos dois lados)**

```json
{
  "hoje": "2026-09-18T12:00:00Z",
  "devedores": [
    { "id": "sem_data",   "customerId": "c1", "customerName": "Ana",   "totalDue": 100, "titleCount": 1, "oldestAt": "2026-09-01T10:00:00Z", "titulos": [ { "origin": "sale", "createdAt": null, "balance": 100, "proximaParcelaEm": null } ] },
    { "id": "vencido",    "customerId": "c2", "customerName": "Bruno", "totalDue": 250, "titleCount": 2, "oldestAt": "2026-08-01T10:00:00Z", "titulos": [ { "origin": "os", "createdAt": "2026-08-01T10:00:00Z", "balance": 150, "proximaParcelaEm": "2026-09-10" }, { "origin": "sale", "createdAt": "2026-09-15T10:00:00Z", "balance": 100, "proximaParcelaEm": null } ] },
    { "id": "vence7",     "customerId": null, "customerName": "Zeca do Posto", "totalDue": 80, "titleCount": 1, "oldestAt": "2026-09-16T10:00:00Z", "titulos": [ { "origin": "sale", "createdAt": "2026-09-16T10:00:00Z", "balance": 80, "proximaParcelaEm": "2026-09-22" } ] },
    { "id": "a_vencer",   "customerId": "c4", "customerName": "Célia", "totalDue": 500, "titleCount": 1, "oldestAt": "2026-09-17T10:00:00Z", "titulos": [ { "origin": "os", "createdAt": "2026-09-17T10:00:00Z", "balance": 500, "proximaParcelaEm": "2026-10-30" } ] },
    { "id": "sem_parcela_antigo", "customerId": "c5", "customerName": "Dário", "totalDue": 60, "titleCount": 1, "oldestAt": "2026-07-01T10:00:00Z", "titulos": [ { "origin": "sale", "createdAt": "2026-07-01T10:00:00Z", "balance": 60, "proximaParcelaEm": null } ] }
  ],
  "classificacao": {
    "sem_data":  { "nextDueAt": null,         "overdue": false },
    "vencido":   { "nextDueAt": "2026-09-10", "overdue": true },
    "vence7":    { "nextDueAt": "2026-09-22", "overdue": false },
    "a_vencer":  { "nextDueAt": "2026-10-30", "overdue": false },
    "sem_parcela_antigo": { "nextDueAt": "2026-07-01T10:00:00Z", "overdue": true }
  },
  "filtros": [
    { "nome": "todos",            "f": { "vencimento": "todos",    "origem": "todos" }, "esperado": ["sem_data","vencido","vence7","a_vencer","sem_parcela_antigo"] },
    { "nome": "vencidos",         "f": { "vencimento": "vencidos", "origem": "todos" }, "esperado": ["vencido","sem_parcela_antigo"] },
    { "nome": "vence7",           "f": { "vencimento": "vence7",   "origem": "todos" }, "esperado": ["vence7"] },
    { "nome": "a_vencer",         "f": { "vencimento": "a_vencer", "origem": "todos" }, "esperado": ["vence7","a_vencer"] },
    { "nome": "so_os",            "f": { "vencimento": "todos",    "origem": "os" },    "esperado": ["vencido","a_vencer"] },
    { "nome": "so_venda",         "f": { "vencimento": "todos",    "origem": "sale" },  "esperado": ["sem_data","vencido","vence7","sem_parcela_antigo"] },
    { "nome": "busca_sem_acento", "f": { "vencimento": "todos",    "origem": "todos", "q": "celia" }, "esperado": ["a_vencer"] },
    { "nome": "busca_apelido",    "f": { "vencimento": "todos",    "origem": "todos", "q": "zeca" },  "esperado": ["vence7"] }
  ],
  "ordenacoes": [
    { "ordem": "valor",       "esperado": ["a_vencer","vencido","sem_data","vence7","sem_parcela_antigo"] },
    { "ordem": "mais_antigo", "esperado": ["sem_parcela_antigo","vencido","sem_data","vence7","a_vencer"] },
    { "ordem": "nome",        "esperado": ["sem_data","vencido","a_vencer","sem_parcela_antigo","vence7"] },
    { "ordem": "vencimento",  "esperado": ["sem_parcela_antigo","vencido","vence7","a_vencer","sem_data"] }
  ],
  "paginacao": { "pageSize": 2, "page": 2, "ordem": "valor", "esperadoIds": ["sem_data","vence7"], "total": 5 }
}
```

Regras que a tabela fixa (e que o código tem de honrar):
- **`nextDueAt`** = menor `proximaParcelaEm` entre os títulos; se nenhum título tem parcela, cai no menor `createdAt` (a data do título vira o vencimento). Título sem nenhuma data não contribui.
- **`overdue`** = existe título cujo vencimento efetivo (`proximaParcelaEm ?? createdAt`) é anterior a `hoje` (comparação por dia, em UTC). Basta UM.
- **`vencidos`** = `overdue`. **`vence7`** = não vencido e `nextDueAt` entre hoje e hoje+7 dias inclusive. **`a_vencer`** = não vencido e `nextDueAt` não nulo (inclui os `vence7`). **`todos`** = tudo, inclusive `sem_data`.
- **`origem`** mantém o devedor se ele tem ao menos um título daquela origem.
- **`q`** compara `semAcento(lower(customerName))` contendo `semAcento(lower(q))`.
- **`nome`** ordena por `customerName` com `localeCompare('pt-BR', {sensitivity: 'base'})`. **`vencimento`**: nulos por último.

- [ ] **Step 2: Escrever o teste que lê a tabela**

```ts
// back/src/modules/receivables/receivables.filtro.spec.ts
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  classificar, filtrarDevedores, ordenarDevedores, paginar, DevedorParaFiltro,
} from './receivables.filtro';

/**
 * A MESMA tabela é lida pelo teste Dart (front/test/receivables_filtro_test.dart).
 * Se um lado mudar a regra sem o outro, os dois ficam vermelhos — foi exatamente
 * a divergência online/offline que deixou o fiado vazando título entre devedores.
 */
const casos = JSON.parse(
  readFileSync(join(__dirname, 'receivables-filtro.casos.json'), 'utf8'),
) as {
  hoje: string;
  devedores: Array<DevedorParaFiltro & { id: string }>;
  classificacao: Record<string, { nextDueAt: string | null; overdue: boolean }>;
  filtros: Array<{ nome: string; f: { q?: string; vencimento: string; origem: string }; esperado: string[] }>;
  ordenacoes: Array<{ ordem: string; esperado: string[] }>;
  paginacao: { pageSize: number; page: number; ordem: string; esperadoIds: string[]; total: number };
};

const hoje = new Date(casos.hoje);
const classificados = casos.devedores.map((d) => ({ ...classificar(d, hoje), id: d.id }));
const ids = (l: Array<{ id: string }>) => l.map((x) => x.id);

describe('receivables.filtro (tabela compartilhada com o front)', () => {
  it.each(Object.entries(casos.classificacao))('classifica %s', (id, esperado) => {
    const d = classificados.find((x) => x.id === id)!;
    expect(d.nextDueAt).toBe(esperado.nextDueAt);
    expect(d.overdue).toBe(esperado.overdue);
  });

  it.each(casos.filtros.map((c) => [c.nome, c] as const))('filtro %s', (_n, c) => {
    const r = filtrarDevedores(classificados, c.f as never, hoje);
    expect(ids(r).sort()).toEqual([...c.esperado].sort());
  });

  it.each(casos.ordenacoes.map((c) => [c.ordem, c] as const))('ordem %s', (_n, c) => {
    expect(ids(ordenarDevedores(classificados, c.ordem as never))).toEqual(c.esperado);
  });

  it('paginação devolve a página pedida e o total geral', () => {
    const p = casos.paginacao;
    const ordenados = ordenarDevedores(classificados, p.ordem as never);
    const r = paginar(ordenados, p.page, p.pageSize);
    expect(ids(r.items)).toEqual(p.esperadoIds);
    expect(r.total).toBe(p.total);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd back && npx jest receivables.filtro`
Expected: FAIL — `Cannot find module './receivables.filtro'`.

- [ ] **Step 4: Implementar a regra**

```ts
// back/src/modules/receivables/receivables.filtro.ts
/**
 * Regra PURA do "A receber": quem está vencido, o que vem primeiro, que página.
 * Sem Nest, sem banco. É a decisão de negócio que erra em silêncio — e é a
 * regra que o offline (Dart) repete; a tabela `receivables-filtro.casos.json`
 * é o contrato dos dois.
 */
export type Vencimento = 'todos' | 'vencidos' | 'vence7' | 'a_vencer';
export type Origem = 'todos' | 'os' | 'sale';
export type OrdemDevedores = 'valor' | 'mais_antigo' | 'nome' | 'vencimento';

export interface TituloParaFiltro {
  origin: 'os' | 'sale';
  createdAt: string | null;
  balance: number;
  /** Próxima parcela em aberto (YYYY-MM-DD); null = sem plano. */
  proximaParcelaEm: string | null;
}

export interface DevedorParaFiltro {
  customerId: string | null;
  customerName: string;
  totalDue: number;
  titleCount: number;
  oldestAt: string | null;
  titulos: TituloParaFiltro[];
}

export interface DevedorClassificado extends DevedorParaFiltro {
  /** Vencimento mais próximo entre os títulos (parcela, senão data do título). */
  nextDueAt: string | null;
  /** Ao menos UM título vencido — não é preciso estar tudo vencido. */
  overdue: boolean;
}

export function semAcento(s: string): string {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

/** "YYYY-MM-DD" em UTC — comparação por DIA, não por instante. */
function diaUtc(iso: string): string {
  return new Date(iso).toISOString().slice(0, 10);
}

function vencimentoEfetivo(t: TituloParaFiltro): string | null {
  return t.proximaParcelaEm ?? t.createdAt;
}

export function classificar(d: DevedorParaFiltro, hoje: Date): DevedorClassificado {
  const hojeDia = diaUtc(hoje.toISOString());
  let nextDueAt: string | null = null;
  let overdue = false;
  for (const t of d.titulos) {
    const v = vencimentoEfetivo(t);
    if (!v) continue;
    if (nextDueAt === null || diaUtc(v) < diaUtc(nextDueAt)) nextDueAt = v;
    if (diaUtc(v) < hojeDia) overdue = true;
  }
  return { ...d, nextDueAt, overdue };
}

export function filtrarDevedores(
  lista: DevedorClassificado[],
  f: { q?: string; vencimento: Vencimento; origem: Origem },
  hoje: Date,
): DevedorClassificado[] {
  const hojeDia = diaUtc(hoje.toISOString());
  const limite7 = new Date(hoje);
  limite7.setUTCDate(limite7.getUTCDate() + 7);
  const limite7Dia = diaUtc(limite7.toISOString());
  const termo = f.q ? semAcento(f.q.trim()) : '';

  return lista.filter((d) => {
    if (f.origem !== 'todos' && !d.titulos.some((t) => t.origin === f.origem)) return false;
    if (termo && !semAcento(d.customerName).includes(termo)) return false;
    switch (f.vencimento) {
      case 'todos':
        return true;
      case 'vencidos':
        return d.overdue;
      case 'vence7':
        return !d.overdue && d.nextDueAt !== null &&
          diaUtc(d.nextDueAt) >= hojeDia && diaUtc(d.nextDueAt) <= limite7Dia;
      case 'a_vencer':
        return !d.overdue && d.nextDueAt !== null;
    }
  });
}

export function ordenarDevedores(
  lista: DevedorClassificado[],
  ordem: OrdemDevedores,
): DevedorClassificado[] {
  const copia = [...lista];
  const porNome = (a: DevedorClassificado, b: DevedorClassificado) =>
    a.customerName.localeCompare(b.customerName, 'pt-BR', { sensitivity: 'base' });
  switch (ordem) {
    case 'valor':
      return copia.sort((a, b) => b.totalDue - a.totalDue || porNome(a, b));
    case 'mais_antigo':
      return copia.sort((a, b) => {
        if (a.oldestAt === b.oldestAt) return porNome(a, b);
        if (a.oldestAt === null) return 1;
        if (b.oldestAt === null) return -1;
        return a.oldestAt < b.oldestAt ? -1 : 1;
      });
    case 'nome':
      return copia.sort(porNome);
    case 'vencimento':
      return copia.sort((a, b) => {
        if (a.nextDueAt === b.nextDueAt) return porNome(a, b);
        if (a.nextDueAt === null) return 1; // sem data por último
        if (b.nextDueAt === null) return -1;
        return diaUtc(a.nextDueAt) < diaUtc(b.nextDueAt) ? -1 : 1;
      });
  }
}

export function paginar<T>(lista: T[], page: number, pageSize: number): { items: T[]; total: number } {
  const p = Math.max(1, page);
  const inicio = (p - 1) * pageSize;
  return { items: lista.slice(inicio, inicio + pageSize), total: lista.length };
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd back && npx jest receivables.filtro`
Expected: PASS — todos os `it.each`.

- [ ] **Step 6: Commit**

```bash
git add back/src/modules/receivables/receivables.filtro.ts back/src/modules/receivables/receivables.filtro.spec.ts back/src/modules/receivables/receivables-filtro.casos.json
git commit -m "feat(receivables): regra pura de vencimento/filtro/ordem + tabela de casos compartilhada

A tabela JSON e o contrato entre o servidor (TS) e o offline (Dart): os dois
testes leem o MESMO arquivo. Divergir vira teste vermelho dos dois lados.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Contratos públicos — próximas parcelas (Cashier) e telefone (Customers)

**Files:**
- Modify: `back/src/modules/cashier/cashier.service.ts` (após `contarParcelasEmAberto`, ~linha 129)
- Modify: `back/src/modules/cashier/cashier.service.impl.ts` (após `listInstallments`, ~linha 919)
- Modify: `back/src/modules/customers/customers.repository.ts` (após `findCustomerById`, linha 91)
- Modify: `back/src/modules/customers/customers.service.ts` (após `getCustomer`, linha 210)
- Test: `back/src/modules/cashier/cashier.proximas-parcelas.spec.ts`

**Interfaces:**
- Produces:
  ```ts
  // CashierService (abstract)
  abstract proximasParcelasEmAberto(tenantId: string, refs: Array<{ saleKind: string; saleId: string }>): Promise<Map<string, string>>; // chave `${saleKind}:${saleId}` → 'YYYY-MM-DD'
  // CustomersService
  async getCustomersByIds(user: AuthUser, ids: string[]): Promise<Array<{ id: string; name: string; phone: string | null }>>
  ```

- [ ] **Step 1: Teste da porta do caixa (unit, sem Nest)**

```ts
// back/src/modules/cashier/cashier.proximas-parcelas.spec.ts
import { CashierServiceImpl } from './cashier.service.impl';

/**
 * Porta estreita para o "A receber": para N títulos, a PRÓXIMA parcela em
 * aberto de cada um, numa consulta só. O chamador não vê a parcela — só a data.
 */
function makeService(rows: Array<{ sale_kind: string; sale_id: string; due_date: Date; paid_at: Date | null }>) {
  const db = {
    receivable_installment: {
      findMany: jest.fn().mockResolvedValue(rows),
    },
  };
  const tenant = {
    runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) => Promise.resolve(fn()),
    withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
    getClient: () => db,
  };
  // Só o `tenant` importa para este método; os demais deps não são tocados.
  const svc = new CashierServiceImpl(tenant as never, {} as never, {} as never, {} as never, {} as never, {} as never, {} as never);
  return { svc, db };
}

describe('proximasParcelasEmAberto', () => {
  it('devolve a parcela em aberto mais próxima de cada título, ignorando as pagas', async () => {
    const { svc } = makeService([
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-10-10'), paid_at: null },
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-09-10'), paid_at: new Date() }, // paga: fora
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-09-20'), paid_at: null },
      { sale_kind: 'os',   sale_id: 'o1', due_date: new Date('2026-09-05'), paid_at: null },
    ]);
    const r = await svc.proximasParcelasEmAberto('t1', [
      { saleKind: 'sale', saleId: 'v1' }, { saleKind: 'os', saleId: 'o1' }, { saleKind: 'sale', saleId: 'sem-plano' },
    ]);
    expect(r.get('sale:v1')).toBe('2026-09-20');
    expect(r.get('os:o1')).toBe('2026-09-05');
    expect(r.has('sale:sem-plano')).toBe(false);
  });

  it('sem refs não consulta o banco', async () => {
    const { svc, db } = makeService([]);
    expect((await svc.proximasParcelasEmAberto('t1', [])).size).toBe(0);
    expect(db.receivable_installment.findMany).not.toHaveBeenCalled();
  });
});
```

Se o construtor de `CashierServiceImpl` tiver outra arity, ajuste o número de `{} as never` — leia o `constructor(` em `cashier.service.impl.ts` antes.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd back && npx jest proximas-parcelas`
Expected: FAIL — `proximasParcelasEmAberto is not a function`.

- [ ] **Step 3: Declarar no contrato abstrato**

Em `cashier.service.ts`, logo após `contarParcelasEmAberto(...)`:

```ts
  /**
   * Para vários títulos de uma vez, a data da PRÓXIMA parcela em aberto de cada
   * um — porta do "A receber", que precisa disso para classificar vencimento
   * sem ler a tabela de parcelas (regra 1). Chave: `${saleKind}:${saleId}`.
   * Título sem plano (ou com tudo pago) simplesmente não aparece no mapa.
   */
  abstract proximasParcelasEmAberto(
    tenantId: string,
    refs: Array<{ saleKind: string; saleId: string }>,
  ): Promise<Map<string, string>>;
```

- [ ] **Step 4: Implementar**

Em `cashier.service.impl.ts`, após `listInstallments`:

```ts
  async proximasParcelasEmAberto(
    tenantId: string,
    refs: Array<{ saleKind: string; saleId: string }>,
  ): Promise<Map<string, string>> {
    const out = new Map<string, string>();
    if (refs.length === 0) return out;
    const rows = await this.tenant.runWithTenant(tenantId, () => {
      const db = this.tenant.getClient();
      return db.receivable_installment.findMany({
        where: {
          paid_at: null,
          OR: refs.map((r) => ({ sale_kind: r.saleKind, sale_id: r.saleId })),
        },
        select: { sale_kind: true, sale_id: true, due_date: true },
        orderBy: { due_date: 'asc' },
      });
    });
    // `orderBy asc` + "primeiro que aparece ganha" = a mais próxima de cada título.
    for (const r of rows) {
      const k = `${r.sale_kind}:${r.sale_id}`;
      if (!out.has(k)) out.set(k, r.due_date.toISOString().slice(0, 10));
    }
    return out;
  }
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd back && npx jest proximas-parcelas`
Expected: PASS.

- [ ] **Step 6: Telefone em lote no Customers**

Em `customers.repository.ts`, após `findCustomerById`:

```ts
  /** Vários por id — para o "A receber" mostrar telefone sem N consultas. */
  findCustomersByIds(ids: string[]) {
    const db = this.tenant.getClient();
    if (ids.length === 0) return Promise.resolve([]);
    return db.customer.findMany({
      where: { id: { in: ids } },
      select: { id: true, name: true, phone: true },
    });
  }
```

Em `customers.service.ts`, após `getCustomer`:

```ts
  /**
   * Nome e telefone de vários clientes de uma vez. Porta do "A receber": quem
   * cobra precisa do telefone na linha, e fazer uma chamada por devedor seria
   * N+1 numa lista que já custa uma varredura.
   */
  async getCustomersByIds(
    _user: AuthUser,
    ids: string[],
  ): Promise<Array<{ id: string; name: string; phone: string | null }>> {
    if (ids.length === 0) return [];
    return this.tenant.withTenantTx(() => this.repo.findCustomersByIds(ids));
  }
```

- [ ] **Step 7: Lint + testes do backend**

Run: `npm run lint --workspace back && npm run test --workspace back 2>&1 | grep -E "Tests:|FAIL"`
Expected: 0 warnings; todos passando.

- [ ] **Step 8: Commit**

```bash
git add back/src/modules/cashier back/src/modules/customers
git commit -m "feat(cashier,customers): portas publicas para o A receber — proxima parcela em lote e telefone por ids

Regra 1: o modulo receivables nao le tabela alheia. Para classificar vencimento
e mostrar telefone na linha ele precisa de duas portas estreitas, em lote — uma
chamada por devedor seria N+1 numa lista que ja custa uma varredura.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `GET /receivables` com filtro, ordenação e paginação

**Files:**
- Create: `back/src/modules/receivables/dto/list-debtors.dto.ts`
- Modify: `back/src/modules/receivables/receivables.module.ts`
- Modify: `back/src/modules/receivables/receivables.service.ts` (`ReceivableCustomer`, construtor, `listCustomers`)
- Modify: `back/src/modules/receivables/receivables.controller.ts` (`listCustomers`)
- Modify: `back/src/modules/receivables/receivables.service.spec.ts` (fixtures do construtor)

**Interfaces:**
- Consumes: `classificar/filtrarDevedores/ordenarDevedores/paginar` (Task 1); `CashierService.proximasParcelasEmAberto`, `CustomersService.getCustomersByIds` (Task 2).
- Produces: resposta
  ```ts
  { items: ReceivableCustomer[]; total: number; page: number; pageSize: number;
    totalDue: number; overdueTotal: number; overdueCount: number;
    pendingSettlement: PendingSettlement; truncated: boolean }
  // ReceivableCustomer ganha: phone: string|null; nextDueAt: string|null; overdue: boolean
  ```

- [ ] **Step 1: DTO**

```ts
// back/src/modules/receivables/dto/list-debtors.dto.ts
import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ListDebtorsQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(['todos', 'vencidos', 'vence7', 'a_vencer'])
  vencimento?: 'todos' | 'vencidos' | 'vence7' | 'a_vencer';
  @IsOptional() @IsIn(['todos', 'os', 'sale']) origem?: 'todos' | 'os' | 'sale';
  @IsOptional() @IsIn(['valor', 'mais_antigo', 'nome', 'vencimento'])
  sort?: 'valor' | 'mais_antigo' | 'nome' | 'vencimento';
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
```

- [ ] **Step 2: Módulo importa Cashier e Customers**

```ts
// receivables.module.ts — trocar o bloco @Module e os imports
import { CashierModule } from '../cashier/cashier.module';
import { CustomersModule } from '../customers/customers.module';
// ...
@Module({
  // Cashier e Customers entram como PORTAS (próxima parcela em lote; telefone).
  // Sem ciclo: OS/Sale → Cashier, receivables → todos; ninguém aponta de volta.
  imports: [BillingModule, OsModule, SaleModule, CashierModule, CustomersModule],
  controllers: [ReceivablesController],
  providers: [ReceivablesService],
  exports: [ReceivablesService],
})
```

Atualize também o comentário do módulo: remova a frase "Não importa `CashierModule` porque não precisa" e escreva por que agora importa (parcelas em lote, regra 1).

- [ ] **Step 3: Service — tipo, construtor, `listCustomers(user, query)`**

Em `receivables.service.ts`:

```ts
// imports novos
import { CashierService } from '../cashier/cashier.service';
import { CustomersService } from '../customers/customers.service';
import {
  classificar, filtrarDevedores, ordenarDevedores, paginar,
  type DevedorParaFiltro, type OrdemDevedores, type Origem, type Vencimento,
} from './receivables.filtro';
import type { ListDebtorsQueryDto } from './dto/list-debtors.dto';

// ReceivableCustomer ganha 3 campos
export interface ReceivableCustomer {
  customerId: string | null;
  customerName: string;
  totalDue: number;
  titleCount: number;
  oldestAt: string | null;
  /** Telefone do cadastro — null para apelido de balcão. Para cobrar da linha. */
  phone: string | null;
  /** Vencimento mais próximo (parcela em aberto, senão data do título). */
  nextDueAt: string | null;
  /** Ao menos um título vencido. */
  overdue: boolean;
}

const DEBTORS_PAGE_SIZE = 20;

// construtor
constructor(
  private readonly os: OsService,
  private readonly sales: SaleService,
  private readonly cashier: CashierService,
  private readonly customers: CustomersService,
) {}

/** Devedores filtrados/ordenados/paginados no SERVIDOR. */
async listCustomers(user: AuthUser, query: ListDebtorsQueryDto = {}): Promise<{
  items: ReceivableCustomer[];
  total: number;
  page: number;
  pageSize: number;
  totalDue: number;
  overdueTotal: number;
  overdueCount: number;
  pendingSettlement: PendingSettlement;
  truncated: boolean;
}> {
  const { titulos, pendentes, truncated } = await this.openTitles(user);

  // 1) próxima parcela por título — UMA chamada ao caixa (regra 1)
  const proximas = await this.cashier.proximasParcelasEmAberto(
    user.tenantId,
    titulos.map((t) => ({ saleKind: t.title.origin, saleId: t.title.id })),
  );

  // 2) agrupa por devedor (MESMA chave da leitura: id, senão `nome:<apelido>`)
  const porCliente = new Map<string, DevedorParaFiltro>();
  for (const { title, customerId, customerName } of titulos) {
    const chave = customerId ?? `nome:${customerName}`;
    const titulo = {
      origin: title.origin,
      createdAt: title.createdAt,
      balance: title.balance,
      proximaParcelaEm: proximas.get(`${title.origin}:${title.id}`) ?? null,
    };
    const atual = porCliente.get(chave);
    if (atual) {
      atual.totalDue = round2(atual.totalDue + title.balance);
      atual.titleCount += 1;
      if (ehAnterior(title.createdAt, atual.oldestAt)) atual.oldestAt = title.createdAt;
      atual.titulos.push(titulo);
      continue;
    }
    porCliente.set(chave, {
      customerId, customerName,
      totalDue: round2(title.balance), titleCount: 1, oldestAt: title.createdAt,
      titulos: [titulo],
    });
  }

  // 3) telefone em lote — só dos cadastrados
  const ids = [...porCliente.values()].map((d) => d.customerId).filter((x): x is string => !!x);
  const contatos = new Map(
    (await this.customers.getCustomersByIds(user, ids)).map((c) => [c.id, c.phone]),
  );

  // 4) regra pura: classifica → filtra → ordena → pagina
  const hoje = new Date();
  const classificados = [...porCliente.values()].map((d) => classificar(d, hoje));
  const filtrados = filtrarDevedores(classificados, {
    q: query.q,
    vencimento: (query.vencimento ?? 'todos') as Vencimento,
    origem: (query.origem ?? 'todos') as Origem,
  }, hoje);
  const ordenados = ordenarDevedores(filtrados, (query.sort ?? 'valor') as OrdemDevedores);
  const pageSize = query.pageSize ?? DEBTORS_PAGE_SIZE;
  const page = query.page ?? 1;
  const pagina = paginar(ordenados, page, pageSize);

  const items: ReceivableCustomer[] = pagina.items.map((d) => ({
    customerId: d.customerId,
    customerName: d.customerName,
    totalDue: d.totalDue,
    titleCount: d.titleCount,
    oldestAt: d.oldestAt,
    phone: d.customerId ? (contatos.get(d.customerId) ?? null) : null,
    nextDueAt: d.nextDueAt,
    overdue: d.overdue,
  }));

  // Totais são da CARTEIRA INTEIRA (não da página nem do filtro): "quanto tenho
  // na rua" não pode mudar quando a pessoa clica num chip.
  const vencidos = classificados.filter((d) => d.overdue);
  return {
    items,
    total: pagina.total,
    page,
    pageSize,
    totalDue: round2(classificados.reduce((acc, c) => acc + c.totalDue, 0)),
    overdueTotal: round2(vencidos.reduce((acc, c) => acc + c.totalDue, 0)),
    overdueCount: vencidos.length,
    pendingSettlement: resumoPendentes(pendentes),
    truncated,
  };
}
```

Remova a antiga implementação de `listCustomers` (linhas ~193–239). Mantenha `listTitles`, `listOpenTitles`, `listPendingSettlement` como estão.

- [ ] **Step 4: Controller**

```ts
// receivables.controller.ts
import { ListDebtorsQueryDto } from './dto/list-debtors.dto';
// ...
  /** Devedores — filtrados, ordenados e paginados no servidor. */
  @Get()
  @Permissions('cashier.read')
  listCustomers(@CurrentUser() user: AuthUser, @Query() query: ListDebtorsQueryDto) {
    return this.receivables.listCustomers(user, query);
  }
```

- [ ] **Step 5: Ajustar o spec existente do service**

Em `receivables.service.spec.ts`, todo `new ReceivablesService(os, sales)` passa a receber dois deps a mais. Adicione um fake mínimo:

```ts
const cashierFake = { proximasParcelasEmAberto: jest.fn().mockResolvedValue(new Map()) } as never;
const customersFake = { getCustomersByIds: jest.fn().mockResolvedValue([]) } as never;
// new ReceivablesService(osFake, salesFake, cashierFake, customersFake)
```

E onde o teste chama `listCustomers(user)` continua válido (`query` tem default). Se algum teste asserta a forma da resposta (`toEqual({ items, totalDue, pendingSettlement, truncated })`), troque por `toMatchObject` com os campos que importam — a resposta ganhou `total/page/pageSize/overdueTotal/overdueCount`.

- [ ] **Step 6: Teste novo no spec — filtro no servidor e totais da carteira inteira**

Acrescente ao `receivables.service.spec.ts` (usando as fábricas `linha()`/fixtures já existentes no arquivo — leia-as antes):

```ts
describe('listCustomers com filtros (servidor)', () => {
  it('vencidos filtra, mas totalDue continua o da carteira inteira', async () => {
    // Monte 2 vendas fiadas, uma com parcela vencida (via cashierFake devolvendo
    // Map([['sale:v1','2026-01-01']])) e outra sem parcela e criada hoje.
    // Esperado: items.length === 1 (a vencida); totalDue === soma das DUAS.
  });
  it('a soma das páginas bate com total', async () => {
    // 3 devedores, pageSize 2: página 1 tem 2, página 2 tem 1, total 3 nas duas.
  });
});
```

Escreva os dois testes completos com as fixtures reais do arquivo — sem deixar só o comentário.

- [ ] **Step 7: tsc + lint + testes**

Run: `npx tsc --noEmit -p back/tsconfig.json && npm run lint --workspace back && npm run test --workspace back 2>&1 | grep -E "Tests:|FAIL"`
Expected: sem erros; 0 warnings; todos passando.

- [ ] **Step 8: Verificar contra a API viva (conciliação)**

Run:
```bash
cd /Users/gabriel.silva/project/OrbixHub && (lsof -ti tcp:4400 >/dev/null || (PORT=4400 npm run back:dev > /tmp/orbix-back.log 2>&1 &)); sleep 35
T=$(curl -s -X POST http://localhost:4400/api/auth/login -H 'Content-Type: application/json' -d '{"email":"dono@teste.com","password":"senha12345"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
for q in "" "vencimento=vencidos" "origem=sale" "sort=nome" "page=1&pageSize=2" "page=2&pageSize=2"; do
  printf "%-26s " "${q:-<sem filtro>}"
  curl -s "http://localhost:4400/api/receivables?$q" -H "Authorization: Bearer $T" | python3 -c "import sys,json;d=json.load(sys.stdin);print('itens=',len(d['items']),'total=',d['total'],'totalDue=',d['totalDue'],'vencido=',d['overdueTotal'])"
done
```
Expected: `totalDue` **igual** em todas as linhas; `total` igual entre `page=1` e `page=2`; `itens` de page1+page2 == total.

- [ ] **Step 9: Commit**

```bash
git add back/src/modules/receivables back/src/modules/receivables/dto
git commit -m "feat(receivables): GET /receivables filtra, ordena e pagina no servidor

q, vencimento (todos/vencidos/vence7/a_vencer), origem (os/sale), sort e page.
Totais (totalDue, overdueTotal) sao da CARTEIRA INTEIRA, nunca da pagina — 'quanto
tenho na rua' nao pode mudar quando se clica num chip. A regra e a pura de
receivables.filtro.ts. `truncated` permanece como sinal raro (varredura por
paginas dos services de OS/venda — regra 1 impede filtro na fonte).

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Modelos e contrato do repositório no front

**Files:**
- Create: `front/lib/features/receivables/domain/receivables_query.dart`
- Modify: `front/lib/features/receivables/domain/receivables_models.dart` (`Debtor`, `DebtorsPage`)
- Modify: `front/lib/features/receivables/domain/receivables_repository.dart`
- Modify: `front/lib/features/receivables/data/receivables_repository_impl.dart`
- Modify: `front/lib/features/receivables/data/fake_receivables_repository.dart`
- Modify: `front/lib/features/receivables/data/local_first_receivables_repository.dart` (só assinatura nesta task; regra no Task 6)

**Interfaces:**
- Produces:
  ```dart
  enum VencimentoFiltro { todos, vencidos, vence7, aVencer }   // wire: todos|vencidos|vence7|a_vencer
  enum OrigemFiltro { todos, os, sale }
  enum OrdemDevedores { valor, maisAntigo, nome, vencimento }  // wire: valor|mais_antigo|nome|vencimento
  class DebtorsQuery { final String? q; final VencimentoFiltro vencimento; final OrigemFiltro origem; final OrdemDevedores sort; final int page; final int pageSize; ... copyWith; Map<String,dynamic> toQuery(); }
  Future<DebtorsPage> listDebtors(DebtorsQuery query);
  // Debtor: + String? phone, String? nextDueAt, bool overdue
  // DebtorsPage: + int total, int page, int pageSize, num overdueTotal, int overdueCount
  ```

- [ ] **Step 1: `receivables_query.dart`**

```dart
/// Filtros do "A receber". Valor puro — vira query string online e parâmetros
/// da regra Dart offline. `page` começa em 1 (mesma convenção do backend).
enum VencimentoFiltro { todos, vencidos, vence7, aVencer }
enum OrigemFiltro { todos, os, sale }
enum OrdemDevedores { valor, maisAntigo, nome, vencimento }

extension VencimentoWire on VencimentoFiltro {
  String get wire => switch (this) {
        VencimentoFiltro.todos => 'todos',
        VencimentoFiltro.vencidos => 'vencidos',
        VencimentoFiltro.vence7 => 'vence7',
        VencimentoFiltro.aVencer => 'a_vencer',
      };
  String get rotulo => switch (this) {
        VencimentoFiltro.todos => 'Todos',
        VencimentoFiltro.vencidos => 'Vencidos',
        VencimentoFiltro.vence7 => 'Vence em 7 dias',
        VencimentoFiltro.aVencer => 'A vencer',
      };
}

extension OrigemWire on OrigemFiltro {
  String get wire => name; // todos | os | sale
  String get rotulo => switch (this) {
        OrigemFiltro.todos => 'Tudo',
        OrigemFiltro.os => 'OS',
        OrigemFiltro.sale => 'Venda de balcão',
      };
}

extension OrdemWire on OrdemDevedores {
  String get wire => switch (this) {
        OrdemDevedores.valor => 'valor',
        OrdemDevedores.maisAntigo => 'mais_antigo',
        OrdemDevedores.nome => 'nome',
        OrdemDevedores.vencimento => 'vencimento',
      };
  String get rotulo => switch (this) {
        OrdemDevedores.valor => 'Maior valor',
        OrdemDevedores.maisAntigo => 'Mais antigo',
        OrdemDevedores.nome => 'Nome (A–Z)',
        OrdemDevedores.vencimento => 'Vencimento',
      };
}

class DebtorsQuery {
  const DebtorsQuery({
    this.q,
    this.vencimento = VencimentoFiltro.todos,
    this.origem = OrigemFiltro.todos,
    this.sort = OrdemDevedores.valor,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? q;
  final VencimentoFiltro vencimento;
  final OrigemFiltro origem;
  final OrdemDevedores sort;
  final int page;
  final int pageSize;

  /// Há algum filtro que ESCONDE devedor? (busca ou chip fora de "todos")
  bool get temFiltroAtivo =>
      (q ?? '').trim().isNotEmpty ||
      vencimento != VencimentoFiltro.todos ||
      origem != OrigemFiltro.todos;

  static const _sentinel = Object();

  /// `q` com sentinela: `q ?? this.q` faria `null` (limpar a busca) devolver o
  /// texto antigo — o bug que já apareceu nas listas de OS/clientes/estoque.
  DebtorsQuery copyWith({
    Object? q = _sentinel,
    VencimentoFiltro? vencimento,
    OrigemFiltro? origem,
    OrdemDevedores? sort,
    int? page,
    int? pageSize,
  }) =>
      DebtorsQuery(
        q: q == _sentinel ? this.q : q as String?,
        vencimento: vencimento ?? this.vencimento,
        origem: origem ?? this.origem,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  Map<String, dynamic> toQuery() => {
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
        if (vencimento != VencimentoFiltro.todos) 'vencimento': vencimento.wire,
        if (origem != OrigemFiltro.todos) 'origem': origem.wire,
        if (sort != OrdemDevedores.valor) 'sort': sort.wire,
        'page': page,
        'pageSize': pageSize,
      };
}
```

- [ ] **Step 2: Modelos freezed**

Em `receivables_models.dart`:

```dart
// Debtor — acrescentar após oldestAt:
    /// Telefone do cadastro. Nulo para apelido de balcão — não há quem ligar.
    String? phone,
    /// Vencimento mais próximo (parcela em aberto, senão data do título).
    @JsonKey(name: 'nextDueAt') String? nextDueAt,
    /// Ao menos um título vencido.
    @Default(false) bool overdue,

// DebtorsPage — acrescentar:
    /// Nº de devedores APÓS o filtro (para a paginação). `items` é só a página.
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
    /// Quanto da carteira INTEIRA está vencido — não muda com filtro nem página.
    @JsonKey(name: 'overdueTotal') @Default(0) num overdueTotal,
    @JsonKey(name: 'overdueCount') @Default(0) int overdueCount,
```

Run: `cd front && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3: Contrato**

```dart
// receivables_repository.dart — substituir a declaração de listDebtors
import 'receivables_query.dart';
  /// Devedores filtrados, ordenados e paginados. Online vai ao servidor; offline
  /// aplica a MESMA regra sobre o espelho local (ver receivables_filtro.dart).
  Future<DebtorsPage> listDebtors(DebtorsQuery query);
```

- [ ] **Step 4: Impl dio**

```dart
  @override
  Future<DebtorsPage> listDebtors(DebtorsQuery query) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/receivables',
          queryParameters: query.toQuery(),
        );
        return DebtorsPage.fromJson(_asMap(res.data));
      });
```

- [ ] **Step 5: Fake e local-first — só compilar (regra no Task 6)**

No fake: `Future<DebtorsPage> listDebtors(DebtorsQuery query) async {` e, por enquanto, aplique apenas `q` (contains sem acento) e ordenação por `totalDue` desc; devolva `total: items.length, page: query.page, pageSize: query.pageSize`. No local-first: mude a assinatura e repasse `query` para `inner.listDebtors(query)` quando online; offline mantenha o comportamento atual (o Task 6 troca).

- [ ] **Step 6: Providers — query com debounce**

Em `receivables_providers.dart`, substitua `debtorsProvider`:

```dart
import 'dart:async';
import '../domain/receivables_query.dart';

class DebtorsQueryNotifier extends Notifier<DebtorsQuery> {
  Timer? _debounce;

  @override
  DebtorsQuery build() {
    ref.onDispose(() => _debounce?.cancel());
    return const DebtorsQuery();
  }

  /// Busca com espera — cada mudança de estado re-busca a lista inteira.
  void setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      final novo = q.isEmpty ? null : q;
      if (novo == state.q) return;
      state = state.copyWith(q: novo, page: 1);
    });
  }

  void setVencimento(VencimentoFiltro v) => state = state.copyWith(vencimento: v, page: 1);
  void setOrigem(OrigemFiltro o) => state = state.copyWith(origem: o, page: 1);
  void setSort(OrdemDevedores s) => state = state.copyWith(sort: s, page: 1);
  void goToPage(int p) => state = state.copyWith(page: p < 1 ? 1 : p);
  /// Zera o que esconde, preservando ordenação.
  void clearFilters() => state = DebtorsQuery(sort: state.sort);
}

/// autoDispose: sair da tela zera filtros (mesma decisão do Estoque — uma busca
/// abandonada não pode continuar filtrando quando a pessoa volta).
final debtorsQueryProvider =
    NotifierProvider.autoDispose<DebtorsQueryNotifier, DebtorsQuery>(
        DebtorsQueryNotifier.new);

final debtorsProvider = FutureProvider.autoDispose<DebtorsPage>((ref) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  final query = ref.watch(debtorsQueryProvider);
  return ref.read(receivablesRepositoryProvider).listDebtors(query);
});
```

- [ ] **Step 7: Corrigir os chamadores que ainda chamam `listDebtors()` sem argumento**

Run: `cd front && flutter analyze 2>&1 | grep -E "error •"` e corrija cada ponto (a aba antiga, testes `receivables_test`, `receivables_offline_test`, `receivables_impl_test`: passe `const DebtorsQuery()`).

- [ ] **Step 8: analyze + testes**

Run: `cd front && flutter analyze && flutter test test/receivables_test.dart test/receivables_offline_test.dart test/receivables_impl_test.dart`
Expected: 0 issues; passando.

- [ ] **Step 9: Commit**

```bash
git add front/lib/features/receivables front/test
git commit -m "feat(receivables): contrato listDebtors(DebtorsQuery) + modelos com telefone, vencimento e paginacao

Debtor ganha phone/nextDueAt/overdue; DebtorsPage ganha total/page/pageSize e
overdueTotal/overdueCount (da carteira inteira). Query com sentinela no `q` e
debounce no estado — os dois bugs que ja apareceram nas outras listas.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Regra Dart irmã + teste que lê a MESMA tabela

**Files:**
- Create: `front/lib/features/receivables/domain/receivables_filtro.dart`
- Create: `front/test/receivables_filtro_test.dart`

**Interfaces:**
- Consumes: `back/src/modules/receivables/receivables-filtro.casos.json` (Task 1).
- Produces:
  ```dart
  class TituloParaFiltro { final String origin; final String? createdAt; final num balance; final String? proximaParcelaEm; }
  class DevedorParaFiltro { customerId, customerName, totalDue, titleCount, oldestAt, List<TituloParaFiltro> titulos }
  class DevedorClassificado extends DevedorParaFiltro { String? nextDueAt; bool overdue; }
  String semAcento(String s)
  DevedorClassificado classificar(DevedorParaFiltro d, DateTime hoje)
  List<DevedorClassificado> filtrarDevedores(List<DevedorClassificado> l, {String? q, required VencimentoFiltro vencimento, required OrigemFiltro origem, required DateTime hoje})
  List<DevedorClassificado> ordenarDevedores(List<DevedorClassificado> l, OrdemDevedores ordem)
  ({List<T> items, int total}) paginar<T>(List<T> l, int page, int pageSize)
  ```

- [ ] **Step 1: Teste que lê o JSON do backend**

```dart
// front/test/receivables_filtro_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_filtro.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_query.dart';

/// Lê a MESMA tabela que o jest do backend lê. É o contrato online/offline: se
/// um lado mudar a regra sem o outro, os dois testes ficam vermelhos.
void main() {
  final arquivo = File('../back/src/modules/receivables/receivables-filtro.casos.json');
  final casos = jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
  final hoje = DateTime.parse(casos['hoje'] as String).toUtc();

  DevedorParaFiltro devedorDe(Map<String, dynamic> j) => DevedorParaFiltro(
        customerId: j['customerId'] as String?,
        customerName: j['customerName'] as String,
        totalDue: j['totalDue'] as num,
        titleCount: j['titleCount'] as int,
        oldestAt: j['oldestAt'] as String?,
        titulos: [
          for (final t in (j['titulos'] as List).cast<Map<String, dynamic>>())
            TituloParaFiltro(
              origin: t['origin'] as String,
              createdAt: t['createdAt'] as String?,
              balance: t['balance'] as num,
              proximaParcelaEm: t['proximaParcelaEm'] as String?,
            ),
        ],
      );

  final ids = <DevedorClassificado, String>{};
  final classificados = <DevedorClassificado>[];
  for (final j in (casos['devedores'] as List).cast<Map<String, dynamic>>()) {
    final c = classificar(devedorDe(j), hoje);
    ids[c] = j['id'] as String;
    classificados.add(c);
  }
  List<String> idsDe(List<DevedorClassificado> l) => [for (final d in l) ids[d]!];

  VencimentoFiltro venc(String w) =>
      VencimentoFiltro.values.firstWhere((v) => v.wire == w);
  OrigemFiltro orig(String w) => OrigemFiltro.values.firstWhere((v) => v.wire == w);
  OrdemDevedores ordem(String w) => OrdemDevedores.values.firstWhere((v) => v.wire == w);

  group('classificação', () {
    (casos['classificacao'] as Map<String, dynamic>).forEach((id, esperado) {
      test(id, () {
        final d = classificados.firstWhere((c) => ids[c] == id);
        final e = esperado as Map<String, dynamic>;
        expect(d.nextDueAt, e['nextDueAt']);
        expect(d.overdue, e['overdue']);
      });
    });
  });

  group('filtros', () {
    for (final c in (casos['filtros'] as List).cast<Map<String, dynamic>>()) {
      test(c['nome'] as String, () {
        final f = c['f'] as Map<String, dynamic>;
        final r = filtrarDevedores(
          classificados,
          q: f['q'] as String?,
          vencimento: venc(f['vencimento'] as String),
          origem: orig(f['origem'] as String),
          hoje: hoje,
        );
        expect(idsDe(r)..sort(), (c['esperado'] as List).cast<String>()..sort());
      });
    }
  });

  group('ordenações', () {
    for (final c in (casos['ordenacoes'] as List).cast<Map<String, dynamic>>()) {
      test(c['ordem'] as String, () {
        expect(idsDe(ordenarDevedores(classificados, ordem(c['ordem'] as String))),
            (c['esperado'] as List).cast<String>());
      });
    }
  });

  test('paginação', () {
    final p = casos['paginacao'] as Map<String, dynamic>;
    final r = paginar(
      ordenarDevedores(classificados, ordem(p['ordem'] as String)),
      p['page'] as int,
      p['pageSize'] as int,
    );
    expect(idsDe(r.items), (p['esperadoIds'] as List).cast<String>());
    expect(r.total, p['total']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd front && flutter test test/receivables_filtro_test.dart`
Expected: FAIL — `Target of URI doesn't exist: receivables_filtro.dart`.

- [ ] **Step 3: Implementar a irmã Dart**

```dart
// front/lib/features/receivables/domain/receivables_filtro.dart
import 'receivables_query.dart';

/// Regra PURA do "A receber" — irmã de `receivables.filtro.ts`. Existe porque
/// o offline recalcula a carteira das linhas locais e precisa filtrar/ordenar
/// igual ao servidor. As duas implementações rodam a MESMA tabela de casos.
class TituloParaFiltro {
  const TituloParaFiltro({
    required this.origin,
    required this.createdAt,
    required this.balance,
    required this.proximaParcelaEm,
  });
  final String origin; // 'os' | 'sale'
  final String? createdAt;
  final num balance;
  /// Próxima parcela em aberto (YYYY-MM-DD); null = sem plano.
  final String? proximaParcelaEm;
}

class DevedorParaFiltro {
  const DevedorParaFiltro({
    required this.customerId,
    required this.customerName,
    required this.totalDue,
    required this.titleCount,
    required this.oldestAt,
    required this.titulos,
  });
  final String? customerId;
  final String customerName;
  final num totalDue;
  final int titleCount;
  final String? oldestAt;
  final List<TituloParaFiltro> titulos;
}

class DevedorClassificado extends DevedorParaFiltro {
  const DevedorClassificado({
    required super.customerId,
    required super.customerName,
    required super.totalDue,
    required super.titleCount,
    required super.oldestAt,
    required super.titulos,
    required this.nextDueAt,
    required this.overdue,
  });
  final String? nextDueAt;
  final bool overdue;
}

String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString().toLowerCase();
}

/// "YYYY-MM-DD" em UTC — comparação por DIA, igual ao servidor.
String _diaUtc(String iso) => DateTime.parse(iso).toUtc().toIso8601String().substring(0, 10);

String? _vencimentoEfetivo(TituloParaFiltro t) => t.proximaParcelaEm ?? t.createdAt;

DevedorClassificado classificar(DevedorParaFiltro d, DateTime hoje) {
  final hojeDia = _diaUtc(hoje.toUtc().toIso8601String());
  String? nextDueAt;
  var overdue = false;
  for (final t in d.titulos) {
    final v = _vencimentoEfetivo(t);
    if (v == null) continue;
    if (nextDueAt == null || _diaUtc(v).compareTo(_diaUtc(nextDueAt)) < 0) nextDueAt = v;
    if (_diaUtc(v).compareTo(hojeDia) < 0) overdue = true;
  }
  return DevedorClassificado(
    customerId: d.customerId,
    customerName: d.customerName,
    totalDue: d.totalDue,
    titleCount: d.titleCount,
    oldestAt: d.oldestAt,
    titulos: d.titulos,
    nextDueAt: nextDueAt,
    overdue: overdue,
  );
}

List<DevedorClassificado> filtrarDevedores(
  List<DevedorClassificado> lista, {
  String? q,
  required VencimentoFiltro vencimento,
  required OrigemFiltro origem,
  required DateTime hoje,
}) {
  final hojeDia = _diaUtc(hoje.toUtc().toIso8601String());
  final limite7Dia = _diaUtc(hoje.toUtc().add(const Duration(days: 7)).toIso8601String());
  final termo = (q ?? '').trim().isEmpty ? '' : semAcento(q!.trim());

  return lista.where((d) {
    if (origem != OrigemFiltro.todos && !d.titulos.any((t) => t.origin == origem.wire)) return false;
    if (termo.isNotEmpty && !semAcento(d.customerName).contains(termo)) return false;
    switch (vencimento) {
      case VencimentoFiltro.todos:
        return true;
      case VencimentoFiltro.vencidos:
        return d.overdue;
      case VencimentoFiltro.vence7:
        if (d.overdue || d.nextDueAt == null) return false;
        final dia = _diaUtc(d.nextDueAt!);
        return dia.compareTo(hojeDia) >= 0 && dia.compareTo(limite7Dia) <= 0;
      case VencimentoFiltro.aVencer:
        return !d.overdue && d.nextDueAt != null;
    }
  }).toList();
}

int _porNome(DevedorClassificado a, DevedorClassificado b) =>
    semAcento(a.customerName).compareTo(semAcento(b.customerName));

List<DevedorClassificado> ordenarDevedores(
    List<DevedorClassificado> lista, OrdemDevedores ordem) {
  final copia = [...lista];
  switch (ordem) {
    case OrdemDevedores.valor:
      copia.sort((a, b) {
        final c = b.totalDue.compareTo(a.totalDue);
        return c != 0 ? c : _porNome(a, b);
      });
    case OrdemDevedores.maisAntigo:
      copia.sort((a, b) {
        if (a.oldestAt == b.oldestAt) return _porNome(a, b);
        if (a.oldestAt == null) return 1;
        if (b.oldestAt == null) return -1;
        return a.oldestAt!.compareTo(b.oldestAt!);
      });
    case OrdemDevedores.nome:
      copia.sort(_porNome);
    case OrdemDevedores.vencimento:
      copia.sort((a, b) {
        if (a.nextDueAt == b.nextDueAt) return _porNome(a, b);
        if (a.nextDueAt == null) return 1;
        if (b.nextDueAt == null) return -1;
        return _diaUtc(a.nextDueAt!).compareTo(_diaUtc(b.nextDueAt!));
      });
  }
  return copia;
}

({List<T> items, int total}) paginar<T>(List<T> lista, int page, int pageSize) {
  final p = page < 1 ? 1 : page;
  final inicio = (p - 1) * pageSize;
  if (inicio >= lista.length) return (items: <T>[], total: lista.length);
  return (items: lista.sublist(inicio, (inicio + pageSize).clamp(0, lista.length)), total: lista.length);
}
```

> Atenção ao `nome`: o TS usa `localeCompare('pt-BR', {sensitivity:'base'})`; o Dart usa `semAcento(...).compareTo`. Para os nomes da tabela (Ana, Bruno, Célia, Dário, Zeca) os dois dão a mesma ordem. Se um caso novo expuser diferença de colação (ex.: "ç" vs "c"), ajuste a tabela para evitar o caso ambíguo — o objetivo é regra igual, não colação perfeita.

- [ ] **Step 4: Rodar os DOIS lados**

Run: `cd front && flutter test test/receivables_filtro_test.dart && cd ../back && npx jest receivables.filtro`
Expected: ambos PASS lendo o mesmo JSON.

- [ ] **Step 5: Commit**

```bash
git add front/lib/features/receivables/domain/receivables_filtro.dart front/test/receivables_filtro_test.dart
git commit -m "feat(receivables): regra Dart irma do filtro, verificada pela MESMA tabela do backend

O teste Dart le back/src/modules/receivables/receivables-filtro.casos.json. Se
TS e Dart divergirem, os dois ficam vermelhos — e nao o relatorio em producao.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Offline aplica a regra (e corrige `a_receber` que faltava)

**Files:**
- Modify: `front/lib/features/receivables/data/local_first_receivables_repository.dart` (`listDebtors`, `_osFinalizadas`, `_titulosLocais`)
- Modify: `front/lib/features/receivables/data/fake_receivables_repository.dart` (`listDebtors` usa a regra)
- Test: `front/test/receivables_offline_test.dart` (novos casos)

**Interfaces:**
- Consumes: `classificar/filtrarDevedores/ordenarDevedores/paginar` (Task 5); `DebtorsQuery` (Task 4); linhas locais `receivable_installment` (`sale_kind`, `sale_id`, `due_date`, `paid_at`).

- [ ] **Step 1: Testes offline novos** (acrescente ao `receivables_offline_test.dart`, usando o harness `_InnerProibido`/`_montarLocal` já existente no arquivo — leia-o):

```dart
  group('filtros offline usam a MESMA regra do servidor', () {
    // Semeie 2 vendas fiadas locais (fiado_at != null, saldo > 0) e uma parcela
    // local VENCIDA (due_date ontem, paid_at null) ligada à primeira.
    test('vencidos devolve só quem tem parcela/título vencido', () async { /* ... */ });
    test('busca por apelido sem acento acha "Célia" com "celia"', () async { /* ... */ });
    test('totalDue não muda ao filtrar (é da carteira inteira)', () async { /* ... */ });
    test('OS em a_receber conta como finalizada (antes só concluida/entregue)', () async {
      // OS status 'a_receber' com saldo e SEM fiado_at → deve cair em pendentes.
    });
  });
```

Escreva os corpos completos com as fábricas do arquivo — nada de `/* ... */` no commit.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd front && flutter test test/receivables_offline_test.dart`
Expected: FAIL nos 4 novos.

- [ ] **Step 3: Implementar**

Em `local_first_receivables_repository.dart`:

```dart
import '../domain/receivables_filtro.dart';
import '../domain/receivables_query.dart';

  /// Espelha `FATURAVEIS` do servidor. `a_receber` FALTAVA aqui — a OS cujo
  /// status se chama "a receber" não caía em pendente de acerto sem rede.
  static const _osFinalizadas = {'concluida', 'a_receber', 'entregue'};
  static const _installments = 'receivable_installment';

  @override
  Future<DebtorsPage> listDebtors(DebtorsQuery query) async {
    if (isOnline()) return inner.listDebtors(query);

    final local = await _titulosLocais();
    // Próxima parcela em aberto por título — mesma porta que o servidor usa,
    // só que sobre o espelho local.
    final proximas = <String, String>{};
    final parcelas = (await rows(_installments))
        .where((r) => r['paid_at'] == null)
        .toList()
      ..sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));
    for (final r in parcelas) {
      proximas.putIfAbsent('${r['sale_kind']}:${r['sale_id']}', () => (r['due_date'] as String).substring(0, 10));
    }

    final porCliente = <String, DevedorParaFiltro>{};
    for (final t in local.fiado) {
      final chave = t.customerId ?? 'nome:${t.customerName}';
      final titulo = TituloParaFiltro(
        origin: t.title.origin,
        createdAt: t.title.createdAt,
        balance: t.title.balance,
        proximaParcelaEm: proximas['${t.title.origin}:${t.title.id}'],
      );
      final atual = porCliente[chave];
      porCliente[chave] = atual == null
          ? DevedorParaFiltro(
              customerId: t.customerId,
              customerName: t.customerName,
              totalDue: t.title.balance,
              titleCount: 1,
              oldestAt: t.title.createdAt,
              titulos: [titulo],
            )
          : DevedorParaFiltro(
              customerId: atual.customerId,
              customerName: atual.customerName,
              totalDue: _round2(atual.totalDue + t.title.balance),
              titleCount: atual.titleCount + 1,
              oldestAt: _maisAntigo(atual.oldestAt, t.title.createdAt),
              titulos: [...atual.titulos, titulo],
            );
    }

    final hoje = DateTime.now().toUtc();
    final classificados = porCliente.values.map((d) => classificar(d, hoje)).toList();
    final filtrados = filtrarDevedores(classificados,
        q: query.q, vencimento: query.vencimento, origem: query.origem, hoje: hoje);
    final pagina = paginar(ordenarDevedores(filtrados, query.sort), query.page, query.pageSize);
    final vencidos = classificados.where((d) => d.overdue);

    return DebtorsPage(
      items: [
        for (final d in pagina.items)
          Debtor(
            customerId: d.customerId,
            customerName: d.customerName,
            totalDue: d.totalDue,
            titleCount: d.titleCount,
            oldestAt: d.oldestAt,
            phone: null, // telefone vem do cadastro; offline a linha não o tem — Task 8 lê do espelho de `customer`
            nextDueAt: d.nextDueAt,
            overdue: d.overdue,
          ),
      ],
      total: pagina.total,
      page: query.page,
      pageSize: query.pageSize,
      totalDue: _round2(classificados.fold<num>(0, (a, d) => a + d.totalDue)),
      overdueTotal: _round2(vencidos.fold<num>(0, (a, d) => a + d.totalDue)),
      overdueCount: vencidos.length,
      pendingSettlement: PendingSettlement(
        count: local.pendentes.length,
        total: _round2(local.pendentes.fold<num>(0, (a, p) => a + p.title.balance)),
      ),
    );
  }
```

**Telefone offline:** leia o espelho local de `customer` (`rows('customer')`, colunas `id`, `phone`) e preencha `phone` para `customerId != null`. Se a entidade `customer` não estiver espelhada neste repositório, declare `static const _customers = 'customer';` e use `rows(_customers)` — a tabela já é sincronizada (ver `sync_engine.dart`).

- [ ] **Step 4: Fake usa a regra também**

No `fake_receivables_repository.dart`, `listDebtors(query)` monta `DevedorParaFiltro` a partir de `_titulos` (com `proximaParcelaEm: null`) e aplica `classificar → filtrarDevedores → ordenarDevedores → paginar`. Assim os testes de tela exercitam o mesmo comportamento.

- [ ] **Step 5: Rodar**

Run: `cd front && flutter analyze && flutter test test/receivables_offline_test.dart test/receivables_test.dart`
Expected: 0 issues; PASS.

- [ ] **Step 6: Commit**

```bash
git add front/lib/features/receivables/data front/test/receivables_offline_test.dart
git commit -m "feat(receivables): offline filtra/ordena/pagina com a mesma regra do servidor

Proxima parcela vem do espelho local de receivable_installment; telefone do
espelho de customer. De quebra: _osFinalizadas estava sem a_receber — OS nesse
status nao caia em pendente de acerto sem rede. E a classe de divergencia que a
tabela de casos existe para impedir.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Quebrar `receivables_tab.dart` em widgets reutilizáveis (mover, não reescrever)

**Files:**
- Create: `front/lib/features/receivables/presentation/widgets/debtor_tile.dart`
- Create: `front/lib/features/receivables/presentation/widgets/debtor_titles_dialog.dart`
- Create: `front/lib/features/receivables/presentation/widgets/pending_settlement.dart`
- Modify: `front/lib/features/receivables/presentation/receivables_tab.dart` (passa a importar os três; classes movidas saem daqui)

**Interfaces:**
- Produces (públicos):
  ```dart
  class DebtorTile extends ConsumerWidget { const DebtorTile({required Debtor debtor, required bool canWrite}); }
  Future<void> showDebtorTitlesDialog(BuildContext, {required String? customerId, required String customerName, required bool canWrite});
  class AvisoPendenteAcerto extends ConsumerWidget { const AvisoPendenteAcerto({required PendingSettlement resumo, required bool canWrite}); }
  ```
  (Leia os construtores atuais de `_DebtorTile`, `_AvisoPendenteAcerto` e a assinatura de `showDebtorTitlesDialog` em `receivables_tab.dart` e preserve os parâmetros exatos.)

- [ ] **Step 1: Mover blocos por linha (sem editar lógica)**

Use os intervalos do arquivo atual (confira com `grep -n "^class "` antes — os números abaixo são os de hoje):
- `debtor_tile.dart` ← `_DebtorTile` (542–654) + `_diasDesde` se estiver fora da classe. Renomeie `_DebtorTile` → `DebtorTile`.
- `debtor_titles_dialog.dart` ← `showDebtorTitlesDialog` (655–677), `_DebtorTitles` (678–760), `_TitleCard` (761–970), `_ScheduleList` (971–1071), `_StatusDot` (1072–1091). Estes internos podem continuar privados neste arquivo.
- `pending_settlement.dart` ← `_AvisoPendenteAcerto` (311–360) → `AvisoPendenteAcerto`, `_PendentesDialog` (361–416), `_PendenteTile` (417–511).

Cada arquivo novo recebe os imports que o bloco usa (copie do topo da aba e remova os não usados até `flutter analyze` ficar limpo).

- [ ] **Step 2: A aba passa a importar**

No topo de `receivables_tab.dart`:
```dart
import 'widgets/debtor_tile.dart';
import 'widgets/debtor_titles_dialog.dart';
import 'widgets/pending_settlement.dart';
```
e substitua `_DebtorTile(` → `DebtorTile(`, `_AvisoPendenteAcerto(` → `AvisoPendenteAcerto(`.

- [ ] **Step 3: analyze + testes da aba**

Run: `cd front && flutter analyze && flutter test test/receivables_test.dart test/receivables_impl_test.dart`
Expected: 0 issues; PASS sem alterar nenhum teste — é a prova de que foi mover, não reescrever.

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/receivables/presentation
git commit -m "refactor(receivables): widgets da aba saem para arquivos proprios (mover, nao reescrever)

DebtorTile, showDebtorTitlesDialog e AvisoPendenteAcerto passam a ser reusaveis
pela tela nova. Os testes da aba passam sem uma linha alterada.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: A tela `ReceivablesScreen` + faixa de filtros

**Files:**
- Create: `front/lib/features/receivables/presentation/receivables_filters_bar.dart`
- Create: `front/lib/features/receivables/presentation/receivables_screen.dart`
- Test: `front/test/receivables_screen_test.dart`

**Interfaces:**
- Consumes: `debtorsQueryProvider`, `debtorsProvider` (Task 4), `DebtorTile`, `AvisoPendenteAcerto`, `showDebtorTitlesDialog` (Task 7), `NeuSearchBar`, `NeuSegmented`, `NeuStatusChip`, `NeuPageControls`, `NeuListFooter`, `NeuEmptyState`, `OfflineScreenNotice`, `CoachTarget`.
- Produces: `class ReceivablesScreen extends ConsumerStatefulWidget { const ReceivablesScreen(); }`; alvos de tutorial `'areceber.resumo'`, `'areceber.filtros'`, `'areceber.lista'`.

- [ ] **Step 1: Teste de tela (harness igual ao de `receivables_test.dart`)**

```dart
// front/test/receivables_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_screen.dart';

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

Widget _app(FakeReceivablesRepository repo) => ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        receivablesRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: ReceivablesScreen())),
    );

void main() {
  testWidgets('topo mostra total na rua, vencido e nº de devedores', (t) async {
    await t.pumpWidget(_app(FakeReceivablesRepository()));
    await t.pumpAndSettle();
    expect(find.text('A receber'), findsOneWidget);
    expect(find.textContaining('Vencido'), findsOneWidget);
    expect(find.textContaining('devedor'), findsOneWidget);
  });

  testWidgets('chip "Vencidos" filtra a lista', (t) async {
    // Fake de exemplo: João (2 títulos, um antigo) e Maria. Com `proximaParcelaEm`
    // nulo a regra usa createdAt — o título de João (2026-07) está vencido; o de
    // Maria (criado "hoje" no fake) não.
    await t.pumpWidget(_app(FakeReceivablesRepository()));
    await t.pumpAndSettle();
    await t.tap(find.text('Vencidos'));
    await t.pumpAndSettle();
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Maria Souza'), findsNothing);
  });

  testWidgets('lista vazia por filtro oferece limpar, não "cadastre"', (t) async {
    await t.pumpWidget(_app(FakeReceivablesRepository(titulos: const [])));
    await t.pumpAndSettle();
    expect(find.textContaining('Ninguém devendo'), findsOneWidget);
  });

  testWidgets('sem cadastro leva o selo; cadastrado mostra telefone', (t) async {
    final repo = FakeReceivablesRepository(titulos: const [
      ReceivableTitle(id: 't1', origin: 'sale', number: 'VND-1', customerId: 'c1',
          customerName: 'João Silva', total: 10, balance: 10),
      ReceivableTitle(id: 't2', origin: 'sale', number: 'VND-2',
          customerName: 'Zeca', total: 5, balance: 5),
    ]);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    expect(find.text('Sem cadastro'), findsOneWidget);
  });
}
```

Ajuste os fixtures do `FakeReceivablesRepository` conforme as datas reais do `_exemplo` (leia `_exemplo` e `_donos` no fake). Se o fake não expuser `phone`, adicione um mapa `_telefones` opcional ao construtor.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd front && flutter test test/receivables_screen_test.dart`
Expected: FAIL — `receivables_screen.dart` não existe.

- [ ] **Step 3: Faixa de filtros**

```dart
// receivables_filters_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../domain/receivables_query.dart';
import 'receivables_providers.dart';

/// Busca + chips de vencimento + origem + ordenação. Chips, não menus: a
/// escolha fica VISÍVEL sem abrir nada — critério da tela é ser fácil.
class ReceivablesFiltersBar extends ConsumerStatefulWidget {
  const ReceivablesFiltersBar({super.key});
  @override
  ConsumerState<ReceivablesFiltersBar> createState() => _ReceivablesFiltersBarState();
}

class _ReceivablesFiltersBarState extends ConsumerState<ReceivablesFiltersBar> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(debtorsQueryProvider);
    final n = ref.read(debtorsQueryProvider.notifier);
    final isMobile = context.isMobile;

    final vencimento = NeuSegmented<VencimentoFiltro>(
      segments: {for (final v in VencimentoFiltro.values) v: v.rotulo},
      selected: q.vencimento,
      onChanged: n.setVencimento,
    );
    final origem = NeuSegmented<OrigemFiltro>(
      segments: {for (final o in OrigemFiltro.values) o: o.rotulo},
      selected: q.origem,
      onChanged: n.setOrigem,
    );
    final ordem = PopupMenuButton<OrdemDevedores>(
      tooltip: 'Ordenar',
      initialValue: q.sort,
      onSelected: n.setSort,
      itemBuilder: (_) => [
        for (final o in OrdemDevedores.values)
          PopupMenuItem(value: o, child: Text(o.rotulo)),
      ],
      child: NeuStatusChip(
        label: q.sort.rotulo,
        color: context.neu.inkMuted,
        tint: context.neu.inkMuted.withValues(alpha: .14),
        icon: Icons.swap_vert_rounded,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 380),
              child: NeuSearchBar(
                hint: 'Buscar devedor',
                controller: _busca,
                onChanged: n.setQuery,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ordem,
        ]),
        const SizedBox(height: 10),
        // Wrap: no celular os dois segmentados empilham; no desktop ficam lado a lado.
        Wrap(spacing: 12, runSpacing: 10, children: [vencimento, origem]),
      ],
    );
  }
}
```

- [ ] **Step 4: A tela**

```dart
// receivables_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/coach_targets.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../cashier/domain/cashier_format.dart';
import '../domain/receivables_models.dart';
import 'credit_sale_dialog.dart';
import 'receivables_filters_bar.dart';
import 'receivables_providers.dart';
import 'widgets/debtor_tile.dart';
import 'widgets/pending_settlement.dart';

/// "A receber" — controle de quem está devendo: vendas a prazo, parcelas, OS
/// entregues e não acertadas. Responde, nesta ordem: quanto tenho na rua (e
/// quanto está vencido), quem deve, de quê.
class ReceivablesScreen extends ConsumerStatefulWidget {
  const ReceivablesScreen({super.key});
  @override
  ConsumerState<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends ConsumerState<ReceivablesScreen> {
  final _scroll = ScrollController();

  bool _has(String p) =>
      ref.read(sessionControllerProvider).meOrNull?.hasPermission(p) ?? false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final canWrite = _has('cashier.write');
    final canSale = _has('sale.write');
    final pagina = ref.watch(debtorsProvider);
    final query = ref.watch(debtorsQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isMobile && canSale)
          ? FloatingActionButton.extended(
              onPressed: () => showCreditSaleDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Venda a prazo'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OfflineScreenNotice(
              message: 'Você está offline. A carteira mostrada é a deste aparelho; '
                  'recebimentos ficam guardados e sobem quando a conexão voltar.',
            ),
            Row(children: [
              Expanded(child: Text('A receber', style: Theme.of(context).textTheme.titleLarge)),
              if (!isMobile && canSale)
                NeuButton(
                  label: 'Venda a prazo',
                  icon: Icons.add,
                  onPressed: () => showCreditSaleDialog(context),
                ),
            ]),
            const SizedBox(height: 12),
            CoachTarget('areceber.resumo', child: _Resumo(pagina: pagina)),
            const SizedBox(height: 12),
            const CoachTarget('areceber.filtros', child: ReceivablesFiltersBar()),
            const SizedBox(height: 12),
            Expanded(
              child: CoachTarget(
                'areceber.lista',
                child: pagina.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Não foi possível carregar: $e'),
                      const SizedBox(height: 12),
                      NeuButton(
                        label: 'Tentar de novo',
                        kind: NeuButtonKind.secondary,
                        icon: Icons.refresh,
                        onPressed: () => ref.invalidate(debtorsProvider),
                      ),
                    ]),
                  ),
                  data: (p) => _lista(context, p, query, canWrite, isMobile),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, DebtorsPage p, DebtorsQuery query, bool canWrite, bool isMobile) {
    if (p.items.isEmpty) {
      if (query.temFiltroAtivo) {
        return NeuEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Nenhum devedor com os filtros ativos',
          message: 'A carteira continua aqui — a busca ou os filtros estão escondendo todos.',
          actionLabel: 'Limpar filtros',
          onAction: () => ref.read(debtorsQueryProvider.notifier).clearFilters(),
        );
      }
      return const NeuEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Ninguém devendo',
        message: 'Vendas a prazo e OS entregues sem acerto aparecem aqui.',
      );
    }
    final lista = ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.only(bottom: isMobile ? 88 : 8),
      itemCount: p.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(children: [
            if (p.pendingSettlement.count > 0) ...[
              AvisoPendenteAcerto(resumo: p.pendingSettlement, canWrite: canWrite),
              const SizedBox(height: 10),
            ],
            if (p.truncated) ...[
              const _AvisoTruncado(),
              const SizedBox(height: 10),
            ],
            DebtorTile(debtor: p.items[0], canWrite: canWrite),
          ]);
        }
        return DebtorTile(debtor: p.items[i], canWrite: canWrite);
      },
    );
    return Column(children: [
      Expanded(child: lista),
      const SizedBox(height: 12),
      NeuPageControls(
        page: p.page,
        pageSize: p.pageSize,
        total: p.total,
        onPage: (n) => ref.read(debtorsQueryProvider.notifier).goToPage(n),
      ),
    ]);
  }
}

/// Topo: total na rua, quanto está vencido (em vermelho), quantos devem.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.pagina});
  final AsyncValue<DebtorsPage> pagina;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final p = pagina.value;
    Widget kpi(String rotulo, String valor, {Color? cor}) => Expanded(
          child: NeuCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rotulo, style: TextStyle(color: neu.inkMuted, fontSize: 14)),
              const SizedBox(height: 6),
              Text(valor, style: TextStyle(color: cor ?? neu.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    return Row(children: [
      kpi('Na rua', p == null ? '—' : formatMoney(p.totalDue)),
      const SizedBox(width: 10),
      kpi('Vencido', p == null ? '—' : formatMoney(p.overdueTotal), cor: neu.danger),
      const SizedBox(width: 10),
      kpi(p != null && p.total == 1 ? 'devedor' : 'devedores', p == null ? '—' : '${p.total}'),
    ]);
  }
}

class _AvisoTruncado extends StatelessWidget {
  const _AvisoTruncado();
  @override
  Widget build(BuildContext context) => NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: context.neu.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A carteira é muito grande e a lista pode estar incompleta. '
              'Use os filtros para estreitar.',
              style: TextStyle(color: context.neu.inkMuted, fontSize: 14),
            ),
          ),
        ]),
      );
}
```

`showCreditSaleDialog` vem no Task 9; para esta task compilar, crie `credit_sale_dialog.dart` com um stub `Future<void> showCreditSaleDialog(BuildContext context) async {}` e substitua no Task 9.

- [ ] **Step 5: Telefone e vencimento na linha — atualizar `DebtorTile`**

Em `widgets/debtor_tile.dart`, sob o nome (após o selo "Sem cadastro"), acrescente:

```dart
                        if ((debtor.phone ?? '').isNotEmpty) ...[
                          Icon(Icons.phone_outlined, size: 14, color: neu.inkMuted),
                          const SizedBox(width: 4),
                          Text(debtor.phone!, style: TextStyle(color: neu.inkMuted, fontSize: 12)),
                          const SizedBox(width: 8),
                        ],
                        if (debtor.nextDueAt != null)
                          NeuStatusChip(
                            label: debtor.overdue
                                ? 'Vencido em ${_dataCurta(debtor.nextDueAt!)}'
                                : 'Vence em ${_dataCurta(debtor.nextDueAt!)}',
                            color: debtor.overdue ? neu.danger : neu.warning,
                            tint: debtor.overdue ? neu.dangerTint : neu.warningTint,
                            icon: debtor.overdue ? Icons.error_outline : Icons.event_outlined,
                          ),
```

e a função:
```dart
String _dataCurta(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}';
}
```

- [ ] **Step 6: Rodar**

Run: `cd front && flutter analyze && flutter test test/receivables_screen_test.dart test/receivables_test.dart`
Expected: 0 issues; PASS.

- [ ] **Step 7: Commit**

```bash
git add front/lib/features/receivables/presentation front/test/receivables_screen_test.dart
git commit -m "feat(receivables): tela 'A receber' — resumo, chips de filtro, telefone e vencimento na linha

Chips em vez de menus (a escolha fica visivel), totais da carteira inteira no
topo, vazio-por-filtro oferece limpar em vez de 'cadastre'. Reusa DebtorTile e
o dialogo de titulos movidos da aba.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Modal "Registrar venda a prazo"

**Files:**
- Modify: `front/lib/features/sale/presentation/sale_create_dialog.dart` (`showSaleCreateDialog` ganha `modoPrazo`; `_SaleCreateDialog` recebe e usa)
- Create/Replace: `front/lib/features/receivables/presentation/credit_sale_dialog.dart`
- Test: `front/test/credit_sale_dialog_test.dart`

**Interfaces:**
- Consumes: `showSaleCreateDialog(context, {refazerDe, editando})` (existente), `SaleDraft(fiado:)`, `cashierRepositoryProvider.createInstallmentPlan(InstallmentPlanDraft)`, `showNeuWarningSnackBar`.
- Produces: `Future<void> showCreditSaleDialog(BuildContext context)`; `showSaleCreateDialog(..., {bool modoPrazo = false})`.

**Desenho (por que não um diálogo do zero):** o de venda já tem itens, desconto, estoque com aviso, cliente e validação. Um modo `prazo` muda três coisas e reusa o resto — duplicar o diálogo geraria dois cálculos de total que divergem. As três diferenças: (1) cliente cadastrado em destaque, com aviso quando só há apelido; (2) o bloco de recebimento some e `fiado: true` é fixo; (3) um bloco de parcelamento opcional que, ao salvar, chama `createInstallmentPlan` com o `id` da venda criada.

- [ ] **Step 1: Teste**

```dart
// front/test/credit_sale_dialog_test.dart
// Harness: copie `_wrap`/overrides de test/sale_cadastro_sem_sair_test.dart
// (FakeSaleRepository, FakeInventoryRepository, FakeCustomersRepository, FakeCashierRepository).
void main() {
  testWidgets('modo prazo: sem bloco de recebimento e com parcelamento', (t) async {
    // abre showSaleCreateDialog(ctx, modoPrazo: true)
    // expect(find.text('Recebido'), findsNothing);   // bloco de pagamento ausente
    // expect(find.text('Parcelar'), findsOneWidget);
  });
  testWidgets('sem cliente cadastrado avisa que apelido não tem telefone', (t) async {
    // expect(find.textContaining('sem telefone'), findsOneWidget);
  });
  testWidgets('salvar com 3 parcelas cria a venda fiada E o plano', (t) async {
    // FakeSaleRepository.criadas.last.fiado == true
    // FakeCashierRepository.planos.length == 1 && .installmentCount == 3
  });
  testWidgets('falha no plano NÃO desfaz a venda e avisa', (t) async {
    // FakeCashierRepository que lança em createInstallmentPlan
    // venda criada; find.textContaining('parcelamento não foi gravado')
  });
}
```

Escreva os quatro corpos completos com os fakes reais (leia `fake_sale_repository.dart` e `fake_cashier_repository.dart` para ver o que já é observável; acrescente `List<InstallmentPlanDraft> planos` ao fake do caixa se não existir).

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd front && flutter test test/credit_sale_dialog_test.dart`
Expected: FAIL — `modoPrazo` não é parâmetro.

- [ ] **Step 3: `modoPrazo` no diálogo de venda**

```dart
// sale_create_dialog.dart
Future<Sale?> showSaleCreateDialog(
  BuildContext context, {
  List<SaleItem>? refazerDe,
  Sale? editando,
  /// Venda A PRAZO ("A receber"): nasce fiada, sem bloco de recebimento, com
  /// parcelamento opcional e cliente cadastrado em destaque.
  bool modoPrazo = false,
}) { /* ... builder: _SaleCreateDialog(refazerDe:, editando:, modoPrazo: modoPrazo) */ }

class _SaleCreateDialog extends ConsumerStatefulWidget {
  const _SaleCreateDialog({this.refazerDe, this.editando, this.modoPrazo = false});
  final bool modoPrazo;
  // ...
}
```

No estado, acrescente:
```dart
  // parcelamento (só modoPrazo)
  bool _parcelar = false;
  int _parcelas = 2;
  int _diaVencimento = DateTime.now().day.clamp(1, 28);
  DateTime? _primeiraParcela;
```

Em `_ehFiado`: `bool get _ehFiado => widget.modoPrazo || _split.ehFiado;`
Em `_recebido`: `if (widget.modoPrazo) return 0;` antes do resto.

No `build`, onde está `if (widget.editando == null) _PaymentSection(...)`, troque por:
```dart
                      if (widget.editando == null && !widget.modoPrazo) _PaymentSection(/* como está */),
                      if (widget.modoPrazo) _ParcelamentoSection(
                        ativo: _parcelar,
                        parcelas: _parcelas,
                        diaVencimento: _diaVencimento,
                        primeira: _primeiraParcela,
                        total: _total,
                        onAtivo: (v) => setState(() => _parcelar = v),
                        onParcelas: (v) => setState(() => _parcelas = v),
                        onDia: (v) => setState(() => _diaVencimento = v),
                        onPrimeira: (d) => setState(() => _primeiraParcela = d),
                      ),
```

Na seção de cliente, logo após o `TextField` do apelido (dentro de `if (_customerId == null)`), acrescente:
```dart
                        if (widget.modoPrazo)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              Icon(Icons.info_outline, size: 16, color: context.neu.warning),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                'Apelido fica sem telefone — para cobrar depois, prefira um cliente cadastrado.',
                                style: TextStyle(color: context.neu.warning, fontSize: 12),
                              )),
                            ]),
                          ),
```

No título do diálogo, se houver `Text('Venda avulsa')`/similar: `widget.modoPrazo ? 'Venda a prazo' : <atual>`.

No `_submit` (caminho de criação), após `final sale = await ...createSale(draft);` e ANTES do lançamento no caixa (que em modoPrazo não acontece, pois `_aLancarNoCaixa == 0`):
```dart
      String? avisoParcelas;
      if (widget.modoPrazo && _parcelar) {
        try {
          await ref.read(cashierRepositoryProvider).createInstallmentPlan(InstallmentPlanDraft(
            saleKind: 'sale',
            saleId: sale.id,
            installmentCount: _parcelas,
            dueDayOfMonth: _diaVencimento,
            totalAmount: _total,
            firstDueDate: _primeiraParcela?.toIso8601String().substring(0, 10),
          ));
        } catch (e) {
          // A venda ficou gravada — o dinheiro não mudou de mão. Só o plano faltou.
          avisoParcelas = 'Venda registrada, mas o parcelamento não foi gravado ($e). '
              'Abra o devedor em "A receber" e parcele por lá.';
        }
      }
```
e, no bloco `if (mounted)` final, depois do SnackBar de sucesso: `if (avisoParcelas != null) showNeuWarningSnackBar(context, avisoParcelas);`. Em modoPrazo, pule `_confirmarFiado()` (a pessoa já escolheu "a prazo" ao abrir o modal) e faça `ref.invalidate(debtorsProvider)` após criar (import de `receivables_providers.dart`).

- [ ] **Step 4: `_ParcelamentoSection`**

```dart
class _ParcelamentoSection extends StatelessWidget {
  const _ParcelamentoSection({
    required this.ativo, required this.parcelas, required this.diaVencimento,
    required this.primeira, required this.total,
    required this.onAtivo, required this.onParcelas, required this.onDia, required this.onPrimeira,
  });
  final bool ativo; final int parcelas; final int diaVencimento; final DateTime? primeira; final double total;
  final ValueChanged<bool> onAtivo; final ValueChanged<int> onParcelas; final ValueChanged<int> onDia; final ValueChanged<DateTime?> onPrimeira;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final porParcela = parcelas > 0 ? total / parcelas : 0.0;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Parcelar'),
          subtitle: Text(ativo
              ? '$parcelas× de ${formatMoney(porParcela)}'
              : 'Sem parcelas: fica tudo a receber de uma vez'),
          value: ativo,
          onChanged: onAtivo,
        ),
        if (ativo) ...[
          Row(children: [
            Expanded(child: NeuStepperField(
              value: parcelas.toDouble(), decimals: 0, semanticLabel: 'Parcelas',
              onChanged: (v) => onParcelas(v.round().clamp(1, 60)),
            )),
            const SizedBox(width: 10),
            Expanded(child: NeuStepperField(
              value: diaVencimento.toDouble(), decimals: 0, semanticLabel: 'Dia do vencimento',
              onChanged: (v) => onDia(v.round().clamp(1, 28)),
            )),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: primeira ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              onPrimeira(d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(primeira == null
                ? '1ª parcela: próximo dia $diaVencimento'
                : '1ª parcela: ${primeira!.day.toString().padLeft(2, '0')}/${primeira!.month.toString().padLeft(2, '0')}/${primeira!.year}'),
          ),
          Text('Rótulos e limites iguais aos do recebimento (1–60 parcelas, dia 1–28).',
              style: TextStyle(color: neu.inkFaint, fontSize: 12)),
        ],
      ]),
    );
  }
}
```

Confira a assinatura real de `NeuStepperField` (usada em `_LineTile`) e adapte os parâmetros.

- [ ] **Step 5: `credit_sale_dialog.dart`**

```dart
import 'package:flutter/material.dart';
import '../../sale/presentation/sale_create_dialog.dart';

/// "Registrar venda a prazo" — o mesmo diálogo da venda, em modo a prazo. Existe
/// para quem está no "A receber" não precisar ir ao Caixa só para fiar.
Future<void> showCreditSaleDialog(BuildContext context) =>
    showSaleCreateDialog(context, modoPrazo: true);
```

- [ ] **Step 6: Rodar**

Run: `cd front && flutter analyze && flutter test test/credit_sale_dialog_test.dart test/sale_cadastro_sem_sair_test.dart`
Expected: 0 issues; PASS (o teste da venda comum continua verde — modoPrazo default false).

- [ ] **Step 7: Commit**

```bash
git add front/lib/features/sale/presentation/sale_create_dialog.dart front/lib/features/receivables/presentation/credit_sale_dialog.dart front/test/credit_sale_dialog_test.dart front/lib/features/cashier/data/fake_cashier_repository.dart
git commit -m "feat(receivables): modal 'Venda a prazo' — o dialogo da venda em modo prazo

Nasce fiada, sem bloco de recebimento, com parcelamento opcional
(POST /cashier/installments, que ja existe) e cliente cadastrado em destaque —
apelido nao tem telefone. Reusa o dialogo em vez de duplicar: dois calculos de
total divergem. Plano que falha nao desfaz a venda (o dinheiro nao mudou de mao);
a tela avisa.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Rota, menu, botão no Caixa e tutorial

**Files:**
- Modify: `front/lib/core/router/app_router.dart` (import + rota literal antes de `/m/:moduleKey`, junto da `/m/cashier`)
- Modify: `front/lib/features/shell/presentation/nav_items.dart` (`addAReceber()` após `addModule('cashier')`)
- Modify: `front/lib/features/cashier/presentation/cashier_screen.dart` (ação "A receber" no `_AcoesGrid`)
- Modify: `front/lib/features/shell/presentation/screen_tutorials.dart` (novo tutorial `_aReceber`; passo `caixa.abas` deixa de citar Fiado)
- Modify: `front/test/coach_targets_test.dart` (`_telas` ganha 'A receber')
- Test: `front/test/nav_items_test.dart` (ou o existente que cobre `gatedNavItems` — grep `gatedNavItems` em `front/test`)

- [ ] **Step 1: Teste do menu**

No teste existente de `gatedNavItems` (grep), acrescente:
```dart
  test('A receber entra logo abaixo de Caixa, só com módulo cashier e cashier.read', () {
    final com = gatedNavItems(_me(modules: ['cashier'], permissions: ['cashier.read']));
    final rotas = com.map((i) => i.route).toList();
    expect(rotas.indexOf('/m/cashier/a-receber'), rotas.indexOf('/m/cashier') + 1);
    final sem = gatedNavItems(_me(modules: ['cashier'], permissions: ['cashier.write']));
    expect(sem.map((i) => i.route), isNot(contains('/m/cashier/a-receber')));
  });
```
(Use a fábrica `_me(...)` do arquivo; se não existir, crie uma que monte `Me` com `modules` e `permissions`.)

- [ ] **Step 2: Rodar e ver falhar** — `flutter test test/<arquivo do gatedNavItems>`.

- [ ] **Step 3: Menu**

```dart
// nav_items.dart — após a função addMensagens
  /// "A receber" não é módulo: é parte comercial do Caixa (mesmo gate do
  /// controller de receivables: módulo `cashier` + `cashier.read`). Item
  /// próprio porque cobrar é outro trabalho que operar a gaveta.
  void addAReceber() {
    if (!me.modules.contains('cashier') || !me.hasPermission('cashier.read')) return;
    items.add(const NavItem('A receber', Icons.request_quote_outlined, '/m/cashier/a-receber'));
  }
// ORDEM DA SIDEBAR:
  addModule('cashier');
  addAReceber();
  addModule('os');
```

- [ ] **Step 4: Rota**

```dart
// app_router.dart
import '../../features/receivables/presentation/receivables_screen.dart';
// ...
          GoRoute(
            path: '/m/cashier',
            pageBuilder: (_, s) => neuPage(s, const CashierScreen()),
          ),
          // A receber — sub-rota do Caixa: o redirect lê o segmento `/m/<módulo>`,
          // então ela herda o gate do módulo `cashier` sem código novo.
          GoRoute(
            path: '/m/cashier/a-receber',
            pageBuilder: (_, s) => neuPage(s, const ReceivablesScreen()),
          ),
```

Confirme no `redirect` (linha ~127) que `segments[2]` para `/m/cashier/a-receber` é `'cashier'` (é: `['', 'm', 'cashier', 'a-receber']`).

- [ ] **Step 5: Botão no Caixa**

Em `cashier_screen.dart`, no `_AcoesGrid` do `_FreeBody`, após a ação 'Receber OS':
```dart
                if (canFiado)
                  _Acao(
                    label: 'A receber',
                    icon: Icons.request_quote_outlined,
                    cor: context.neu.warning,
                    onTap: () => context.go('/m/cashier/a-receber'),
                  ),
```
`_FreeBody` precisa receber `canFiado` (passe `_canReadReceivables()` de quem o constrói) e o arquivo precisa `import 'package:go_router/go_router.dart';` se ainda não tiver. Atualize o comentário acima do grid ("Fiado tem aba própria") para "A receber tem tela própria".

- [ ] **Step 6: Tutorial**

Em `screen_tutorials.dart`: no passo `caixa.abas` do `_caixa`, o texto passa a descrever duas abas (Caixa do dia / Histórico) e a dizer que "A receber" virou item de menu. Acrescente um tutorial novo e registre-o onde os demais estão (grep `_caixa,` para achar a lista):
```dart
const _aReceber = ScreenTutorial(
  id: 'tut_areceber_v1',
  titulo: 'A receber',
  steps: [
    CoachStep(
      targetName: 'areceber.resumo',
      title: 'Quanto tem na rua',
      text: 'Total a receber, quanto disso já venceu e quantas pessoas devem. Esses números são da carteira inteira — não mudam quando você filtra.',
    ),
    CoachStep(
      targetName: 'areceber.filtros',
      title: 'Quem cobro hoje',
      text: '"Vencidos" é a fila de cobrança. "Vence em 7 dias" é quem avisar antes. Dá para separar OS de venda de balcão e ordenar por valor, atraso, nome ou vencimento.',
    ),
    CoachStep(
      targetName: 'areceber.lista',
      title: 'Quem deve, e de quê',
      text: 'Cada linha traz telefone e a próxima parcela. Toque para ver os títulos, as parcelas e receber — total ou parcela.',
    ),
  ],
);
```

- [ ] **Step 7: `coach_targets_test.dart`**

Em `_telas`, acrescente:
```dart
  'A receber': (
    tela: const ReceivablesScreen(),
    alvos: ['areceber.resumo', 'areceber.filtros', 'areceber.lista'],
  ),
```
com o import e, se o harness não sobrescrever `receivablesRepositoryProvider`, acrescente `receivablesRepositoryProvider.overrideWithValue(FakeReceivablesRepository())` aos overrides.

- [ ] **Step 8: Rodar**

Run: `cd front && flutter analyze && flutter test`
Expected: 0 issues; tudo passando.

- [ ] **Step 9: Commit**

```bash
git add front/lib/core/router/app_router.dart front/lib/features/shell front/lib/features/cashier/presentation/cashier_screen.dart front/test
git commit -m "feat(receivables): rota /m/cashier/a-receber, item de menu abaixo de Caixa, botao no Caixa e tutorial

Sub-rota do Caixa para herdar o gate do modulo pelo redirect (segmento /m/<modulo>).
Item de menu gated por cashier + cashier.read — as mesmas regras do controller.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: A aba sai do Caixa; limpeza

**Files:**
- Modify: `front/lib/features/cashier/presentation/cashier_screen.dart` (remove aba `Fiado`, `_tab == 1`, import da aba)
- Delete: `front/lib/features/receivables/presentation/receivables_tab.dart`
- Modify: `front/test/receivables_test.dart`, `front/test/receivables_impl_test.dart` (montam `ReceivablesScreen` no lugar de `ReceivablesTab`)
- Modify: `front/test/cashier_sem_sessao_test.dart` (asserções que citam a aba Fiado)

- [ ] **Step 1: Caixa sem a aba**

Em `cashier_screen.dart`: remova `if (canFiado) 1: 'Fiado',` do mapa `segments`; remova `if (_tab == 1 && canFiado) return ReceivablesTab(...)`; remova o import de `receivables_tab.dart`. Se `canFiado` só era usado aí e no botão (Task 10), mantenha-o pelo botão. Ajuste o comentário "Abas montadas conforme o papel".

- [ ] **Step 2: Testes que montavam a aba**

Em `receivables_test.dart` e `receivables_impl_test.dart`: `ReceivablesTab(canWrite: x)` → `const ReceivablesScreen()` e, onde `canWrite` era falso, sobrescreva `sessionControllerProvider` com um `Me` sem `cashier.write` (copie o padrão `_FakeSession` de `inventory_screen_test.dart`). Asserções sobre textos da aba ("Quem deve") passam a usar os da tela ("A receber", "Na rua").

Em `cashier_sem_sessao_test.dart`: qualquer `find.text('Fiado')` sobre as abas vira `findsNothing`, e o teste do grid de ações passa a esperar 'A receber' quando `cashier.read`.

- [ ] **Step 3: Remover o arquivo**

Run: `git rm front/lib/features/receivables/presentation/receivables_tab.dart`

- [ ] **Step 4: analyze + suíte inteira dos dois lados**

Run: `cd front && flutter analyze && flutter test && cd ../back && npm run lint --workspace back && npm run test --workspace back`
Expected: front 0 issues, All tests passed; back 0 warnings, todos passando.

- [ ] **Step 5: Conciliação final contra a API (a mesma do fiado)**

Run (backend em 4400, token do `dono@teste.com`): para cada devedor de `GET /receivables?pageSize=100`, abra `GET /receivables/<id>` ou `GET /receivables/sem-cliente?nome=<apelido>` e some `totalDue`; compare com `totalDue` da carteira.
Expected: **BATE**. É a conferência que provou o bug do vazamento — repeti-la aqui é o que garante que a tela nova não regrediu o isolamento.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(receivables): a aba Fiado sai do Caixa — 'A receber' e o unico caminho

Dois caminhos para a mesma carteira divergem com o tempo (foi assim que o
agrupamento da aba ficou diferente do detalhe e vazou titulo entre devedores).
O botao no Caixa e o item de menu entraram na mesma entrega.

Conciliacao contra a API: soma das abas de cada devedor == totalDue da carteira.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Gaps entre Caixa e A receber a reportar ao dono (não corrigir sem alinhar)

Enquanto implementa, registre (no relatório final, não em código) o que aparecer destas categorias:
- **Receber pelo Caixa vs pela tela**: se `showReceiveTitleDialog` e o "Receber OS" do Caixa calcularem saldo de jeitos diferentes.
- **Parcelamento**: hoje só nasce no recebimento; a tela passa a criá-lo na venda. Se o Caixa mostrar parcela de forma diferente do `_TitleCard`, anote.
- **`truncated`**: se em algum tenant real a varredura estourar, a tela avisa — anote a frequência.
- **Apelido homônimo**: já marcado com "Sem cadastro"; se o Caixa não marcar igual no histórico, anote.

## Self-Review

**Spec coverage**
- Nome/rota/menu/botão/aba sai → Tasks 10, 11 ✓
- Filtros no servidor (`q`, `vencimento`, `origem`, `sort`, `page`) → Task 3 ✓; regra pura → Task 1 ✓
- Vencimento do devedor (parcela senão data; um vencido basta) → Task 1 (tabela + `classificar`) ✓
- Offline recalcula com a mesma regra; tabela única → Tasks 5, 6 ✓; `a_receber` herdado → Task 6 ✓
- UI: topo, chips, telefone, próxima parcela, abrir devedor → Task 8 ✓
- Modal venda a prazo (cliente em destaque, sem recebimento, parcelamento opcional; falha do plano não desfaz) → Task 9 ✓
- Fora de escopo respeitado (sem WhatsApp, sem export, sem parcelar no fluxo do Caixa) ✓
- `truncated`: spec dizia sumir; plano registra desvio consciente e mantém como aviso raro (Task 8 `_AvisoTruncado`) ✓

**Placeholder scan** — Task 3 Step 6, Task 6 Step 1 e Task 9 Step 1 trazem esqueletos de teste com comentários: a instrução explícita é escrever os corpos completos com as fixtures reais dos arquivos **antes do commit**; o executor deve ler as fábricas existentes (`linha()`, `_montarLocal`, fakes) — sem isso o passo não está pronto.

**Type consistency** — `Vencimento`/`VencimentoFiltro` wire `a_vencer` ↔ `aVencer` ✓; `OrdemDevedores` wire `mais_antigo` ↔ `maisAntigo` ✓; chave de parcela `${saleKind}:${saleId}` igual em Task 2/3/6 ✓; `DebtorsPage.total/page/pageSize/overdueTotal/overdueCount` iguais em Task 3 (resposta) e Task 4 (modelo) ✓; `proximasParcelasEmAberto` mesmo nome no abstract, impl e uso ✓.
