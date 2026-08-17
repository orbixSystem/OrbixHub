import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { AuditService } from '../../common/audit/audit.service';
import { ENV } from '../../common/config/config.module';
import { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import {
  buildTrackingUrl,
  renderTrackingLinkEmail,
} from '../../common/mailer/mail-templates';
import { MailerService } from '../../common/mailer/mailer.service';
import { CustomersService } from '../customers/customers.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { OsRepository } from './os.repository';
import { SendTrackingLinkDto } from './dto/tracking-link.dto';

/** Lê uma string não-vazia de um mapa solto (company settings vêm como jsonb). */
function str(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

/**
 * Envio do link público de acompanhamento da OS ao cliente.
 *
 * Fica fora do `OsService` de propósito: é um fluxo de saída (e-mail), não parte
 * do ciclo de vida da OS. "Aponta, não invade": o e-mail do cliente vem do
 * `CustomersService` e o nome da oficina do `TenancyService` — nenhuma tabela
 * alheia é lida aqui. O envio acontece SEMPRE fora de transação de banco.
 */
@Injectable()
export class OsTrackingService {
  private readonly logger = new Logger(OsTrackingService.name);

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
    private readonly customers: CustomersService,
    private readonly tenancy: TenancyService,
    private readonly mailer: MailerService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Cabeçalho da OS (sem timeline/fotos — não precisamos deles aqui). */
  private loadOrder(id: string) {
    return this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(id);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      return order;
    });
  }

  /**
   * E-mail cadastrado do cliente da OS — sugestão para o atendente CONFERIR
   * antes de enviar. Cliente sem e-mail (ou inacessível) devolve `null`: o
   * atendente digita o endereço na hora.
   */
  private async customerEmail(
    user: AuthUser,
    customerId: string | null,
  ): Promise<string | null> {
    if (!customerId) return null;
    try {
      const customer = (await this.customers.getCustomer(
        user,
        customerId,
      )) as { email?: string | null };
      return str(customer.email);
    } catch (e) {
      // Cliente removido não pode travar o envio manual — só não sugerimos nada.
      this.logger.warn(
        `E-mail do cliente ${customerId} indisponível: ${(e as Error).message}`,
      );
      return null;
    }
  }

  /** Dados que a tela de confirmação mostra antes de disparar o envio. */
  async getRecipient(user: AuthUser, orderId: string) {
    const order = await this.loadOrder(orderId);
    return {
      customer_name: order.customer_name ?? null,
      email: await this.customerEmail(user, order.customer_id),
    };
  }

  /**
   * Envia o link de acompanhamento para o endereço confirmado pelo atendente.
   * Registra uma nota interna na timeline (a oficina vê que o link saiu) e
   * audita. Não altera o cadastro do cliente.
   */
  async sendLinkByEmail(
    user: AuthUser,
    orderId: string,
    dto: SendTrackingLinkDto,
  ) {
    const order = await this.loadOrder(orderId);
    if (!order.public_token) {
      throw new BadRequestException(
        'Esta OS ainda não tem link de acompanhamento.',
      );
    }
    const to = dto.email.trim().toLowerCase();

    const company = await this.tenancy.getCompanyView(user.tenantId);
    const companyName = str(company.companyName) ?? 'OrbixHub';
    const mail = renderTrackingLinkEmail({
      companyName,
      customerName: order.customer_name,
      orderNumber: order.number,
      url: buildTrackingUrl(order.public_token, this.env.APP_PUBLIC_URL),
    });

    // I/O externo FORA de qualquer transação (regra de ouro).
    try {
      await this.mailer.sendMessage({
        to,
        subject: mail.subject,
        html: mail.html,
        text: mail.text,
        // O cliente responde para a oficina, não para o nosso remetente técnico.
        fromName: companyName,
        replyTo: str(company.email) ?? undefined,
      });
    } catch (e) {
      this.logger.error(
        `Falha ao enviar link da OS ${orderId} para ${to}: ${(e as Error).message}`,
      );
      throw new ServiceUnavailableException(
        'Não foi possível enviar o e-mail agora. Tente novamente em instantes.',
      );
    }

    // Nota interna: o histórico da OS mostra que o link foi enviado e para quem.
    await this.tenant.withTenantTx(() =>
      this.repo.createEvent(user.tenantId, orderId, {
        kind: 'note',
        message: `Link de acompanhamento enviado por e-mail para ${to}.`,
        visiblePublic: false,
        createdBy: user.userId,
      }),
    );
    await this.audit.log(
      user.tenantId,
      user.userId,
      'os_tracking_link_email',
      orderId,
      { to },
    );

    return { sent: true, to };
  }
}
