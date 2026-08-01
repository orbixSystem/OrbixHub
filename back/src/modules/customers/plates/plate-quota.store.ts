import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../common/database/prisma.service';

/**
 * Contador de cota mensal das consultas de placa — tabela GLOBAL
 * `plate_lookup_usage` (a cota é da plataforma no provedor, não do tenant),
 * por isso PrismaService base direto, sem RLS/tenant tx.
 *
 * A reserva é ATÔMICA: um único upsert condicional incrementa só se ainda há
 * saldo, então duas requests concorrentes nunca estouram o limite juntas.
 * Fluxo do service: reserva ANTES da chamada externa; se o provedor não
 * atender (indisponível/timeout), devolve com `refund`.
 */
@Injectable()
export class PlateQuotaStore {
  constructor(private readonly prisma: PrismaService) {}

  /** Período corrente no formato 'YYYY-MM' (UTC — mesma régua do provedor). */
  static currentPeriod(now: Date = new Date()): string {
    return now.toISOString().slice(0, 7);
  }

  /**
   * Tenta consumir 1 consulta do período. Retorna o total usado após o
   * incremento, ou `null` quando o limite já foi atingido (nada consumido).
   */
  async tryConsume(period: string, limit: number): Promise<number | null> {
    const rows = await this.prisma.$queryRaw<Array<{ count: number }>>`
      INSERT INTO plate_lookup_usage (period, count, updated_at)
      VALUES (${period}, 1, now())
      ON CONFLICT (period) DO UPDATE
        SET count = plate_lookup_usage.count + 1, updated_at = now()
        WHERE plate_lookup_usage.count < ${limit}
      RETURNING count`;
    return rows.length > 0 ? rows[0].count : null;
  }

  /** Devolve 1 consulta (chamada externa reservou mas não foi servida). */
  async refund(period: string): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE plate_lookup_usage
        SET count = GREATEST(count - 1, 0), updated_at = now()
      WHERE period = ${period}`;
  }

  /** Total consumido no período (0 quando o mês ainda não teve consulta). */
  async used(period: string): Promise<number> {
    const row = await this.prisma.plate_lookup_usage.findUnique({
      where: { period },
    });
    return row?.count ?? 0;
  }
}
