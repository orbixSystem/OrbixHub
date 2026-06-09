# Autocomplete de marca/modelo no cadastro de veículo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No cadastro de veículo (subject), ao digitar a marca aparecem marcas reais (FIPE) e, escolhida a marca, o campo modelo oferece os modelos daquela marca — como sugestão não-obrigatória; ano segue manual.

**Architecture:** Mecanismo **genérico** — um campo de `subjectFields` pode declarar uma `fonte` de autocomplete e uma dependência (`dependeDe`). O backend expõe `GET /customers/lookups/:fonte`, que delega a um `SubjectLookupService` com cache Redis. A FIPE é **um provider isolado** (`FipeClient`, casca de carro) atrás de uma interface trocável. O Flutter renderiza campos com `fonte` como `Autocomplete` (texto livre + sugestões via repository). O valor salvo continua texto em `attributes` — FIPE só assiste a digitação.

**Tech Stack:** Backend NestJS (TypeScript, ioredis, `fetch` global do Node 24, Jest + supertest e2e). Frontend Flutter (Riverpod 3, dio, freezed, `Autocomplete`).

**Spec:** `docs/superpowers/specs/2026-06-08-autocomplete-marca-modelo-veiculo-design.md`

---

## File Structure

**Backend (`back/`):**
- Create `src/modules/customers/fipe.client.ts` — interface `FipeClient` + token `FIPE_CLIENT` + impl HTTP (`HttpFipeClient`) que fala com a FIPE pública (Parallelum v2). Casca de carro, isolada.
- Create `src/modules/customers/subject-lookup.service.ts` — registry genérico de fontes + cache Redis + degradação graciosa. Define `LookupOption`.
- Create `src/modules/customers/subject-lookup.service.spec.ts` — unit (fake FipeClient + fake Redis).
- Modify `src/modules/customers/customers.config.ts` — `SubjectFieldConfig` ganha `fonte?`/`dependeDe?`; defaults da oficina marcam `marca`/`modelo`.
- Modify `src/modules/customers/dto/config.dto.ts` — `SubjectFieldDto` aceita `fonte?`/`dependeDe?` (round-trip no PATCH).
- Modify `src/modules/customers/customers.controller.ts` — rota `GET lookups/:fonte`.
- Modify `src/modules/customers/customers.module.ts` — providers `SubjectLookupService` + `FIPE_CLIENT`.
- Modify `test/customers.e2e-spec.ts` — bloco e2e do endpoint (auth, módulo, shape, cache) com `FIPE_CLIENT` fake.

**Frontend (`front/`):**
- Modify `lib/features/customers/domain/customers_models.dart` — `SubjectFieldConfig` ganha `fonte`/`dependeDe`; novo `LookupOption`.
- Modify `lib/features/customers/domain/customers_repository.dart` — método `lookup(...)`.
- Modify `lib/features/customers/data/customers_repository_impl.dart` — impl dio.
- Modify `lib/features/customers/data/fake_customers_repository.dart` — impl fake.
- Modify `lib/features/customers/presentation/subject_form_dialog.dart` — campo com `fonte` vira `Autocomplete` + cascata.
- Modify `test/customers_test.dart` — widget test do autocomplete/cascata.

> `di.dart` **não muda**: `customersRepositoryProvider` já injeta `CustomersRepositoryImpl(dio)`; o novo método entra na mesma classe.

---

## Task 1: `FipeClient` — adaptador HTTP isolado (casca de carro)

**Files:**
- Create: `back/src/modules/customers/fipe.client.ts`

> Boundary fino sobre a FIPE pública. Sem teste unitário (faria I/O de rede real); a lógica é exercida via `SubjectLookupService` com um fake. Parallelum v2: `GET /cars/brands` → `[{code,name}]`; `GET /cars/brands/{brandCode}/models` → `[{code,name}]`.

- [ ] **Step 1: Criar o arquivo**

```ts
// back/src/modules/customers/fipe.client.ts

/** Token de DI para a interface (permite trocar provider/fake em teste). */
export const FIPE_CLIENT = Symbol('FIPE_CLIENT');

/** Base pública da FIPE (Parallelum v2). Não é segredo; const por ora. */
export const FIPE_BASE_URL = 'https://fipe.parallelum.com.br/api/v2';

export interface FipeBrand {
  code: string;
  name: string;
}
export interface FipeModel {
  code: string;
  name: string;
}

/** Provider de dados de veículo (casca de carro). Trocável por outra fonte. */
export interface FipeClient {
  brands(): Promise<FipeBrand[]>;
  models(brandCode: string): Promise<FipeModel[]>;
}

/** Impl real via `fetch` (Node 24). Lança em status != 2xx — o caller degrada. */
export class HttpFipeClient implements FipeClient {
  constructor(private readonly baseUrl: string = FIPE_BASE_URL) {}

  async brands(): Promise<FipeBrand[]> {
    const res = await fetch(`${this.baseUrl}/cars/brands`);
    if (!res.ok) throw new Error(`FIPE brands HTTP ${res.status}`);
    return (await res.json()) as FipeBrand[];
  }

  async models(brandCode: string): Promise<FipeModel[]> {
    const res = await fetch(
      `${this.baseUrl}/cars/brands/${encodeURIComponent(brandCode)}/models`,
    );
    if (!res.ok) throw new Error(`FIPE models HTTP ${res.status}`);
    return (await res.json()) as FipeModel[];
  }
}
```

- [ ] **Step 2: Compilar**

Run: `npm run back:lint`
Expected: 0 warnings (arquivo ainda não importado em lugar nenhum — ok).

- [ ] **Step 3: Commit**

```bash
git add back/src/modules/customers/fipe.client.ts
git commit -m "feat(customers): FipeClient — adaptador isolado da FIPE pública"
```

---

## Task 2: `SubjectLookupService` — registry genérico + cache + degradação

**Files:**
- Create: `back/src/modules/customers/subject-lookup.service.ts`
- Test: `back/src/modules/customers/subject-lookup.service.spec.ts`

- [ ] **Step 1: Escrever o teste que falha**

```ts
// back/src/modules/customers/subject-lookup.service.spec.ts
import { NotFoundException } from '@nestjs/common';
import { SubjectLookupService } from './subject-lookup.service';
import type { FipeClient, FipeBrand, FipeModel } from './fipe.client';

class FakeFipe implements FipeClient {
  public brandCalls = 0;
  constructor(
    private readonly _brands: FipeBrand[] = [
      { code: '22', name: 'Ford' },
      { code: '23', name: 'Fiat' },
    ],
    private readonly _models: FipeModel[] = [
      { code: '1', name: 'Ka' },
      { code: '2', name: 'Fiesta' },
    ],
  ) {}
  async brands() {
    this.brandCalls++;
    return this._brands;
  }
  async models(_brandCode: string) {
    return this._models;
  }
}

/** Redis mínimo em memória (get/set com EX ignorado). */
function fakeRedis() {
  const store = new Map<string, string>();
  return {
    store,
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => {
      store.set(k, v);
      return 'OK';
    },
  } as any;
}

describe('SubjectLookupService', () => {
  it('rejects an unknown source', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    await expect(svc.lookup('fipe.cor', {})).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('maps marcas with the FIPE code in meta', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.marcas', {});
    expect(out).toContainEqual({
      value: 'Ford',
      label: 'Ford',
      meta: { codigo: '22' },
    });
  });

  it('filters by q (case-insensitive contains)', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.marcas', { q: 'fia' });
    expect(out.map((o) => o.value)).toEqual(['Fiat']);
  });

  it('returns [] for modelos without a marca code', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    expect(await svc.lookup('fipe.modelos', {})).toEqual([]);
  });

  it('serves the second call from cache (no second FIPE hit)', async () => {
    const fipe = new FakeFipe();
    const svc = new SubjectLookupService(fakeRedis(), fipe);
    await svc.lookup('fipe.marcas', {});
    await svc.lookup('fipe.marcas', { q: 'for' });
    expect(fipe.brandCalls).toBe(1);
  });

  it('degrades to [] when the FIPE client throws', async () => {
    const broken: FipeClient = {
      brands: async () => {
        throw new Error('boom');
      },
      models: async () => {
        throw new Error('boom');
      },
    };
    const svc = new SubjectLookupService(fakeRedis(), broken);
    expect(await svc.lookup('fipe.marcas', {})).toEqual([]);
  });
});
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `npm run back:test -- subject-lookup`
Expected: FAIL — `Cannot find module './subject-lookup.service'`.

- [ ] **Step 3: Implementar o service**

```ts
// back/src/modules/customers/subject-lookup.service.ts
import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../common/redis/redis.module';
import { FIPE_CLIENT, type FipeClient } from './fipe.client';

/** Opção devolvida ao front: `value` (texto salvo), `label` (exibido), `meta`. */
export interface LookupOption {
  value: string;
  label: string;
  meta?: Record<string, unknown>;
}

/**
 * Fontes de autocomplete para campos de subject. Mecanismo GENÉRICO: o módulo
 * só conhece chaves de fonte; a FIPE (casca de carro) entra via FipeClient.
 * Cache em Redis (24h); chamada externa NUNCA dentro de transação de banco;
 * degradação graciosa (FIPE fora → []), o campo segue como texto livre.
 */
@Injectable()
export class SubjectLookupService {
  private static readonly TTL_SECONDS = 60 * 60 * 24;
  private static readonly SOURCES = new Set(['fipe.marcas', 'fipe.modelos']);
  private static readonly LIMIT = 50;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(FIPE_CLIENT) private readonly fipe: FipeClient,
  ) {}

  async lookup(
    fonte: string,
    params: { marca?: string; q?: string },
  ): Promise<LookupOption[]> {
    if (!SubjectLookupService.SOURCES.has(fonte)) {
      throw new NotFoundException('Fonte de autocomplete desconhecida.');
    }
    const all = await this.load(fonte, params.marca);
    return this.filter(all, params.q);
  }

  private async load(
    fonte: string,
    marca: string | undefined,
  ): Promise<LookupOption[]> {
    // modelos dependem do código da marca; sem ele, nada a sugerir.
    if (fonte === 'fipe.modelos' && !marca) return [];

    const key = `lookup:${fonte}:${marca ?? '-'}`;
    const cached = await this.readCache(key);
    if (cached) return cached;

    let options: LookupOption[];
    try {
      options =
        fonte === 'fipe.marcas'
          ? (await this.fipe.brands()).map((b) => ({
              value: b.name,
              label: b.name,
              meta: { codigo: b.code },
            }))
          : (await this.fipe.models(marca as string)).map((m) => ({
              value: m.name,
              label: m.name,
            }));
    } catch {
      return []; // degradação graciosa: nunca trava o cadastro
    }

    await this.writeCache(key, options);
    return options;
  }

  private filter(options: LookupOption[], q: string | undefined): LookupOption[] {
    if (!q?.trim()) return options.slice(0, SubjectLookupService.LIMIT);
    const term = q.trim().toLowerCase();
    return options
      .filter((o) => o.label.toLowerCase().includes(term))
      .slice(0, SubjectLookupService.LIMIT);
  }

  private async readCache(key: string): Promise<LookupOption[] | null> {
    try {
      const raw = await this.redis.get(key);
      return raw ? (JSON.parse(raw) as LookupOption[]) : null;
    } catch {
      return null; // cache é best-effort
    }
  }

  private async writeCache(key: string, value: LookupOption[]): Promise<void> {
    try {
      await this.redis.set(
        key,
        JSON.stringify(value),
        'EX',
        SubjectLookupService.TTL_SECONDS,
      );
    } catch {
      /* best-effort */
    }
  }
}
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `npm run back:test -- subject-lookup`
Expected: PASS (6 testes verdes).

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/customers/subject-lookup.service.ts back/src/modules/customers/subject-lookup.service.spec.ts
git commit -m "feat(customers): SubjectLookupService — fontes genéricas + cache + degradação"
```

---

## Task 3: Config — `fonte`/`dependeDe` no campo (back) + defaults da oficina

**Files:**
- Modify: `back/src/modules/customers/customers.config.ts`
- Modify: `back/src/modules/customers/dto/config.dto.ts`

> Sem migration: `subjectFields` mora em `tenant_module.settings` (jsonb). Só evoluímos o tipo + os defaults + o DTO de PATCH.

- [ ] **Step 1: Estender `SubjectFieldConfig` e os defaults**

Em `back/src/modules/customers/customers.config.ts`, troque a interface `SubjectFieldConfig`:

```ts
export interface SubjectFieldConfig {
  chave: string;
  rotulo: string;
  tipo: SubjectFieldType;
  obrigatorio: boolean;
  /** Fonte de autocomplete (ex.: 'fipe.marcas'). Ausente = campo manual. */
  fonte?: string;
  /** Chave do campo do qual este depende na cascata (ex.: modelo→'marca'). */
  dependeDe?: string;
}
```

E no `DEFAULT_CUSTOMERS_CONFIG`, troque as linhas de `marca` e `modelo`:

```ts
    { chave: 'marca', rotulo: 'Marca', tipo: 'text', obrigatorio: false, fonte: 'fipe.marcas' },
    { chave: 'modelo', rotulo: 'Modelo', tipo: 'text', obrigatorio: false, fonte: 'fipe.modelos', dependeDe: 'marca' },
```

(As demais linhas — `identifier`, `ano`, `cor`, `km` — ficam iguais.)

- [ ] **Step 2: Aceitar `fonte`/`dependeDe` no DTO de PATCH**

Em `back/src/modules/customers/dto/config.dto.ts`, dentro de `SubjectFieldDto`, adicione após `obrigatorio`:

```ts
  @IsOptional() @IsString() @MaxLength(40) fonte?: string;
  @IsOptional() @IsString() @MaxLength(40) dependeDe?: string;
```

- [ ] **Step 3: Rodar os testes de config e ver passar**

Run: `npm run back:test -- customers.config`
Expected: PASS — `mergeCustomersConfig` segue verde (compara contra o próprio `DEFAULT_CUSTOMERS_CONFIG`, agora com `fonte` nas linhas marca/modelo).

- [ ] **Step 4: Commit**

```bash
git add back/src/modules/customers/customers.config.ts back/src/modules/customers/dto/config.dto.ts
git commit -m "feat(customers): campo de subject ganha fonte/dependeDe; defaults oficina usam FIPE"
```

---

## Task 4: Endpoint `GET /customers/lookups/:fonte` + wiring + e2e

**Files:**
- Modify: `back/src/modules/customers/customers.module.ts`
- Modify: `back/src/modules/customers/customers.controller.ts`
- Test: `back/test/customers.e2e-spec.ts`

- [ ] **Step 1: Registrar providers no módulo**

Em `back/src/modules/customers/customers.module.ts`:

Adicione os imports no topo (após os imports existentes do módulo):

```ts
import { SubjectLookupService } from './subject-lookup.service';
import { FIPE_CLIENT, HttpFipeClient } from './fipe.client';
```

E no array `providers` (após `CustomersRepository`):

```ts
    SubjectLookupService,
    { provide: FIPE_CLIENT, useFactory: () => new HttpFipeClient() },
```

- [ ] **Step 2: Adicionar a rota no controller**

Em `back/src/modules/customers/customers.controller.ts`:

Importe o service e ajuste o construtor:

```ts
import { SubjectLookupService } from './subject-lookup.service';
```

```ts
  constructor(
    private readonly customers: CustomersService,
    private readonly lookup: SubjectLookupService,
  ) {}
```

E adicione a rota logo após o bloco de `config` (rotas literais antes de `:id`):

```ts
  // --- autocomplete de campos de subject (marca/modelo via FIPE) ---
  @Get('lookups/:fonte')
  @Permissions('subject.read')
  lookups(
    @Param('fonte') fonte: string,
    @Query('marca') marca?: string,
    @Query('q') q?: string,
  ) {
    return this.lookup.lookup(fonte, { marca, q });
  }
```

- [ ] **Step 3: Escrever o teste e2e que falha**

Em `back/test/customers.e2e-spec.ts`, adicione no topo (junto aos imports):

```ts
import { FIPE_CLIENT } from '../src/modules/customers/fipe.client';
import type { FipeClient } from '../src/modules/customers/fipe.client';
```

Crie um fake de FIPE com contador (perto do `CapturingMailer`):

```ts
class CountingFipe implements FipeClient {
  public brandCalls = 0;
  async brands() {
    this.brandCalls++;
    return [
      { code: '22', name: 'Ford' },
      { code: '23', name: 'Fiat' },
    ];
  }
  async models(_brandCode: string) {
    return [
      { code: '1', name: 'Ka' },
      { code: '2', name: 'Fiesta' },
    ];
  }
}
```

Declare a instância no escopo do `describe` e sobrescreva o provider no `beforeAll`. Localize o `Test.createTestingModule({ imports: [AppModule] }).overrideProvider(MailerService).useValue(mailer)` e encadeie:

```ts
    const fipe = new CountingFipe();
    // guarde numa var de escopo externo se precisar inspecionar brandCalls:
    fipeRef = fipe;
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(mailer)
      .overrideProvider(FIPE_CLIENT)
      .useValue(fipe)
      .compile();
```

Declare `let fipeRef: CountingFipe;` junto às outras declarações (`let app`, `let redis`…).

Adicione um bloco de testes (dentro do `describe` principal, após os blocos existentes). Reaproveite o helper de login de owner já presente no arquivo — se ele se chamar diferente de `registerOwner`, use o nome real e pegue `owner.access`:

```ts
  describe('GET /customers/lookups/:fonte', () => {
    it('401 sem token', async () => {
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas')
        .expect(401);
    });

    it('marcas: retorna opções com código no meta e cacheia', async () => {
      const owner = await registerOwner(); // helper existente no arquivo
      const before = fipeRef.brandCalls;

      const r1 = await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas')
        .set('Authorization', `Bearer ${owner.access}`)
        .expect(200);
      expect(r1.body).toContainEqual({
        value: 'Ford',
        label: 'Ford',
        meta: { codigo: '22' },
      });

      // segunda chamada vem do cache: sem novo hit na FIPE
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas?q=fia')
        .set('Authorization', `Bearer ${owner.access}`)
        .expect(200);
      expect(fipeRef.brandCalls).toBe(before + 1);
    });

    it('fonte desconhecida → 404', async () => {
      const owner = await registerOwner();
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.cor')
        .set('Authorization', `Bearer ${owner.access}`)
        .expect(404);
    });
  });
```

> Se o arquivo não tiver um helper `registerOwner`, copie o padrão de criação de owner usado nos blocos existentes (registro → verify via `mailer.lastTokenFor` → login) para obter `access`. Não invente endpoints — espelhe o que o teste já faz.

- [ ] **Step 4: Rodar o e2e e ver passar**

Run (FLUSHALL no redis antes, conforme README §6): `npm run back:test:e2e -- customers`
Expected: PASS — incluindo o novo bloco `GET /customers/lookups/:fonte` (3 testes).

- [ ] **Step 5: Lint**

Run: `npm run back:lint`
Expected: 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add back/src/modules/customers/customers.module.ts back/src/modules/customers/customers.controller.ts back/test/customers.e2e-spec.ts
git commit -m "feat(customers): endpoint GET /customers/lookups/:fonte (autocomplete) + e2e"
```

---

## Task 5: Front — modelos `SubjectFieldConfig.fonte/dependeDe` + `LookupOption`

**Files:**
- Modify: `front/lib/features/customers/domain/customers_models.dart`
- Regen: `customers_models.freezed.dart` / `customers_models.g.dart`

- [ ] **Step 1: Estender `SubjectFieldConfig` e adicionar `LookupOption`**

Em `front/lib/features/customers/domain/customers_models.dart`, troque a classe `SubjectFieldConfig`:

```dart
/// Definição de um campo do formulário de subject (vem da config).
@freezed
abstract class SubjectFieldConfig with _$SubjectFieldConfig {
  const factory SubjectFieldConfig({
    required String chave,
    required String rotulo,
    @Default('text') String tipo, // 'text' | 'number'
    @Default(false) bool obrigatorio,
    String? fonte, // ex.: 'fipe.marcas' — null = campo manual
    String? dependeDe, // chave do campo do qual depende (cascata)
  }) = _SubjectFieldConfig;

  factory SubjectFieldConfig.fromJson(Map<String, dynamic> json) =>
      _$SubjectFieldConfigFromJson(json);
}
```

E adicione, ao fim do arquivo (após `SubjectDraft`), o modelo de opção:

```dart
/// Opção de autocomplete vinda de `GET /customers/lookups/:fonte`.
/// `value` é o texto salvo; `meta['codigo']` (quando houver) alimenta a cascata.
@freezed
abstract class LookupOption with _$LookupOption {
  const factory LookupOption({
    required String value,
    required String label,
    @Default(<String, dynamic>{}) Map<String, dynamic> meta,
  }) = _LookupOption;

  factory LookupOption.fromJson(Map<String, dynamic> json) =>
      _$LookupOptionFromJson(json);
}
```

- [ ] **Step 2: Regerar o código freezed/json**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\dart.bat run build_runner build --delete-conflicting-outputs`
Expected: "Succeeded" — `customers_models.freezed.dart`/`.g.dart` atualizados com `LookupOption` e os novos campos.

- [ ] **Step 3: Analisar**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/customers/domain/customers_models.dart front/lib/features/customers/domain/customers_models.freezed.dart front/lib/features/customers/domain/customers_models.g.dart
git commit -m "feat(front/customers): SubjectFieldConfig.fonte/dependeDe + LookupOption"
```

---

## Task 6: Front — método `lookup` no repository (interface + dio + fake)

**Files:**
- Modify: `front/lib/features/customers/domain/customers_repository.dart`
- Modify: `front/lib/features/customers/data/customers_repository_impl.dart`
- Modify: `front/lib/features/customers/data/fake_customers_repository.dart`

- [ ] **Step 1: Declarar na interface**

Em `front/lib/features/customers/domain/customers_repository.dart`, antes do fechamento da interface (após `subjectHistory`), adicione:

```dart

  // ---- autocomplete (marca/modelo via FIPE, no backend) ----
  /// Opções para um campo com `fonte`. `marca` = código da marca selecionada
  /// (cascata); `q` = texto digitado. Lista vazia se a fonte não tiver dados.
  Future<List<LookupOption>> lookup(String fonte, {String? marca, String? q});
```

- [ ] **Step 2: Implementar no dio**

Em `front/lib/features/customers/data/customers_repository_impl.dart`, antes do fechamento da classe (após `subjectHistory`), adicione:

```dart

  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? q,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers/lookups/$fonte',
          queryParameters: {
            if (marca != null && marca.isNotEmpty) 'marca': marca,
            if (q != null && q.isNotEmpty) 'q': q,
          },
        );
        return _asList(res.data).map(LookupOption.fromJson).toList();
      });
```

- [ ] **Step 3: Implementar no fake**

Em `front/lib/features/customers/data/fake_customers_repository.dart`, antes do fechamento da classe (após `subjectHistory`), adicione:

```dart

  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? q,
  }) async {
    final all = switch (fonte) {
      'fipe.marcas' => const [
          LookupOption(value: 'Ford', label: 'Ford', meta: {'codigo': '22'}),
          LookupOption(value: 'Fiat', label: 'Fiat', meta: {'codigo': '23'}),
        ],
      'fipe.modelos' => marca == null
          ? const <LookupOption>[]
          : const [
              LookupOption(value: 'Ka', label: 'Ka'),
              LookupOption(value: 'Fiesta', label: 'Fiesta'),
            ],
      _ => const <LookupOption>[],
    };
    final term = q?.trim().toLowerCase();
    if (term == null || term.isEmpty) return all;
    return all.where((o) => o.label.toLowerCase().contains(term)).toList();
  }
```

- [ ] **Step 4: Analisar**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze`
Expected: "No issues found!" (as três impls satisfazem a interface).

- [ ] **Step 5: Commit**

```bash
git add front/lib/features/customers/domain/customers_repository.dart front/lib/features/customers/data/customers_repository_impl.dart front/lib/features/customers/data/fake_customers_repository.dart
git commit -m "feat(front/customers): repository.lookup (dio + fake)"
```

---

## Task 7: Front — campo `Autocomplete` no `SubjectFormDialog` + cascata

**Files:**
- Modify: `front/lib/features/customers/presentation/subject_form_dialog.dart`
- Test: `front/test/customers_test.dart`

> Campo com `fonte` vira `Autocomplete` (texto livre + sugestões). A marca selecionada guarda `meta['codigo']` em memória; trocar a marca limpa os campos dependentes. O valor salvo continua sendo o texto do controller (lógica de `_save` inalterada).

- [ ] **Step 1: Escrever o widget test que falha**

Em `front/test/customers_test.dart`, adicione (no fim, dentro do grupo de testes ou em um novo `group`):

```dart
  testWidgets('campo com fonte sugere marcas e a cascata limpa o modelo',
      (tester) async {
    final fake = FakeCustomersRepository();
    const config = CustomersConfig(
      subjectFields: [
        SubjectFieldConfig(
          chave: 'marca',
          rotulo: 'Marca',
          fonte: 'fipe.marcas',
        ),
        SubjectFieldConfig(
          chave: 'modelo',
          rotulo: 'Modelo',
          fonte: 'fipe.modelos',
          dependeDe: 'marca',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SubjectFormDialog(customerId: 'cus-1', config: config),
          ),
        ),
      ),
    );

    // digitar na Marca dispara o lookup e mostra as opções
    await tester.enterText(find.byKey(const Key('subjectField-marca')), 'f');
    await tester.pumpAndSettle();
    expect(find.text('Ford'), findsWidgets);

    // escolher Ford
    await tester.tap(find.text('Ford').last);
    await tester.pumpAndSettle();

    // agora Modelo sugere modelos da marca
    await tester.enterText(find.byKey(const Key('subjectField-modelo')), 'k');
    await tester.pumpAndSettle();
    expect(find.text('Ka'), findsWidgets);
  });
```

> Confirme os imports no topo de `customers_test.dart`: `flutter_riverpod`, `flutter_test`, `customers_models.dart`, `fake_customers_repository.dart`, `subject_form_dialog.dart`, e `di.dart` (para `customersRepositoryProvider`). Adicione os que faltarem.

- [ ] **Step 2: Rodar e ver falhar**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/customers_test.dart`
Expected: FAIL — não há campo com `Key('subjectField-marca')` nem autocomplete (hoje é `TextFormField` puro sem key).

- [ ] **Step 3: Implementar o campo de autocomplete + cascata**

Em `front/lib/features/customers/presentation/subject_form_dialog.dart`:

3a. Adicione, no estado `_SubjectFormDialogState`, um mapa de códigos selecionados (após `_fields`):

```dart
  /// Código FIPE da opção selecionada por campo (alimenta a cascata).
  final Map<String, String?> _selectedCode = {};
```

3b. No `build`, troque o loop que monta os campos. Substitua todo o bloco
`for (final f in widget.config.subjectFields) ...[ ... ]` por:

```dart
                for (final f in widget.config.subjectFields) ...[
                  const SizedBox(height: 12),
                  if (f.fonte != null)
                    _LookupField(
                      field: f,
                      controller: _fields[f.chave]!,
                      marcaCodigo: f.dependeDe == null
                          ? null
                          : _selectedCode[f.dependeDe],
                      onSelected: (opt) {
                        // setState p/ os campos dependentes rebuildarem com o
                        // novo código (a cascata lê _selectedCode no build).
                        setState(() {
                          _selectedCode[f.chave] =
                              opt.meta['codigo'] as String?;
                          // troca de marca limpa os campos dependentes
                          for (final dep in widget.config.subjectFields) {
                            if (dep.dependeDe == f.chave) {
                              _fields[dep.chave]!.clear();
                              _selectedCode[dep.chave] = null;
                            }
                          }
                        });
                      },
                    )
                  else
                    TextFormField(
                      controller: _fields[f.chave],
                      decoration: InputDecoration(
                        labelText: '${f.rotulo}${f.obrigatorio ? ' *' : ''}',
                      ),
                      keyboardType: f.tipo == 'number'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      inputFormatters: f.tipo == 'number'
                          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                          : null,
                      validator: (v) {
                        if (f.obrigatorio && (v == null || v.trim().isEmpty)) {
                          return '${f.rotulo} é obrigatório';
                        }
                        return null;
                      },
                    ),
                ],
```

3c. Adicione, ao fim do arquivo (após a classe de estado), o widget de campo:

```dart
/// Campo de texto com sugestões não-obrigatórias vindas do repository
/// (`lookup`). Permite digitar valores fora da lista; ao escolher uma opção,
/// notifica o pai (para guardar o código e disparar a cascata).
class _LookupField extends ConsumerWidget {
  const _LookupField({
    required this.field,
    required this.controller,
    required this.marcaCodigo,
    required this.onSelected,
  });

  final SubjectFieldConfig field;
  final TextEditingController controller;
  final String? marcaCodigo;
  final ValueChanged<LookupOption> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<LookupOption>(
      // mantém o que já foi digitado ao reconstruir
      initialValue: TextEditingValue(text: controller.text),
      displayStringForOption: (o) => o.value,
      optionsBuilder: (value) async {
        if (value.text.isEmpty) return const Iterable<LookupOption>.empty();
        final repo = ref.read(customersRepositoryProvider);
        return repo.lookup(
          field.fonte!,
          marca: marcaCodigo,
          q: value.text,
        );
      },
      onSelected: (opt) {
        controller.text = opt.value;
        onSelected(opt);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        // espelha a digitação livre no controller do formulário
        textController.addListener(() => controller.text = textController.text);
        return TextFormField(
          key: Key('subjectField-${field.chave}'),
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '${field.rotulo}${field.obrigatorio ? ' *' : ''}',
          ),
          validator: (v) {
            if (field.obrigatorio && (v == null || v.trim().isEmpty)) {
              return '${field.rotulo} é obrigatório';
            }
            return null;
          },
        );
      },
    );
  }
}
```

3d. Garanta os imports no topo do arquivo: já há `flutter_riverpod`. O `_LookupField` usa `ref` → ok (ConsumerWidget). Mantenha o import de `app_exception.dart`, `di.dart`, `customers_models.dart` (já presentes).

> Nota de implementação: o `_save()` atual já lê `_fields[f.chave].text` para todos os campos não-`identifier` e joga em `attributes`. Como o `_LookupField` espelha a digitação no mesmo controller, **`_save` não muda** — o texto (selecionado ou livre) é persistido como hoje.

- [ ] **Step 4: Rodar o teste e ver passar**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/customers_test.dart`
Expected: PASS — sugestões de marca aparecem, seleção de Ford habilita modelos.

- [ ] **Step 5: Analisar + suite completa**

Run (do diretório `front`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze` (Expected: "No issues found!") e depois `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test` (Expected: todos verdes).

- [ ] **Step 6: Commit**

```bash
git add front/lib/features/customers/presentation/subject_form_dialog.dart front/test/customers_test.dart
git commit -m "feat(front/customers): autocomplete marca→modelo no cadastro de subject"
```

---

## Task 8: Documentação

**Files:**
- Modify: `docs/configuracao.md`

- [ ] **Step 1: Documentar o mecanismo de `fonte`**

Em `docs/configuracao.md`, na seção do módulo "Clientes & Veículos" (campos do subject), adicione um parágrafo:

```markdown
### Autocomplete de campos (fonte)

Um campo de `subjectFields` pode declarar uma `fonte` de autocomplete e, opcionalmente,
`dependeDe` (cascata). O backend serve as opções por `GET /customers/lookups/:fonte`
(cache de 24h em Redis, degradação graciosa). Fontes disponíveis:

- `fipe.marcas` — marcas de veículos (Tabela FIPE).
- `fipe.modelos` — modelos da marca selecionada (`dependeDe: 'marca'`).

A sugestão é **não-obrigatória**: o usuário pode digitar valores fora da lista. O valor
salvo é sempre o texto, em `attributes` (nenhum código FIPE é persistido). Verticais sem
veículos simplesmente não declaram esses campos.
```

- [ ] **Step 2: Commit**

```bash
git add docs/configuracao.md
git commit -m "docs(customers): documenta autocomplete de campos (fonte FIPE)"
```

---

## Verificação final (antes de "pronto")

- [ ] `npm run back:lint` → 0 warnings
- [ ] `npm run back:test` → verde (inclui `subject-lookup`, `customers.config`)
- [ ] `npm run back:test:e2e -- customers` → verde (FLUSHALL no redis antes, README §6)
- [ ] `flutter analyze` (em `front/`) → "No issues found!"
- [ ] `flutter test` (em `front/`) → verde

> Cite o output real de cada comando — nunca afirme "passa" sem rodar (regra de ouro: evidência antes de afirmar).
