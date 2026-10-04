import { Injectable, Logger } from '@nestjs/common';
import { MailerService } from '../../../common/mailer/mailer.service';
import { TenantContext } from '../../../common/database/tenant-context';
import { NotificationsService } from '../../notifications/notifications.service';
import { EmployeesService } from '../../iam/employees.service';
import { ResumoMensal } from './monthly-summary.repository';

/**
 * Entrega o resumo pronto: sino no app e e-mail para o dono.
 *
 * Os dois canais existem porque alcançam pessoas diferentes. O sino pega quem
 * já está no sistema; o e-mail pega quem não entra há semanas — e relatório
 * mensal é lido na caixa de entrada, não procurado num menu.
 *
 * Avisar é parte da ENTREGA, nunca da geração: se o e-mail falhar, o resumo
 * continua gravado e visível. Por isso quem chama trata a falha daqui sem
 * desfazer nada.
 */
@Injectable()
export class MonthlySummaryNotifier {
  private readonly logger = new Logger(MonthlySummaryNotifier.name);

  constructor(
    private readonly notifications: NotificationsService,
    private readonly employees: EmployeesService,
    private readonly mailer: MailerService,
    private readonly tenant: TenantContext,
  ) {}

  async avisar(tenantId: string, resumo: ResumoMensal): Promise<void> {
    // Porta pública do módulo de notificações — nunca a tabela dele.
    //
    // `refId` fica de FORA: a coluna é `uuid`, e o mês ("2026-09-01") não é um.
    // Mandá-lo ali fazia o insert estourar em "Error creating UUID" e o aviso
    // simplesmente não chegava — o resumo existia e ninguém era avisado. O mês
    // vai no título, que é onde o leitor precisa dele de qualquer forma.
    await this.notifications.notify(tenantId, {
      type: 'report_monthly_summary',
      title: `Seu resumo de ${resumo.periodo.rotulo} está pronto`,
      body: resumo.narrativa.titulo,
      refType: 'report_month',
    });

    const donos = await this.tenant.runWithTenant(tenantId, async () => {
      const membros = await this.employees.listEmployees();
      return membros.filter(
        (m) => m.role === 'owner' && m.status === 'active' && m.email,
      );
    });

    for (const dono of donos) {
      try {
        await this.mailer.sendMessage({
          to: dono.email!,
          subject: `Resumo de ${resumo.periodo.rotulo}`,
          text: textoDoEmail(resumo),
          html: htmlDoEmail(resumo),
        });
      } catch (e) {
        // Um endereço que bounce não pode impedir o outro dono de receber.
        this.logger.warn(
          `Falha ao enviar o resumo para ${dono.email}: ${
            e instanceof Error ? e.message : String(e)
          }`,
        );
      }
    }
  }
}

const money = (v: number): string =>
  v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

const valor = (k: ResumoMensal['kpis'][number]): string =>
  k.formato === 'dinheiro' ? money(k.valor) : String(k.valor);

/** "▲ 12%" / "▼ 4%" / "" — a seta só aparece quando há comparação. */
function seta(k: ResumoMensal['kpis'][number]): string {
  if (!k.variacao) return '';
  const subiu = k.variacao.pct > 0;
  return `${subiu ? '▲' : '▼'} ${Math.abs(k.variacao.pct)}%`;
}

function textoDoEmail(r: ResumoMensal): string {
  const linhas = [
    r.narrativa.titulo,
    '',
    r.narrativa.leitura,
    '',
    'NÚMEROS DO MÊS',
    ...r.kpis.map((k) => `- ${k.rotulo}: ${valor(k)} ${seta(k)}`.trimEnd()),
  ];
  if (r.narrativa.alertas.length > 0) {
    linhas.push('', 'O QUE MERECE ATENÇÃO', ...r.narrativa.alertas.map((a) => `- ${a}`));
  }
  if (r.narrativa.recomendacoes.length > 0) {
    linhas.push('', 'PARA ESTE MÊS', ...r.narrativa.recomendacoes.map((a) => `- ${a}`));
  }
  return linhas.join('\n');
}

/**
 * HTML simples e tabular de propósito: cliente de e-mail não é navegador, e um
 * relatório que chega quebrado no Outlook não é lido.
 */
function htmlDoEmail(r: ResumoMensal): string {
  const kpis = r.kpis
    .map(
      (k) => `<tr>
        <td style="padding:6px 12px 6px 0;color:#555">${esc(k.rotulo)}</td>
        <td style="padding:6px 0;font-weight:700">${esc(valor(k))}</td>
        <td style="padding:6px 0 6px 10px;color:#888">${esc(seta(k))}</td>
      </tr>`,
    )
    .join('');
  const lista = (titulo: string, itens: string[]): string =>
    itens.length === 0
      ? ''
      : `<h3 style="font-size:15px;margin:22px 0 8px">${titulo}</h3>
         <ul style="margin:0;padding-left:18px;color:#333;line-height:1.6">
           ${itens.map((i) => `<li>${esc(i)}</li>`).join('')}
         </ul>`;

  return `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;color:#222">
    <h2 style="font-size:18px;margin:0 0 6px">${esc(r.narrativa.titulo)}</h2>
    <p style="color:#555;line-height:1.6;margin:0 0 18px">${esc(r.narrativa.leitura)}</p>
    <table style="border-collapse:collapse;font-size:14px">${kpis}</table>
    ${lista('O que merece atenção', r.narrativa.alertas)}
    ${lista('Para este mês', r.narrativa.recomendacoes)}
  </div>`;
}

const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
