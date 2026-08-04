import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import type { SubjectHistoryEntry } from '../customers/subject-history.provider';
import { SaleRepository } from './sale.repository';

/**
 * Vendas de balcão no histórico do cliente.
 *
 * "O que esse cliente já comprou aqui" não é só ordem de serviço: quem vende uma
 * palheta no balcão para um cliente cadastrado gerou histórico igual. Antes a
 * timeline mostrava apenas OS, e a venda avulsa ficava invisível na ficha dele.
 *
 * Venda NÃO tem subject (não é "do carro", é do cliente), então
 * [listBySubject] devolve vazio de propósito: filtrar a timeline por veículo tem
 * de esconder as vendas, senão elas apareceriam repetidas em todos os carros.
 */
@Injectable()
export class SaleSubjectHistoryProvider {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: SaleRepository,
  ) {}

  /** Venda não pertence a um veículo — nada a devolver aqui. */
  async listBySubject(): Promise<SubjectHistoryEntry[]> {
    return [];
  }

  async listByCustomer(customerId: string): Promise<SubjectHistoryEntry[]> {
    const sales = await this.tenant.withTenantTx(() =>
      this.repo.listSalesByCustomer(customerId),
    );
    return sales.map((s) => ({
      id: s.id,
      kind: 'sale',
      title: `Venda ${s.number}`,
      status: s.status,
      occurredAt: s.created_at.toISOString(),
    }));
  }
}
