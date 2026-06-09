import { Injectable } from '@nestjs/common';

/** Uma entrada do histórico (ex.: uma OS). Genérico por design. */
export interface SubjectHistoryEntry {
  id: string;
  kind: string; // ex.: 'os'
  title: string;
  status: string;
  occurredAt: string; // ISO
  /** A qual subject (veículo) pertence — alimenta a timeline do cliente. */
  subjectId?: string;
  subjectLabel?: string;
}

/**
 * Seam de histórico. O módulo `customers` NÃO conhece as tabelas da OS
 * ("aponta, não invade"): quando o módulo de OS existir, ele registra um provider
 * que implementa estes métodos chamando o **service público** da OS
 * (`osService.listBySubject(...)` / `listByCustomer(...)`). Até lá, vazio.
 */
export abstract class SubjectHistoryProvider {
  /** Eventos de UM subject (filtro por carro). */
  abstract listBySubject(subjectId: string): Promise<SubjectHistoryEntry[]>;
  /** Timeline do cliente: eventos de TODOS os subjects dele. */
  abstract listByCustomer(customerId: string): Promise<SubjectHistoryEntry[]>;
}

/** Default enquanto não há módulo de OS: histórico vazio (sem tabela nova). */
@Injectable()
export class EmptySubjectHistoryProvider extends SubjectHistoryProvider {
  async listBySubject(): Promise<SubjectHistoryEntry[]> {
    return [];
  }
  async listByCustomer(): Promise<SubjectHistoryEntry[]> {
    return [];
  }
}
