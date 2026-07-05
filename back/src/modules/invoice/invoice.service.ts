import {
  ConflictException,
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { AuditService } from '../../common/audit/audit.service';
import { TenantContext } from '../../common/database/tenant-context';
import { CustomersService } from '../customers/customers.service';
import { OsService } from '../os/os.service';
import { SalesService } from '../sales/sales.service';
import {
  CancelInvoiceDto,
  IssueInvoiceDto,
  ListInvoicesQueryDto,
} from './dto/invoice.dto';
import {
  FISCAL_GATEWAY,
  FiscalGateway,
  FiscalIssueLine,
} from './fiscal/fiscal-gateway';
import {
  InvoiceLineData,
  InvoiceRepository,
} from './invoice.repository';

const DEFAULT_PAGE_SIZE = 20;

const toNum = (d: Prisma.Decimal | number | null | undefined): number => {
  if (d == null) return 0;
  return typeof d === 'number' ? d : d.toNumber();
};

const round2 = (n: number): number => Math.round(n * 100) / 100;

/** Deriva o `kind` do evento de timeline a partir do status da emissão. */
function issueEventKind(status: 'processing' | 'authorized' | 'rejected'): string {
  if (status === 'rejected') return 'rejected';
  if (status === 'authorized') return 'authorized';
  return 'sent';
}

/** Mensagem legível do evento de timeline conforme o status da emissão. */
function issueEventMessage(status: 'processing' | 'authorized' | 'rejected', rejectionReason: string | null): string {
  if (status === 'rejected') return rejectionReason ?? 'Nota rejeitada.';
  if (status === 'authorized') return 'Nota autorizada.';
  return 'Nota enviada — aguardando autorização.';
}

/** type do webhook fiscal → status interno da nota. */
const WEBHOOK_STATUS: Record<string, 'authorized' | 'rejected' | 'canceled'> = {
  'invoice.authorized': 'authorized',
  'invoice.rejected': 'rejected',
  'invoice.canceled': 'canceled',
};

/**
 * Emissão de Nota Fiscal a partir da OS (ONLINE-ONLY). "Aponta, não invade": a OS e
 * o cliente são lidos via services públicos (`OsService`/`CustomersService`) e a
 * nota faz SNAPSHOT das linhas (serviço E produto) — dona do próprio registro.
 *
 * A chamada ao gateway fiscal acontece SEMPRE FORA de transação de banco; o status
 * assíncrono chega por webhook idempotente (tenant resolvido via SECURITY DEFINER).
 */
@Injectable()
export class InvoiceService {
  private readonly logger = new Logger(InvoiceService.name);

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InvoiceRepository,
    private readonly os: OsService,
    private readonly sales: SalesService,
    private readonly customers: CustomersService,
    private readonly audit: AuditService,
    @Inject(FISCAL_GATEWAY) private readonly gateway: FiscalGateway,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async issue(user: AuthUser, dto: IssueInvoiceDto) {
    const documentType = dto.documentType ?? 'nfse';

    // 1) Resolve a ORIGEM: OS ou venda (exatamente uma), via service público
    //    ("aponta, não invade"). Bloqueia cancelada / sem itens / com nota ativa.
    if ((dto.orderId == null) === (dto.saleId == null)) {
      throw new BadRequestException('Informe uma OS ou uma venda (apenas uma).');
    }
    const source = await this.resolveSource(dto);

    // 2) Snapshot das linhas (serviço E produto) + totais por natureza.
    const lines: InvoiceLineData[] = source.lines;
    const serviceAmount = round2(
      lines.filter((l) => l.kind === 'service').reduce((s, l) => s + l.total, 0),
    );
    const productAmount = round2(
      lines.filter((l) => l.kind === 'product').reduce((s, l) => s + l.total, 0),
    );
    const totalAmount = round2(serviceAmount + productAmount);

    // 4) Documento do tomador via service público do customers (pode não existir;
    //    venda p/ consumidor final não tem customerId).
    let customerDocument: string | null = null;
    if (source.customerId) {
      try {
        const customer = await this.customers.getCustomer(user, source.customerId);
        customerDocument = (customer as { document?: string | null }).document ?? null;
      } catch {
        customerDocument = null;
      }
    }

    // 5) Cria o rascunho + evento 'created' (transação curta).
    const draft = await this.tenant.withTenantTx(async () => {
      const created = await this.repo.createWithLines(
        {
          tenant_id: user.tenantId,
          document_type: documentType,
          environment: this.env.FISCAL_ENVIRONMENT,
          order_id: source.orderId,
          sale_id: source.saleId,
          order_number: source.number,
          customer_id: source.customerId,
          customer_name: source.customerName,
          customer_document: customerDocument,
          service_amount: serviceAmount,
          product_amount: productAmount,
          total_amount: totalAmount,
          issued_by: user.userId,
        },
        lines,
      );
      await this.repo.createEvent(user.tenantId, created.id, {
        kind: 'created',
        message: 'Nota criada a partir da ' + source.label,
        statusSnapshot: 'draft',
      });
      return created;
    });

    // 6) Chamada ao gateway fiscal — SEMPRE FORA de transação.
    const gatewayLines: FiscalIssueLine[] = lines.map((l) => ({
      kind: l.kind,
      name: l.name,
      quantity: l.quantity,
      unitPrice: l.unit_price,
      total: l.total,
    }));
    let result;
    try {
      result = await this.gateway.issue({
        tenantId: user.tenantId,
        invoiceId: draft.id,
        documentType,
        environment: this.env.FISCAL_ENVIRONMENT,
        customer: { name: source.customerName, document: customerDocument },
        lines: gatewayLines,
        serviceAmount,
        productAmount,
        totalAmount,
      });
    } catch (e) {
      this.logger.error(`Falha na emissão da nota ${draft.id}: ${String(e)}`);
      await this.tenant.withTenantTx(async () => {
        await this.repo.updateInvoice(draft.id, {
          status: 'error',
          rejection_reason: 'Falha ao comunicar com o provedor fiscal.',
        });
        await this.repo.createEvent(user.tenantId, draft.id, {
          kind: 'error',
          message: 'Falha ao comunicar com o provedor fiscal.',
          statusSnapshot: 'error',
        });
      });
      throw new ServiceUnavailableException(
        'Falha ao comunicar com o provedor fiscal. Tente novamente.',
      );
    }

    // 7) Persiste o resultado (transação curta).
    const invoice = await this.tenant.withTenantTx(async () => {
      await this.repo.updateInvoice(draft.id, {
        status: result.status,
        external_id: result.externalId,
        number: result.number,
        series: result.series,
        access_key: result.accessKey,
        pdf_url: result.pdfUrl,
        xml_url: result.xmlUrl,
        rejection_reason: result.rejectionReason,
        authorized_at: result.status === 'authorized' ? new Date() : null,
      });
      await this.repo.createEvent(user.tenantId, draft.id, {
        kind: issueEventKind(result.status),
        message: issueEventMessage(result.status, result.rejectionReason),
        statusSnapshot: result.status,
      });
      return this.repo.findByIdWithLines(draft.id);
    });

    await this.audit.log(user.tenantId, user.userId, 'invoice_issue', draft.id, {
      orderId: source.orderId,
      saleId: source.saleId,
      documentType,
      status: result.status,
    });
    return invoice;
  }

  /** Origem normalizada da nota (OS ou venda), com guardrails. Lê via service
   * público — nunca toca a tabela alheia. */
  private async resolveSource(dto: IssueInvoiceDto): Promise<{
    orderId: string | null;
    saleId: string | null;
    number: string;
    customerId: string | null;
    customerName: string;
    label: string;
    lines: InvoiceLineData[];
  }> {
    const toLine = (it: {
      kind: string;
      name: string;
      quantity: Prisma.Decimal | number;
      unit_price: Prisma.Decimal | number;
      total: Prisma.Decimal | number;
    }): InvoiceLineData => ({
      kind: it.kind === 'product' ? 'product' : 'service',
      name: it.name,
      quantity: toNum(it.quantity),
      unit_price: toNum(it.unit_price),
      total: toNum(it.total),
    });

    if (dto.orderId) {
      const { order, items } = await this.os.getOrderWithItems(dto.orderId);
      if (order.status === 'cancelada') {
        throw new BadRequestException('Não é possível emitir nota de uma OS cancelada.');
      }
      if (items.length === 0) {
        throw new BadRequestException('A OS não tem itens para faturar.');
      }
      const active = await this.tenant.withTenantTx(() =>
        this.repo.countAuthorizedByOrder(dto.orderId!),
      );
      if (active > 0) {
        throw new ConflictException('Esta OS já possui uma nota emitida ou em emissão.');
      }
      return {
        orderId: order.id,
        saleId: null,
        number: order.number,
        customerId: order.customer_id,
        customerName: order.customer_name,
        label: 'OS ' + order.number,
        lines: items.map(toLine),
      };
    }

    // Venda
    const sale = await this.sales.getOne(dto.saleId!);
    if (sale.status === 'cancelada') {
      throw new BadRequestException('Não é possível emitir nota de uma venda cancelada.');
    }
    if (sale.items.length === 0) {
      throw new BadRequestException('A venda não tem itens para faturar.');
    }
    const active = await this.tenant.withTenantTx(() =>
      this.repo.countAuthorizedBySale(dto.saleId!),
    );
    if (active > 0) {
      throw new ConflictException('Esta venda já possui uma nota emitida ou em emissão.');
    }
    return {
      orderId: null,
      saleId: sale.id,
      number: sale.number,
      customerId: sale.customer_id,
      customerName: sale.customer_name ?? 'Consumidor final',
      label: 'venda ' + sale.number,
      lines: sale.items.map(toLine),
    };
  }

  async list(query: ListInvoicesQueryDto) {
    const page = query.page && query.page > 0 ? query.page : 1;
    const [items, total] = await this.tenant.withTenantTx(() =>
      this.repo.listInvoices({
        status: query.status,
        orderId: query.orderId,
        saleId: query.saleId,
        skip: (page - 1) * DEFAULT_PAGE_SIZE,
        take: DEFAULT_PAGE_SIZE,
      }),
    );
    return { items, total, page, pageSize: DEFAULT_PAGE_SIZE };
  }

  async getOne(id: string) {
    const invoice = await this.tenant.withTenantTx(async () => {
      const inv = await this.repo.findByIdWithLines(id);
      if (!inv) return null;
      const events = await this.repo.listEvents(id);
      return { ...inv, events };
    });
    if (!invoice) throw new BadRequestException('Nota não encontrada.');
    return invoice;
  }

  async cancel(user: AuthUser, id: string, dto: CancelInvoiceDto) {
    const invoice = await this.tenant.withTenantTx(() => this.repo.findById(id));
    if (!invoice) throw new BadRequestException('Nota não encontrada.');
    if (invoice.status !== 'authorized') {
      throw new ForbiddenException('Só é possível cancelar uma nota autorizada.');
    }

    const result = await this.gateway.cancel({
      tenantId: user.tenantId,
      invoiceId: id,
      externalId: invoice.external_id ?? '',
      reason: dto.reason,
    });

    const updated = await this.tenant.withTenantTx(async () => {
      await this.repo.updateInvoice(id, {
        status: result.status === 'canceled' ? 'canceled' : 'authorized',
        canceled_at: result.status === 'canceled' ? new Date() : null,
        rejection_reason: result.rejectionReason,
      });
      await this.repo.createEvent(user.tenantId, id, {
        kind: result.status === 'canceled' ? 'canceled' : 'rejected',
        message:
          result.status === 'canceled'
            ? `Nota cancelada: ${dto.reason}`
            : result.rejectionReason ?? 'Cancelamento rejeitado.',
        statusSnapshot: result.status === 'canceled' ? 'canceled' : 'authorized',
      });
      return this.repo.findByIdWithLines(id);
    });

    await this.audit.log(user.tenantId, user.userId, 'invoice_cancel', id, {
      reason: dto.reason,
      status: result.status,
    });
    return updated;
  }

  /**
   * Webhook do provedor fiscal (SEM JWT). Verifica assinatura → dedupe →
   * resolve tenant/nota por external_id (SECURITY DEFINER) → atualiza sob o
   * contexto daquele tenant → audita → marca processado. NUNCA confia em tenant
   * vindo do payload.
   */
  async processWebhook(rawBody: Buffer | string, signature: string | undefined): Promise<void> {
    if (!this.gateway.verifySignature(rawBody, signature)) {
      throw new BadRequestException('Assinatura de webhook inválida.');
    }
    const payload = JSON.parse(rawBody.toString()) as {
      id: string;
      type: string;
      data?: {
        externalId?: string;
        number?: string;
        series?: string;
        accessKey?: string;
        pdfUrl?: string;
        xmlUrl?: string;
        rejectionReason?: string;
      };
    };

    let eventRow: { id: string };
    try {
      eventRow = await this.repo.insertWebhookEvent(
        payload.id,
        payload.type,
        payload as unknown as Prisma.InputJsonValue,
      );
    } catch (e) {
      if ((e as { code?: string }).code !== 'P2002') throw e;
      const existing = await this.repo.findWebhookEventByExternalId(payload.id);
      if (!existing || existing.processed_at) return;
      eventRow = { id: existing.id };
    }

    const status = WEBHOOK_STATUS[payload.type];
    const externalId = payload.data?.externalId;
    if (status && externalId) {
      const resolved = await this.repo.resolveByExternalId(externalId);
      if (resolved) {
        await this.tenant.runWithTenant(resolved.tenantId, async () => {
          await this.repo.updateInvoice(resolved.invoiceId, {
            status,
            number: payload.data?.number ?? undefined,
            series: payload.data?.series ?? undefined,
            access_key: payload.data?.accessKey ?? undefined,
            pdf_url: payload.data?.pdfUrl ?? undefined,
            xml_url: payload.data?.xmlUrl ?? undefined,
            rejection_reason: payload.data?.rejectionReason ?? null,
            authorized_at: status === 'authorized' ? new Date() : undefined,
            canceled_at: status === 'canceled' ? new Date() : undefined,
          });
          await this.repo.createEvent(resolved.tenantId, resolved.invoiceId, {
            kind: status,
            message: `Atualização do provedor fiscal: ${payload.type}`,
            statusSnapshot: status,
          });
        });
        await this.audit.log(resolved.tenantId, null, 'invoice_webhook', resolved.invoiceId, {
          type: payload.type,
          externalId,
        });
      }
    }
    await this.repo.markWebhookProcessed(eventRow.id);
  }
}
