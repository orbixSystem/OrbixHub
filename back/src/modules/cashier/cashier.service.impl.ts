import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { CashierRepository, CashierSyncEntity } from './cashier.repository';
import {
  clampChangedSinceLimit,
  type ChangedSincePage,
} from '../../common/database/changed-since';
import { SEM_TETO, validarDesconto } from './cashier.discount';
import {
  buildPaymentSummary,
  CashierService,
  PaymentSummary,
} from './cashier.service';
import {
  CASHIER_CONFIG_KEY,
  CASHIER_MODULE_KEY,
  CashierConfig,
  computeDifference,
  computeExpected,
  directionForCategory,
  EntryCategory,
  mergeCashierConfig,
  PaymentMethod,
  round2,
  SaleKind,
} from './cashier.config';
import {
  CorrectEntryDto,
  CreateEntryDto,
  ReverseEntryDto,
  UpdateEntryDto,
} from './dto/entry.dto';
import { CreateInstallmentPlanDto, PayInstallmentDto } from './dto/installment.dto';
import {
  CreateExpenseTemplateDto,
  UpdateExpenseTemplateDto,
} from './dto/expense-template.dto';
import { CloseSessionDto, OpenSessionDto } from './dto/session.dto';
import { EntryQueryDto, SummaryQueryDto } from './dto/query.dto';
import { UpdateCashierConfigDto } from './dto/config.dto';
import {
  isIdUniqueViolation,
  isUniqueViolation,
} from '../../common/database/prisma-errors';

const DEFAULT_PAGE_SIZE = 20;

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

const parseDate = (v: string | undefined): Date | undefined =>
  v ? new Date(v) : undefined;

/** Totais de uma sessão por método/direção (informativo no fechamento/atual). */
export interface MethodTotals {
  method: string;
  in: number;
  out: number;
}

/**
 * Implementação REAL do Caixa. Estende o contrato congelado `CashierService`
 * (os 2 métodos que a OS/vendas consomem) e adiciona a operação do módulo
 * (sessões, lançamentos, extrato, resumo, config). Tudo tenant-scoped por RLS:
 * endpoints do controller usam `withTenantTx` (tenant do CLS/JWT); os métodos do
 * contrato usam `runWithTenant` (tenant explícito vindo do chamador, p. ex. a OS).
 */
@Injectable()
export class CashierServiceImpl extends CashierService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: CashierRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
  ) {
    super();
  }

  // ============== Contrato público (consumido pela OS/vendas) ==============
  async getPaymentSummary(
    tenantId: string,
    vendaId: string,
    fallbackTotal = 0,
  ): Promise<PaymentSummary> {
    const { recebido, desconto } = await this.tenant.runWithTenant(
      tenantId,
      () => this.repo.sumSettledForSale(vendaId),
    );
    return buildPaymentSummary(fallbackTotal, recebido, desconto);
  }

  async getPaymentSummaryBatch(
    tenantId: string,
    vendas: Array<{ id: string; total: number }>,
  ): Promise<Map<string, PaymentSummary>> {
    const map = new Map<string, PaymentSummary>();
    if (!vendas.length) return map;
    const porVenda = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.sumSettledForSales(vendas.map((v) => v.id)),
    );
    for (const v of vendas) {
      const s = porVenda.get(v.id);
      map.set(v.id, buildPaymentSummary(v.total, s?.recebido ?? 0, s?.desconto ?? 0));
    }
    return map;
  }

  private static readonly SYNC_ENTITIES = new Set<CashierSyncEntity>([
    'cash_session',
    'cash_entry',
    // Modelos de despesa fixa: sem eles no pull, os atalhos ficariam invisíveis
    // offline — e é justo offline que o operador mais precisa lançar rápido.
    'cash_expense_template',
    // Parcelamento de fiado: criar o plano e quitar parcela precisam funcionar
    // no balcão sem rede — é ali que o cliente está combinando o prazo.
    'receivable_installment',
  ]);

  /**
   * Página de mudanças de `cash_session`/`cash_entry` para o pull de sync
   * offline ("aponta, não invade": o módulo `sync` só chama este service
   * público via o token `CashierService`). Mesma shape JSON dos endpoints de
   * leitura (linhas cruas do Prisma — `listSessions`/`listEntries` também
   * devolvem a linha crua).
   */
  async listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    if (!CashierServiceImpl.SYNC_ENTITIES.has(entity as CashierSyncEntity)) {
      throw new BadRequestException(
        `Entidade não pertence ao módulo cashier: ${entity}`,
      );
    }
    const clamped = clampChangedSinceLimit(limit);
    return this.tenant.withTenantTx(() =>
      this.repo.listChangedSince(entity as CashierSyncEntity, cursor, clamped),
    );
  }

  // ============ Despesas fixas (modelos de lançamento) ============
  /**
   * Modelos disponíveis para o atalho. `includeDisabled` só para a tela de
   * gerenciamento — os atalhos do lançamento mostram apenas os ativos.
   */
  listExpenseTemplates(includeDisabled = false) {
    return this.tenant.withTenantTx(() =>
      this.repo.listTemplates({ includeDisabled }),
    );
  }

  async createExpenseTemplate(user: AuthUser, dto: CreateExpenseTemplateDto) {
    const name = dto.name.trim();
    try {
      const created = await this.tenant.withTenantTx(() =>
        this.repo.createTemplate(user.tenantId, {
          ...(dto.id ? { id: dto.id } : {}),
          name,
          // 0 = "o valor varia": o atalho preenche só o nome.
          amount: dto.amount ?? 0,
          category: dto.category ?? 'despesa',
          method: dto.method ?? null,
          created_by: user.userId,
        }),
      );
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_template_create',
        created.id,
      );
      return created;
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      // Dois uniques possíveis: a PK (replay offline reenviando o mesmo id) e o
      // nome entre os ativos. Sob RLS o meta.target vem null, então confirmamos
      // por leitura — tratar um pelo outro daria a mensagem errada ao operador.
      if (dto.id) {
        const idTaken =
          isIdUniqueViolation(e) ||
          (await this.tenant.withTenantTx(() =>
            this.repo.findTemplate(dto.id as string),
          )) != null;
        if (idTaken) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
      }
      throw new ConflictException(`Já existe uma despesa fixa "${name}".`);
    }
  }

  async updateExpenseTemplate(
    user: AuthUser,
    id: string,
    dto: UpdateExpenseTemplateDto,
  ) {
    const current = await this.tenant.withTenantTx(() =>
      this.repo.findTemplate(id),
    );
    if (!current) throw new NotFoundException('Despesa fixa não encontrada.');
    const name = dto.name?.trim();
    try {
      const updated = await this.tenant.withTenantTx(() =>
        this.repo.updateTemplate(id, {
          ...(name ? { name } : {}),
          ...(dto.amount != null ? { amount: dto.amount } : {}),
          ...(dto.category ? { category: dto.category } : {}),
          // `method` distingue ausente (não mexe) de null explícito (limpar).
          ...(dto.method !== undefined ? { method: dto.method } : {}),
          ...(dto.status ? { status: dto.status } : {}),
        }),
      );
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_template_update',
        id,
      );
      return updated;
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      throw new ConflictException(
        `Já existe uma despesa fixa "${name ?? current.name}".`,
      );
    }
  }

  /** Desativar = sem hard delete (regra 6). O que já foi lançado não muda. */
  disableExpenseTemplate(user: AuthUser, id: string) {
    return this.updateExpenseTemplate(user, id, { status: 'disabled' });
  }

  // ===================== Config =====================
  async getConfig(tenantId: string): Promise<CashierConfig> {
    const settings = await this.billing.getModuleSettings(
      tenantId,
      CASHIER_MODULE_KEY,
    );
    return mergeCashierConfig(
      settings[CASHIER_CONFIG_KEY] as Partial<CashierConfig> | undefined,
    );
  }

  async updateConfig(
    user: AuthUser,
    dto: UpdateCashierConfigDto,
  ): Promise<CashierConfig> {
    const settings = await this.billing.getModuleSettings(
      user.tenantId,
      CASHIER_MODULE_KEY,
    );
    const current = settings[CASHIER_CONFIG_KEY] as
      | Partial<CashierConfig>
      | undefined;
    const merged = mergeCashierConfig(current, dto as Partial<CashierConfig>);
    await this.billing.setModuleSettings(user.tenantId, CASHIER_MODULE_KEY, {
      ...settings,
      [CASHIER_CONFIG_KEY]: merged,
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'settings_change',
      'cashier.config',
    );
    return merged;
  }

  // ===================== Sessões =====================
  async openSession(user: AuthUser, dto: OpenSessionDto) {
    try {
      const session = await this.tenant.withTenantTx(async () => {
        const open = await this.repo.findOpenSession(dto.deviceId);
        if (open)
          throw new ConflictException(
            'Já existe um caixa aberto neste ponto de caixa.',
          );
        return this.repo.createSession(user.tenantId, {
          id: dto.id,
          opened_by: user.userId,
          opening_amount: dto.openingAmount ?? 0,
          notes: dto.notes?.trim() || null,
          device_id: dto.deviceId ?? null,
        });
      });
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_session_open',
        session.id,
      );
      return session;
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      // PK duplicada (replay offline com id) ≠ "caixa já aberto" (corrida do
      // índice parcial uq_cash_session_open_device). Sob RLS o meta.target vem
      // null — quando o detalhe não aponta a PK, confirmamos com uma leitura
      // por id em nova tx (id existe no tenant ⇒ conflito de id).
      if (dto.id) {
        const idTaken =
          isIdUniqueViolation(e) ||
          (await this.tenant.withTenantTx(() =>
            this.repo.findSessionById(dto.id as string),
          )) != null;
        if (idTaken) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
      }
      // Índice parcial único protege contra corrida (2 aberturas simultâneas no mesmo ponto).
      throw new ConflictException(
        'Já existe um caixa aberto neste ponto de caixa.',
      );
    }
  }

  async closeSession(user: AuthUser, dto: CloseSessionDto) {
    const config = await this.getConfig(user.tenantId);
    const { session, expected, difference, byMethod } =
      await this.tenant.withTenantTx(async () => {
        const open = await this.repo.findOpenSession(dto.deviceId);
        if (!open)
          throw new BadRequestException(
            'Não há caixa aberto neste ponto de caixa.',
          );
        const rows = await this.repo.sessionTotalsByMethod(open.id);
        const byMethod = shapeMethodTotals(rows);
        const cash = pickCash(byMethod);
        const all = pickAll(byMethod);
        const opening = toNum(open.opening_amount);
        // countCashOnly ⇒ só dinheiro entra na conta do esperado.
        const expected = config.countCashOnly
          ? computeExpected({
              opening,
              totalIn: cash.in,
              totalOut: cash.out,
            })
          : computeExpected({ opening, totalIn: all.in, totalOut: all.out });
        const counted = round2(dto.countedAmount);
        const difference = computeDifference(counted, expected);
        const session = await this.repo.closeSession(open.id, {
          closed_by: user.userId,
          closing_amount_counted: counted,
          closing_amount_expected: expected,
          difference,
          notes: dto.notes?.trim() || null,
        });
        return { session, expected, difference, byMethod };
      });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_session_close',
      session.id,
      { expected, difference },
    );
    return { ...session, byMethod };
  }

  /** Sessão aberta atual + totais correntes (para a tela do caixa do dia). */
  async getCurrentSession(user: AuthUser, deviceId?: string) {
    return this.tenant.withTenantTx(async () => {
      const open = await this.repo.findOpenSession(deviceId);
      if (!open) return null;
      const rows = await this.repo.sessionTotalsByMethod(open.id);
      const byMethod = shapeMethodTotals(rows);
      const all = pickAll(byMethod);
      const cash = pickCash(byMethod);
      const config = mergeCashierConfig(
        (await this.billing.getModuleSettings(user.tenantId, CASHIER_MODULE_KEY))[
          CASHIER_CONFIG_KEY
        ] as Partial<CashierConfig> | undefined,
      );
      const expected = config.countCashOnly
        ? computeExpected({
            opening: toNum(open.opening_amount),
            totalIn: cash.in,
            totalOut: cash.out,
          })
        : computeExpected({
            opening: toNum(open.opening_amount),
            totalIn: all.in,
            totalOut: all.out,
          });
      return {
        ...open,
        byMethod,
        totals: { in: all.in, out: all.out, expected },
      };
    });
  }

  async listSessions(
    _user: AuthUser,
    page = 1,
    pageSize = DEFAULT_PAGE_SIZE,
    filtros: { deviceId?: string | null; status?: 'open' | 'closed' } = {},
  ) {
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listSessions({
        skip: (page - 1) * pageSize,
        take: pageSize,
        deviceId: filtros.deviceId,
        status: filtros.status,
      }),
    );
    return { items, total, page, pageSize };
  }

  // ===================== Lançamentos =====================
  /**
   * Valida o desconto pedido e devolve o valor aprovado. Lança 403 com o motivo
   * quando a alçada não cobre — a UI esconde o campo de quem não pode, mas
   * esconder não é proteger: o backend é a verdade.
   */
  private async aprovarDesconto(
    user: AuthUser,
    entrada: { desconto: number; saldo: number; amount: number },
  ): Promise<number> {
    if (!entrada.desconto) return 0;
    const r = validarDesconto({
      ...entrada,
      podeConceder: await this.hasPermission(user.role, 'cashier.discount'),
      // Sem teto configurável — decisão do dono: a régua por valor/percentual
      // não fazia sentido no uso real. A contenção é a PERMISSÃO (só owner e
      // gerente concedem) mais a trava de "não se perdoa mais do que se deve",
      // que continua valendo e é a que impede dinheiro fantasma.
      teto: SEM_TETO,
    });
    if (!r.ok) throw new ForbiddenException(r.motivo);
    return r.desconto;
  }

  async createEntry(user: AuthUser, dto: CreateEntryDto) {
    const category = dto.category as EntryCategory;
    // Despesa/sangria/suprimento (ajustes da gaveta) são privilégio de gestão.
    // Recebimento (os_payment/venda_avulsa) o atendente faz com `cashier.write`.
    if (
      (category === 'despesa' ||
        category === 'sangria' ||
        category === 'suprimento') &&
      !(await this.hasPermission(user.role, 'cashier.manage'))
    ) {
      throw new ForbiddenException(
        'Apenas dono/gerente podem lançar despesa, sangria ou suprimento.',
      );
    }
    const direction = directionForCategory(category);
    const { saleKind, saleId } = this.resolveSale(category, dto);
    const config = await this.getConfig(user.tenantId);

    // Desconto precisa de um documento a que se aplicar: sem dívida apontada não
    // há saldo a perdoar (decisão registrada na spec).
    //
    // O SALDO, porém, o caixa não sabe sozinho — o total do documento pertence
    // ao módulo dono (OS/venda), e ler a tabela alheia é proibido. Por isso o
    // chamador informa `saleTotal`, mesmo padrão de `getPaymentSummary(...,
    // fallbackTotal)`, que já existe justamente por essa fronteira.
    //
    // `saleTotal` serve à trava de "não se perdoa mais do que se deve": sem o
    // total, o caixa não sabe o saldo (ele pertence ao módulo dono) e a trava
    // fica limitada ao que a própria operação declara.
    let desconto = 0;
    if (dto.discount) {
      if (!saleId) {
        throw new BadRequestException(
          'Desconto só se aplica a lançamento que quita uma venda ou OS.',
        );
      }
      const somas = await this.tenant.runWithTenant(user.tenantId, () =>
        this.repo.sumSettledForSale(saleId),
      );
      const jaQuitado = round2(somas.recebido + somas.desconto);
      const total = dto.saleTotal ? round2(dto.saleTotal) : null;
      const saldo =
        total !== null
          ? Math.max(0, round2(total - jaQuitado))
          : round2(dto.amount + dto.discount);
      desconto = await this.aprovarDesconto(user, {
        desconto: dto.discount,
        saldo,
        amount: dto.amount,
      });
    }

    const entry = await this.tenant.withTenantTx(async () => {
      let open = await this.repo.findOpenSession(dto.deviceId);
      if (!open) {
        if (config.requireOpenSession)
          throw new BadRequestException(
            'Não há caixa aberto neste ponto de caixa.',
          );
        // requireOpenSession=false ⇒ abre uma sessão implícita (valor inicial 0) no mesmo ponto.
        open = await this.repo.createSession(user.tenantId, {
          opened_by: user.userId,
          opening_amount: 0,
          notes: null,
          device_id: dto.deviceId ?? null,
        });
      }
      try {
        return await this.repo.createEntry(user.tenantId, {
          id: dto.id,
          cash_session_id: open.id,
          direction,
          amount: round2(dto.amount),
          method: dto.method as PaymentMethod,
          category,
          sale_kind: saleKind,
          sale_id: saleId,
          description: dto.description?.trim() || null,
          discount: desconto,
          discount_reason: desconto
            ? dto.discountReason?.trim() || null
            : null,
          created_by: user.userId,
        });
      } catch (e) {
        // `cash_entry` não tem unique além da PK: P2002 com id do cliente
        // presente SÓ pode ser o id duplicado (replay repetido).
        if (dto.id && isUniqueViolation(e)) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
        throw e;
      }
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_create',
      entry.id,
      { category, direction, amount: toNum(entry.amount), saleKind, saleId },
    );
    // Trilha SEPARADA para o desconto. Um desconto some dentro de um evento
    // genérico de lançamento — e é exatamente o que alguém vai querer auditar
    // depois ("quem perdoou esses R$ 300?"). Só é gravado quando existe, para
    // não poluir o log com ruído de valor zero.
    if (desconto > 0) {
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_discount_grant',
        entry.id,
        {
          discount: desconto,
          reason: dto.discountReason?.trim() || null,
          saleKind,
          saleId,
          amount: toNum(entry.amount),
        },
      );
    }
    return entry;
  }

  /**
   * Edita o que o lançamento DIZ (descrição, categoria de mesma direção). Nunca
   * o quanto ele vale: valor/forma passam por [correctEntry], que estorna e
   * relança — um livro caixa não sobrescreve movimento, registra a correção.
   */
  async updateEntry(user: AuthUser, id: string, dto: UpdateEntryDto) {
    const entry = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findEntryById(id);
      if (!existing) throw new NotFoundException('Lançamento não encontrado.');
      // Estornado é registro histórico fechado: editá-lo reescreveria o passado.
      if (existing.reversed_at)
        throw new ConflictException(
          'Lançamento estornado não pode ser editado.',
        );

      const category = dto.category as EntryCategory | undefined;
      if (category && category !== existing.category) {
        // Mudar a direção altera o saldo do caixa — isso é correção, não edição.
        if (
          directionForCategory(category) !==
          directionForCategory(existing.category as EntryCategory)
        ) {
          throw new BadRequestException(
            'Esta troca de categoria inverte entrada/saída. Use a correção do '
              + 'lançamento (estorna e relança).',
          );
        }
      }
      return this.repo.updateEntry(id, {
        ...(dto.description !== undefined
          ? { description: dto.description.trim() || null }
          : {}),
        ...(category ? { category } : {}),
      });
    });
    await this.audit.log(user.tenantId, user.userId, 'cashier_entry_update', id, {
      description: dto.description?.trim(),
      category: dto.category,
    });
    return entry;
  }

  /**
   * Corrige um lançamento errado: estorna o original (com motivo) e cria o novo
   * com os valores certos. É o "editar" do dinheiro — e é uma operação só para o
   * usuário, mesmo sendo duas linhas no livro.
   *
   * Campos ausentes herdam do original (corrigir só o valor é o caso comum). O
   * lançamento novo entra na sessão ABERTA de hoje, não na do original: dinheiro
   * corrigido hoje pertence ao caixa de hoje — senão a conferência de um dia já
   * fechado mudaria retroativamente.
   */
  async correctEntry(user: AuthUser, id: string, dto: CorrectEntryDto) {
    const original = await this.tenant.withTenantTx(() =>
      this.repo.findEntryById(id),
    );
    if (!original) throw new NotFoundException('Lançamento não encontrado.');
    if (original.reversed_at)
      throw new ConflictException('Lançamento já estornado.');

    // Estorna primeiro: se a criação falhar, o original fica estornado e o
    // usuário lança de novo — melhor que duplicar dinheiro no caixa.
    await this.reverseEntry(user, id, { reason: dto.reason });

    const novo = await this.createEntry(user, {
      id: dto.newId,
      amount: dto.amount ?? toNum(original.amount),
      method: (dto.method ?? original.method) as PaymentMethod,
      category: (dto.category ?? original.category) as EntryCategory,
      saleKind: (original.sale_kind ?? undefined) as 'os' | 'sale' | undefined,
      saleId: original.sale_id ?? undefined,
      description:
        dto.description ?? (original.description ?? undefined),
      // Corrigir um recebimento tem de poder corrigir o DESCONTO junto: quem
      // errou o valor pode ter errado o abatimento. Omitir o campo HERDA o
      // desconto original — corrigir só a forma de pagamento não deveria
      // apagar em silêncio o desconto que já havia sido concedido.
      discount: dto.discount ?? toNum(original.discount),
      discountReason:
        dto.discountReason ?? (original.discount_reason ?? undefined),
      deviceId: undefined,
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_correct',
      novo.id,
      {
        corrigiu: id,
        motivo: dto.reason,
        de: toNum(original.amount),
        para: toNum(novo.amount),
        descontoDe: toNum(original.discount),
        descontoPara: toNum(novo.discount),
      },
    );
    return novo;
  }

  /**
   * Valida e resolve o vínculo com a venda. `os_payment` exige (saleKind='os',
   * saleId). Saídas (despesa/sangria) e suprimento nunca apontam venda. `venda_avulsa`
   * é forward-compatible: aceita um vínculo, mas hoje (sem módulo `sale`) fica solto.
   */
  private resolveSale(
    category: EntryCategory,
    dto: CreateEntryDto,
  ): { saleKind: SaleKind | null; saleId: string | null } {
    if (category === 'os_payment') {
      if (dto.saleKind !== 'os' || !dto.saleId)
        throw new BadRequestException(
          'Recebimento de OS exige saleKind="os" e saleId.',
        );
      return { saleKind: 'os', saleId: dto.saleId };
    }
    if (category === 'venda_avulsa') {
      // Aceita vínculo opcional; sem módulo `sale` ainda, normalmente vem solto.
      if (dto.saleId) return { saleKind: (dto.saleKind ?? 'sale') as SaleKind, saleId: dto.saleId };
      return { saleKind: null, saleId: null };
    }
    // despesa / sangria / suprimento: nunca apontam venda.
    return { saleKind: null, saleId: null };
  }

  async reverseEntry(user: AuthUser, id: string, dto: ReverseEntryDto) {
    const entry = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findEntryById(id);
      if (!existing) throw new NotFoundException('Lançamento não encontrado.');
      if (existing.reversed_at)
        throw new ConflictException('Lançamento já estornado.');
      return this.repo.markReversed(id, {
        reversed_by: user.userId,
        reversal_reason: dto.reason.trim(),
      });
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_reverse',
      id,
      { reason: dto.reason.trim() },
    );
    return entry;
  }

  // ============ Porta do módulo `expenses` (contas a pagar) ============
  /**
   * Saída no livro caixa referente a uma despesa paga. Ver o contrato em
   * `CashierService.registrarSaidaDeDespesa` para o "por que" desta porta.
   *
   * Repare no que NÃO está aqui: a checagem de `cashier.manage`. Ela existe no
   * `createEntry` porque lá o lançamento é digitado por quem opera a gaveta;
   * aqui ele é consequência de uma baixa que o módulo de despesas já autorizou
   * com `finance.write`. Duplicar a exigência impediria o dono de pagar a conta
   * de luz por não ter papel de caixa.
   */
  async registrarSaidaDeDespesa(
    user: AuthUser,
    input: {
      amount: number;
      method: string;
      description: string;
      deviceId?: string | null;
      entryId?: string;
      originId?: string;
    },
  ): Promise<{ id: string }> {
    const config = await this.getConfig(user.tenantId);
    const method = input.method as PaymentMethod;
    if (!config.paymentMethods.includes(method)) {
      throw new BadRequestException('Forma de pagamento não aceita pelo caixa.');
    }

    const entry = await this.tenant.withTenantTx(async () => {
      let open = await this.repo.findOpenSession(input.deviceId ?? undefined);
      if (!open) {
        // Sem sessão e com exigência ligada: recusa em vez de gravar torto. Quem
        // chamou NÃO deve persistir a baixa — senão o fechamento deixa de bater
        // e não há como descobrir por quê.
        if (config.requireOpenSession) {
          throw new BadRequestException(
            'Não há caixa aberto. Abra o caixa para registrar o pagamento.',
          );
        }
        open = await this.repo.createSession(user.tenantId, {
          opened_by: user.userId,
          opening_amount: 0,
          notes: null,
          device_id: input.deviceId ?? null,
        });
      }
      try {
        return await this.repo.createEntry(user.tenantId, {
          id: input.entryId,
          cash_session_id: open.id,
          // Direção derivada da categoria, como todo lançamento — despesa é saída.
          direction: directionForCategory('despesa'),
          amount: round2(input.amount),
          method,
          category: 'despesa',
          // Origem = a despesa que gerou a saída. Antes ia NULA, e o vínculo
          // existia só no sentido despesa → lançamento: o extrato mostrava
          // "Aluguel" sem caminho de volta para a conta.
          //
          // Guardar a tag não fere a regra 1 — `sale_kind` já carrega `'os'`, de
          // outro módulo, e o caixa segue sem saber o que uma despesa É. E é o que
          // faz o clique funcionar OFFLINE: o espelho local do lançamento traz
          // `sale_kind`, enquanto buscar por `cash_entry_id` exigiria rede.
          sale_kind: input.originId ? 'expense' : null,
          sale_id: input.originId ?? null,
          description: input.description.trim() || null,
          created_by: user.userId,
        });
      } catch (e) {
        if (input.entryId && isUniqueViolation(e)) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
        throw e;
      }
    });

    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_create',
      entry.id,
      {
        category: 'despesa',
        direction: 'out',
        amount: toNum(entry.amount),
        origem: 'expenses',
      },
    );
    return { id: entry.id };
  }

  /**
   * Estorna o lançamento de uma despesa cujo pagamento foi desfeito.
   *
   * Silencioso quando o lançamento não existe mais ou já foi estornado: desfazer
   * duas vezes (offline + replay do sync) não pode derrubar a operação, e o
   * estado final desejado — lançamento sem efeito no caixa — já é o vigente.
   */
  async estornarSaidaDeDespesa(user: AuthUser, entryId: string): Promise<void> {
    const estornado = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findEntryById(entryId);
      if (!existing || existing.reversed_at) return null;
      return this.repo.markReversed(entryId, {
        reversed_by: user.userId,
        reversal_reason: 'Pagamento da despesa desfeito',
      });
    });
    if (!estornado) return;
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_reverse',
      entryId,
      { reason: 'Pagamento da despesa desfeito', origem: 'expenses' },
    );
  }

  // ===================== Extrato & resumo =====================
  async listEntries(_user: AuthUser, query: EntryQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listEntries({
        sessionId: query.sessionId,
        q: query.q?.trim() || undefined,
        direction: query.direction,
        method: query.method,
        category: query.category,
        saleKind: query.saleKind,
        saleId: query.saleId,
        from: parseDate(query.from),
        to: parseDate(query.to),
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  /** Totais por método/categoria/origem no período — base dos relatórios (recebido). */
  async receivedBySale(range?: { from?: Date; to?: Date }) {
    return this.tenant.withTenantTx(() =>
      this.repo.receivedBySale(range ?? {}),
    );
  }

  async getCashSummary(_user: AuthUser, query: SummaryQueryDto) {
    const p = { from: parseDate(query.from), to: parseDate(query.to) };
    const [methodRows, categoryRows, originRows, descontos] =
      await this.tenant.withTenantTx(() =>
        Promise.all([
          this.repo.summaryByMethod(p),
          this.repo.summaryByCategory(p),
          this.repo.summaryByOrigin(p),
          this.repo.sumDiscounts(p),
        ]),
      );
    const byMethod = shapeMethodTotals(methodRows);
    const all = pickAll(byMethod);
    return {
      byMethod,
      byCategory: shapeKeyedTotals(categoryRows, 'category'),
      byOrigin: shapeKeyedTotals(originRows, 'sale_kind', 'nenhum'),
      totalIn: all.in,
      totalOut: all.out,
      net: round2(all.in - all.out),
      // Desconto NÃO entra em totalIn nem em net: ele fecha dívida sem entrar
      // dinheiro, e somá-lo faria o fechamento acusar caixa inexistente. Vem
      // como número próprio, para o dono responder "quanto abri mão?" — que é
      // a pergunta que só existe depois que o desconto passa a ser registrável.
      totalDiscount: descontos,
    };
  }

  /**
   * Resumo de pagamento para o endpoint HTTP do caixa. `total` é OPCIONAL e vem do
   * dono da venda (a OS sabe seu total) — o caixa não toca a tabela da venda. Sem
   * `total`, reflete só o recebido (total=0). Acompanha as entries da venda.
   */
  async getSalePaymentDetail(
    _user: AuthUser,
    saleId: string,
    total?: number,
  ) {
    const { somas, entries } = await this.tenant.withTenantTx(async () => {
      const [somas, entries] = await Promise.all([
        this.repo.sumSettledForSale(saleId),
        this.repo.listEntriesForSale(saleId),
      ]);
      return { somas, entries };
    });
    return {
      ...buildPaymentSummary(total ?? 0, somas.recebido, somas.desconto),
      entries,
    };
  }

  // ===================== Parcelas de fiado =====================

  /** Lista as parcelas de uma venda/OS ordenadas por vencimento. */
  listInstallments(tenantId: string, saleKind: string, saleId: string) {
    return this.tenant.runWithTenant(tenantId, () => {
      const db = this.tenant.getClient();
      return db.receivable_installment.findMany({
        where: { sale_kind: saleKind, sale_id: saleId },
        orderBy: { due_date: 'asc' },
      });
    });
  }

  /** Parcelas ainda não quitadas (contrato `CashierService`). */
  contarParcelasEmAberto(
    tenantId: string,
    saleKind: string,
    saleId: string,
  ): Promise<number> {
    return this.tenant.runWithTenant(tenantId, () => {
      const db = this.tenant.getClient();
      return db.receivable_installment.count({
        where: { sale_kind: saleKind, sale_id: saleId, paid_at: null },
      });
    });
  }

  /**
   * Cria um plano de parcelas para o saldo remanescente de uma venda/OS.
   * Divide o saldo atual igualmente (ajuste de centavos na última parcela).
   */
  async createInstallmentPlan(user: AuthUser, dto: CreateInstallmentPlanDto) {
    const {
      saleKind,
      saleId,
      installmentCount,
      dueDayOfMonth,
      totalAmount,
      firstDueDate,
      notes,
      installmentIds,
    } = dto;
    // Replay offline: os ids vêm do cliente (um por parcela, na mesma ordem) —
    // sem eles, reenviar o push duplicaria o plano inteiro.
    if (installmentIds && installmentIds.length !== installmentCount) {
      throw new BadRequestException(
        'installmentIds deve ter um id por parcela.',
      );
    }

    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      // Verifica se já existe plano de parcelas pendentes para esta venda.
      const existing = await db.receivable_installment.count({
        where: { sale_kind: saleKind, sale_id: saleId, paid_at: null },
      });
      if (existing > 0) {
        throw new BadRequestException('Já existe um plano de parcelas pendentes para esta venda.');
      }

      // Divide o total igualmente; ajuste de centavos na última parcela.
      const base = round2(totalAmount / installmentCount);
      const last = round2(totalAmount - base * (installmentCount - 1));

      // Calcula as datas de vencimento
      const dates: Date[] = [];
      let current = firstDueDate
        ? new Date(firstDueDate)
        : nextOccurrenceOfDay(dueDayOfMonth);
      for (let i = 0; i < installmentCount; i++) {
        dates.push(new Date(current));
        const next = new Date(current);
        next.setMonth(next.getMonth() + 1);
        next.setDate(Math.min(dueDayOfMonth, daysInMonth(next.getFullYear(), next.getMonth())));
        current = next;
      }

      const data = dates.map((due_date, i) => ({
        ...(installmentIds ? { id: installmentIds[i] } : {}),
        tenant_id: user.tenantId,
        sale_kind: saleKind,
        sale_id: saleId,
        amount: i === installmentCount - 1 ? last : base,
        due_date,
        notes: notes ?? null,
      }));

      return db.receivable_installment.createMany({ data });
    });
  }

  /**
   * Quita uma parcela: cria o cash_entry correspondente e marca `paid_at`.
   */
  async payInstallment(user: AuthUser, installmentId: string, dto: PayInstallmentDto) {
    const config = await this.getConfig(user.tenantId);

    const result = await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const inst = await db.receivable_installment.findFirst({
        where: { id: installmentId, paid_at: null },
      });
      if (!inst) throw new NotFoundException('Parcela não encontrada ou já paga.');

      // Garante sessão (cria sessão implícita se necessário, como createEntry)
      let open = await this.repo.findOpenSession(undefined);
      if (!open) {
        if (config.requireOpenSession) {
          throw new BadRequestException('Não há caixa aberto. Abra o caixa para registrar o pagamento.');
        }
        open = await this.repo.createSession(user.tenantId, {
          opened_by: user.userId,
          opening_amount: 0,
          notes: null,
          device_id: null,
        });
      }

      // Aqui o teto PERCENTUAL vale integralmente: a parcela é do caixa, então
      // o saldo é conhecido de verdade — diferente do lançamento genérico, onde
      // o total do documento vive no módulo dono.
      const valorParcela = round2(toNum(inst.amount));
      const desconto = await this.aprovarDesconto(user, {
        desconto: dto.discount ?? 0,
        saldo: valorParcela,
        amount: Math.max(0, round2(valorParcela - (dto.discount ?? 0))),
      });

      // Cria o cash_entry — `id` do cliente (replay offline) evita duplicar o
      // lançamento se o push reenviar, mesmo idioma de `expense.pay`.
      //
      // O dinheiro que entra é a parcela MENOS o desconto; a parcela fecha
      // porque amount + discount cobre o valor dela.
      const entry = await this.repo.createEntry(user.tenantId, {
        ...(dto.cashEntryId ? { id: dto.cashEntryId } : {}),
        cash_session_id: open.id,
        direction: 'in',
        amount: round2(valorParcela - desconto),
        method: dto.method as PaymentMethod,
        category: (inst.sale_kind === 'os' ? 'os_payment' : 'venda_avulsa') as EntryCategory,
        sale_kind: inst.sale_kind as SaleKind,
        sale_id: inst.sale_id,
        description: dto.description?.trim() || null,
        discount: desconto,
        discount_reason: desconto ? dto.discountReason?.trim() || null : null,
        created_by: user.userId,
      });

      // Marca a parcela como paga
      const paga = await db.receivable_installment.update({
        where: { id: installmentId },
        data: { paid_at: new Date(), entry_id: entry.id, updated_at: new Date() },
      });
      return { paga, desconto };
    });

    await this.audit.log(user.tenantId, user.userId, 'installment_pay', installmentId, {
      method: dto.method,
      discount: result.desconto,
    });
    if (result.desconto > 0) {
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_discount_grant',
        installmentId,
        {
          discount: result.desconto,
          reason: dto.discountReason?.trim() || null,
          origem: 'installment',
        },
      );
    }
    return result.paga;
  }

  /**
   * Cargo tem a permissão? (role/role_permission/permission são globais, sem RLS —
   * mesma consulta do PermissionsGuard). Usado para o gate fino de categorias
   * sensíveis dentro de `createEntry`.
   */
  private async hasPermission(role: string, perm: string): Promise<boolean> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ key: string }>>`
      SELECT p.key FROM role r
      JOIN role_permission rp ON rp.role_id = r.id
      JOIN permission p ON p.id = rp.permission_id
      WHERE r.key = ${role} AND p.key = ${perm}
      LIMIT 1
    `;
    return rows.length > 0;
  }
}

// ===================== Helpers de forma (puros) =====================
type GroupRow = { direction: string; _sum: { amount: Prisma.Decimal | null } };

/** Agrupa linhas (method, direction) → [{ method, in, out }]. */
function shapeMethodTotals(
  rows: Array<GroupRow & { method: string }>,
): MethodTotals[] {
  const map = new Map<string, MethodTotals>();
  for (const r of rows) {
    const cur = map.get(r.method) ?? { method: r.method, in: 0, out: 0 };
    if (r.direction === 'in') cur.in = round2(cur.in + toNum(r._sum.amount));
    else cur.out = round2(cur.out + toNum(r._sum.amount));
    map.set(r.method, cur);
  }
  return [...map.values()];
}

/** Agrupa linhas (<key>, direction) → [{ key, in, out }] genérico. */
function shapeKeyedTotals<K extends string>(
  rows: Array<GroupRow & Record<K, string | null>>,
  key: K,
  nullLabel = 'nenhum',
): Array<{ key: string; in: number; out: number }> {
  const map = new Map<string, { key: string; in: number; out: number }>();
  for (const r of rows) {
    const k = (r[key] as string | null) ?? nullLabel;
    const cur = map.get(k) ?? { key: k, in: 0, out: 0 };
    if (r.direction === 'in') cur.in = round2(cur.in + toNum(r._sum.amount));
    else cur.out = round2(cur.out + toNum(r._sum.amount));
    map.set(k, cur);
  }
  return [...map.values()];
}

const pickCash = (rows: MethodTotals[]): { in: number; out: number } => {
  const cash = rows.find((r) => r.method === 'dinheiro');
  return { in: cash?.in ?? 0, out: cash?.out ?? 0 };
};

// ===================== Helpers de parcelamento =====================

/** Próxima ocorrência de `day` a partir de hoje (inclusive). */
function nextOccurrenceOfDay(day: number): Date {
  const now = new Date();
  const candidate = new Date(now.getFullYear(), now.getMonth(), day);
  if (candidate <= now) {
    const next = new Date(candidate);
    next.setMonth(next.getMonth() + 1);
    next.setDate(Math.min(day, daysInMonth(next.getFullYear(), next.getMonth())));
    return next;
  }
  return candidate;
}

/** Número de dias do mês `month` (0-based) do ano `year`. */
function daysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

const pickAll = (rows: MethodTotals[]): { in: number; out: number } => {
  let i = 0;
  let o = 0;
  for (const r of rows) {
    i += r.in;
    o += r.out;
  }
  return { in: round2(i), out: round2(o) };
};
