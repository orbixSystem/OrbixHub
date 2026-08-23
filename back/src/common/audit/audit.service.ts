import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../database/tenant-context';

export type AuditAction =
  | 'login'
  | 'password_change'
  | 'invite'
  | 'subscription_change'
  | 'role_change'
  | 'member_activate'
  | 'member_deactivate'
  | 'settings_change'
  // Ligar/desligar módulo ou funcionalidade tem rastro próprio, e não
  // `settings_change`: muda o que o tenant PODE fazer, não uma preferência de
  // tela. Quando existir cobrança por funcionalidade, é por aqui que se audita
  // quem ligou o quê e quando.
  | 'module_toggle'
  | 'feature_toggle'
  // Cliente escreveu para o suporte da Orbix.
  | 'support_message'
  // A Orbix entrou no ambiente do cliente (link de suporte gerado/consumido).
  // Fica no audit DO TENANT de propósito: o cliente pode perguntar quem entrou.
  | 'support_session'
  // Ambiente criado pelo sistema de admin, nao pelo cadastro self-service.
  | 'tenant_provision'
  | 'customer_delete'
  | 'subject_delete'
  | 'inventory_item_create'
  | 'inventory_item_update'
  | 'inventory_item_archive'
  | 'inventory_item_unarchive'
  | 'inventory_item_delete'
  | 'os_create'
  | 'os_update'
  | 'os_status_change'
  | 'os_delete'
  | 'os_tracking_link_email'
  | 'os_photo_add'
  | 'os_photo_delete'
  | 'os_template_create'
  | 'os_template_update'
  | 'os_template_delete'
  | 'os_template_apply'
  | 'os_stock_reconcile'
  | 'invoice_issue'
  | 'invoice_authorized'
  | 'invoice_rejected'
  | 'invoice_cancel'
  | 'invoice_webhook'
  | 'invoice_config_update'
  | 'invoice_empresa_register'
  | 'invoice_cert_upload'
  | 'schedule_hours_update'
  | 'schedule_item_assign'
  | 'schedule_item_unassign'
  | 'sale_create'
  | 'sale_cancel'
  // Reatribuição de cliente da venda (o dinheiro dela nunca é editado).
  | 'sale_update'
  | 'os_emit_invoice'
  | 'cashier_session_open'
  | 'cashier_session_close'
  | 'cashier_entry_create'
  | 'cashier_entry_reverse'
  // Edição de campo não-financeiro do lançamento (descrição/categoria).
  | 'cashier_entry_update'
  // Correção de valor: estorno + relançamento numa operação.
  | 'cashier_entry_correct'
  // Modelos de despesa fixa (atalhos de lançamento) — criar/editar/desativar.
  | 'cashier_template_create'
  | 'cashier_template_update'
  | 'sale_emit_invoice'
  // Despesas (contas a pagar). `expense_pay`/`expense_unpay` são as auditadas de
  // verdade: são as que mexem dinheiro e espelham lançamento no caixa — o
  // `cashEntryId` no metadata é o que amarra as duas pontas numa investigação.
  | 'expense_create'
  | 'expense_update'
  | 'expense_pay'
  | 'expense_unpay'
  | 'expense_cancel'
  | 'expense_restore'
  // `expense_purge` é o ÚNICO hard delete do projeto: depois dele não há mais
  // linha para consultar, então esta entrada de auditoria é o que resta como
  // prova de que a conta existiu. Gravada antes do DELETE, com a descrição no
  // metadata justamente por isso.
  | 'expense_purge'
  | 'expense_category_create'
  | 'expense_category_update'
  | 'sync_overwrite'
  | 'plate_lookup'
  | 'installment_pay'
  | 'installment_plan_create'
  // Declaração de fiado: o operador passou o título pelo caixa e recebeu ZERO.
  // É a única prova desse caso (não gera lançamento), então precisa de trilha.
  | 'os_fiado'
  | 'sale_fiado';

@Injectable()
export class AuditService {
  constructor(private readonly tenant: TenantContext) {}

  /** audit_log has RLS — write under the given tenant's context (short tx). */
  async log(
    tenantId: string,
    actorUserId: string | null,
    action: AuditAction,
    target?: string,
    metadata?: Record<string, unknown>,
  ): Promise<void> {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.audit_log.create({
        data: {
          tenant_id: tenantId,
          actor_user_id: actorUserId,
          action,
          target: target ?? null,
          metadata: metadata
            ? (metadata as Prisma.InputJsonValue)
            : undefined,
        },
      });
    });
  }
}
