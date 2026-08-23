import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import { AccessTokenService } from '../../common/auth/jwt.service';
import { AuditService } from '../../common/audit/audit.service';
import { AuthRepository } from './auth.repository';

/** Minutos de vida do código no link. Curto: é para clicar agora. */
const VALIDADE_DO_CODIGO_MIN = 5;

/**
 * O propósito CARREGA o tenant de destino: `support_session:<uuid>`.
 *
 * O destino precisa viajar com o código, e o único lugar seguro é o banco —
 * na URL ele seria palpite de quem clica. Antes o consumo caía na primeira
 * membership do dono, e dono de duas empresas abria sessão na empresa errada,
 * com o audit da outra dizendo que alguém entrou.
 */
const PROPOSITO = 'support_session';
const prefixoDe = (tenantId: string) => `${PROPOSITO}:${tenantId}`;

export interface LinkDeSuporte {
  url: string;
  expiraEm: Date;
  /** Para quem o painel vai entrar — mostrar antes de clicar evita surpresa. */
  comoEmail: string;
}

/**
 * Sessão de suporte: a Orbix entra no ambiente do cliente para ver o problema
 * com os olhos dele.
 *
 * Três decisões que sustentam isso sem virar uma porta dos fundos:
 *
 * 1. O link carrega um código de USO ÚNICO e vida curta (5 min), guardado como
 *    hash — quem lê o banco não consegue entrar. Vazou depois de usado, não
 *    vale nada; vazou antes, expira sozinho.
 * 2. A sessão entregue tem SÓ token de acesso (15 min), sem refresh. Não há
 *    credencial duradoura para esquecer aberta: acabou o tempo, acabou o
 *    acesso, e é preciso gerar outro link — o que gera outra linha de auditoria.
 * 3. Toda emissão e todo consumo ficam no `audit_log` DO TENANT. O cliente pode
 *    perguntar quem entrou no ambiente dele e a resposta está lá, não na nossa
 *    palavra.
 */
@Injectable()
export class SupportSessionService {
  private readonly logger = new Logger(SupportSessionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
    private readonly repo: AuthRepository,
    private readonly accessTokens: AccessTokenService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Gera o link. Entra como o DONO do ambiente — é quem enxerga tudo, e é o
   * único cargo garantido de existir em qualquer tenant.
   */
  async criarLink(tenantId: string, quem: string): Promise<LinkDeSuporte> {
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Ambiente não encontrado.');

    const dono = await this.acharDono(tenantId);
    if (!dono) {
      throw new BadRequestException(
        'Este ambiente não tem dono ativo — não há por quem entrar.',
      );
    }

    const codigo = randomBytes(32).toString('base64url');
    await this.repo.createOneTimeToken(
      dono.id,
      prefixoDe(tenantId),
      hash(codigo),
      VALIDADE_DO_CODIGO_MIN,
    );

    await this.audit.log(tenantId, null, 'support_session', dono.id, {
      acao: 'link_gerado',
      por: quem,
    });
    this.logger.log(`[suporte] link gerado para ${tenant.slug} por ${quem}`);

    // `/#/` porque o app web roteia por HASH — é a mesma forma dos links de
    // verificação e reset que já saem por e-mail. Sem o `#`, o Flutter carrega
    // na rota raiz, não vê o código e manda para o login.
    const base = this.env.APP_PUBLIC_URL.replace(/\/$/, '');
    return {
      url: `${base}/#/suporte-orbix?code=${codigo}`,
      expiraEm: new Date(Date.now() + VALIDADE_DO_CODIGO_MIN * 60_000),
      comoEmail: dono.email_normalized,
    };
  }

  /**
   * Troca o código pelo token de acesso. Consome ANTES de emitir: se algo
   * falhar depois, o código já queimou — repetir a tentativa não dá duas
   * sessões pelo mesmo link.
   */
  async consumir(codigo: string): Promise<{ accessToken: string }> {
    const registro = await this.repo.findOneTimeTokenByPurposePrefix(
      hash(codigo),
      `${PROPOSITO}:`,
    );
    if (!registro?.user_id) {
      throw new UnauthorizedException('Link de suporte inválido ou expirado.');
    }
    await this.repo.consumeOneTimeToken(registro.id);

    // O tenant vem do registro, nunca do cliente — é o ambiente para o qual
    // ESTE link foi gerado.
    const tenantId = registro.purpose.slice(PROPOSITO.length + 1);

    // A RLS ainda não pode ser satisfeita (não há JWT), então a leitura usa a
    // função `SECURITY DEFINER` que o seletor de empresa já usa pré-contexto —
    // o mesmo padrão dos fluxos sem JWT.
    const memberships = await this.repo.findUserMemberships(registro.user_id);
    // A membership tem de ser a DESTE tenant. Um dono de duas empresas tinha
    // 50% de chance de cair na errada quando isto era `memberships[0]`.
    const membership = memberships.find((m) => m.tenant_id === tenantId);
    if (!membership) {
      throw new UnauthorizedException('Link de suporte inválido ou expirado.');
    }

    await this.audit.log(
      tenantId,
      registro.user_id,
      'support_session',
      registro.user_id,
      { acao: 'sessao_iniciada' },
    );

    return {
      accessToken: this.accessTokens.sign({
        sub: registro.user_id,
        tid: tenantId,
        role: membership.role_key as 'owner',
        jti: randomUUID(),
      }),
    };
  }

  /**
   * `membership` é tenant-scoped: ler sem contexto devolve VAZIO pela RLS, e o
   * sintoma é "este ambiente não tem dono" num ambiente que tem. Sabemos o
   * tenant aqui, então a leitura roda sob `runWithTenant`.
   */
  private async acharDono(tenantId: string) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const m = await db.membership.findFirst({
        where: { tenant_id: tenantId, status: 'active', role: { key: 'owner' } },
        include: { users: true },
        orderBy: { created_at: 'asc' },
      });
      return m?.users ?? null;
    });
  }
}

/** Só o hash vai para o banco — o código existe apenas no link. */
function hash(codigo: string): string {
  return createHash('sha256').update(codigo).digest('hex');
}
