import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import type { OrderLock } from '../os/order-lock.registry';
import { InvoiceRepository } from './invoice.repository';

/**
 * Impedimento fiscal: OS com nota ativa (rascunho/processando/autorizada) não
 * pode ser reaberta nem excluída.
 *
 * Uma nota autorizada declarou ao fisco os itens e o valor daquela OS. Deixar a
 * OS mudar por baixo dela produziria um documento fiscal que não corresponde a
 * nada — e uma OS excluída deixaria a nota apontando para o vazio. O caminho é
 * cancelar a nota primeiro.
 */
@Injectable()
export class InvoiceOrderLock implements OrderLock {
  readonly key = 'invoice';

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InvoiceRepository,
  ) {}

  async motivo(orderId: string): Promise<string | null> {
    const ativas = await this.tenant.withTenantTx(() =>
      this.repo.countAuthorizedByOrder(orderId),
    );
    return ativas > 0
      ? 'Esta OS tem nota fiscal ativa. Cancele a nota antes de reabrir ou excluir a OS.'
      : null;
  }
}
