import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { PrismaService } from '../../common/database/prisma.service';
import { MailerService } from '../../common/mailer/mailer.service';
import {
  renderAcessoBloqueado,
  renderAcessoVencido,
  renderAvisoDeVencimento,
} from '../../common/mailer/mail-templates';
import { IamService } from '../iam/iam.service';

/**
 * Quantos dias antes do vencimento o aviso sai.
 *
 * Mora aqui, e não no job, porque DOIS caminhos a usam: o job da meia-noite e o
 * ajuste de data feito pelo painel, que avisa na hora quando a data ja cai na
 * janela.
 */
export const DIAS_DE_AVISO = 15;

/**
 * Os e-mails de cobrança, num lugar só.
 *
 * Existe porque DOIS caminhos avisam o cliente — o job da meia-noite e o
 * bloqueio feito à mão pelo painel — e os dois precisam mandar exatamente a
 * mesma coisa. Enquanto isso morava dentro do job, o bloqueio manual não
 * avisava ninguém; duplicar o envio no service teria criado dois textos que um
 * dia divergem.
 *
 * Nada aqui estoura: a decisão já foi gravada no banco quando o e-mail é
 * tentado, e uma falha de SMTP não pode desfazer o corte nem impedir que os
 * outros tenants sejam processados. Quem precisa saber se saiu recebe `false`.
 */
@Injectable()
export class CobrancaMailService {
  private readonly logger = new Logger(CobrancaMailService.name);

  constructor(
    private readonly iam: IamService,
    private readonly mailer: MailerService,
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Aviso ANTES de vencer. Devolve se saiu — quem chama só marca se sim. */
  avisoDeVencimento(tenantId: string, dias: number): Promise<boolean> {
    return this.enviar(tenantId, (empresa, url) =>
      renderAvisoDeVencimento({ empresa, url, dias, whatsapp: this.zap }),
    );
  }

  /** Venceu: modo consulta. */
  acessoVencido(tenantId: string): Promise<boolean> {
    return this.enviar(tenantId, (empresa, url) =>
      renderAcessoVencido({ empresa, url, whatsapp: this.zap }),
    );
  }

  /** Bloqueado — automático ou pela mão de alguém. O motivo vai no corpo. */
  acessoBloqueado(tenantId: string, motivo: string | null): Promise<boolean> {
    return this.enviar(tenantId, (empresa, url) =>
      renderAcessoBloqueado({ empresa, url, motivo, whatsapp: this.zap }),
    );
  }

  private get zap(): string | undefined {
    return this.env.SUPPORT_WHATSAPP;
  }

  private async enviar(
    tenantId: string,
    montar: (
      empresa: string,
      url: string,
    ) => { subject: string; html: string; text: string },
  ): Promise<boolean> {
    try {
      const dono = await this.iam.donoDoTenant(tenantId);
      if (!dono) {
        this.logger.warn(`sem dono ativo em ${tenantId} — ninguém para avisar`);
        return false;
      }
      // `tenant` é tabela global (sem RLS): leitura direta pelo client base.
      const empresa = await this.prisma.tenant.findUnique({
        where: { id: tenantId },
        select: { name: true },
      });
      const mail = montar(
        empresa?.name ?? 'sua empresa',
        this.env.APP_PUBLIC_URL,
      );
      await this.mailer.sendMessage({
        to: dono.email,
        subject: mail.subject,
        html: mail.html,
        text: mail.text,
      });
      return true;
    } catch (e) {
      this.logger.error(`falha ao avisar ${tenantId}: ${String(e)}`);
      return false;
    }
  }
}
