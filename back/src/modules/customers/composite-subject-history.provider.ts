import { Injectable } from '@nestjs/common';
import {
  SubjectHistoryProvider,
  type SubjectHistoryEntry,
} from './subject-history.provider';

/**
 * Uma fonte de histórico do cliente. Cada módulo que gera fatos sobre o cliente
 * implementa isto (OS, venda de balcão, …) sem que `customers` conheça as tabelas
 * deles — "aponta, não invade".
 */
export interface SubjectHistorySource {
  listBySubject(subjectId: string): Promise<SubjectHistoryEntry[]>;
  listByCustomer(customerId: string): Promise<SubjectHistoryEntry[]>;
}

/**
 * Histórico do cliente = a UNIÃO das fontes, em ordem cronológica.
 *
 * Antes o seam aceitava uma fonte só e estava amarrado à OS, então a venda de
 * balcão não aparecia na ficha do cliente — mesmo sendo a mesma pergunta ("o que
 * essa pessoa já comprou aqui"). Com o compositor, cada módulo novo que gere
 * fatos do cliente entra somando, sem tocar em `customers`.
 *
 * Uma fonte que falha NÃO derruba a timeline: o histórico é leitura, e é melhor
 * mostrar as OS sem as vendas do que uma tela de erro.
 */
@Injectable()
export class CompositeSubjectHistoryProvider extends SubjectHistoryProvider {
  constructor(private readonly sources: SubjectHistorySource[]) {
    super();
  }

  async listBySubject(subjectId: string): Promise<SubjectHistoryEntry[]> {
    return this.merge(
      await Promise.all(
        this.sources.map((s) => this.safe(() => s.listBySubject(subjectId))),
      ),
    );
  }

  async listByCustomer(customerId: string): Promise<SubjectHistoryEntry[]> {
    return this.merge(
      await Promise.all(
        this.sources.map((s) => this.safe(() => s.listByCustomer(customerId))),
      ),
    );
  }

  /** Mais recente primeiro (mesma ordem que cada fonte já usa isoladamente). */
  private merge(listas: SubjectHistoryEntry[][]): SubjectHistoryEntry[] {
    return listas
      .flat()
      .sort((a, b) => b.occurredAt.localeCompare(a.occurredAt));
  }

  private async safe(
    fn: () => Promise<SubjectHistoryEntry[]>,
  ): Promise<SubjectHistoryEntry[]> {
    try {
      return await fn();
    } catch {
      return [];
    }
  }
}
