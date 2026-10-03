import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../../common/database/tenant-context';
import { Narrativa } from '../../../common/ai/ai-text.gateway';
import { Kpi, Periodo, Sinal } from './monthly-metrics';

export interface ResumoMensal {
  period: string;
  periodo: Periodo;
  kpis: Kpi[];
  sinais: Sinal[];
  narrativa: Narrativa;
  aiModel: string;
  aiStatus: 'ok' | 'fallback';
  generatedAt: string;
}

/**
 * A única tabela do módulo `report`.
 *
 * O resto do módulo compõe tudo on-the-fly; aqui se guarda um FATO datado: o
 * texto escrito uma vez sobre o mês que fechou. Regerar produziria outro texto
 * (o modelo não é determinístico) e o dono veria o "mesmo" relatório mudar
 * sozinho de um dia para o outro.
 */
@Injectable()
export class MonthlySummaryRepository {
  constructor(private readonly tenant: TenantContext) {}

  /**
   * Grava o resumo do mês. `upsert` na chave (tenant, período): rodar o job
   * duas vezes — retry, deploy no meio da madrugada, duas instâncias — atualiza
   * em vez de duplicar.
   */
  async salvar(
    tenantId: string,
    period: Date,
    dados: {
      metrics: Prisma.InputJsonValue;
      signals: Prisma.InputJsonValue;
      narrative: Prisma.InputJsonValue;
      aiModel: string;
      aiStatus: string;
    },
  ): Promise<void> {
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.report_monthly_summary.upsert({
        where: { tenant_id_period: { tenant_id: tenantId, period } },
        create: {
          tenant_id: tenantId,
          period,
          metrics: dados.metrics,
          signals: dados.signals,
          narrative: dados.narrative,
          ai_model: dados.aiModel,
          ai_status: dados.aiStatus,
        },
        update: {
          metrics: dados.metrics,
          signals: dados.signals,
          narrative: dados.narrative,
          ai_model: dados.aiModel,
          ai_status: dados.aiStatus,
          generated_at: new Date(),
        },
      });
    });
  }

  /** O resumo de um mês, ou `null` se aquele mês não foi gerado. */
  async buscar(period: Date): Promise<ResumoMensal | null> {
    const row = await this.tenant.withTenantTx(() =>
      this.tenant.getClient().report_monthly_summary.findFirst({
        where: { period },
      }),
    );
    return row ? mapear(row) : null;
  }

  /** O mais recente — é o que a tela abre quando ninguém escolheu mês. */
  async maisRecente(): Promise<ResumoMensal | null> {
    const row = await this.tenant.withTenantTx(() =>
      this.tenant.getClient().report_monthly_summary.findFirst({
        orderBy: { period: 'desc' },
      }),
    );
    return row ? mapear(row) : null;
  }

  /** Os meses disponíveis, do mais novo para o mais velho. */
  async periodosDisponiveis(limite = 24): Promise<string[]> {
    const rows = await this.tenant.withTenantTx(() =>
      this.tenant.getClient().report_monthly_summary.findMany({
        select: { period: true },
        orderBy: { period: 'desc' },
        take: limite,
      }),
    );
    return rows.map((r) => iso(r.period));
  }
}

const iso = (d: Date): string => d.toISOString().slice(0, 10);

function mapear(row: {
  period: Date;
  metrics: unknown;
  signals: unknown;
  narrative: unknown;
  ai_model: string;
  ai_status: string;
  generated_at: Date;
}): ResumoMensal {
  const metrics = row.metrics as { periodo: Periodo; kpis: Kpi[] };
  return {
    period: iso(row.period),
    periodo: metrics.periodo,
    kpis: metrics.kpis ?? [],
    sinais: (row.signals as Sinal[]) ?? [],
    narrativa: row.narrative as Narrativa,
    aiModel: row.ai_model,
    aiStatus: row.ai_status === 'ok' ? 'ok' : 'fallback',
    generatedAt: row.generated_at.toISOString(),
  };
}
