import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { AuthRepository } from '../auth/auth.repository';
import { PasswordService } from '../../common/crypto/password.service';
import { BillingService } from '../billing/billing.service';
import { VerticalRegistry } from '../../verticals/vertical.registry';
import { normalizeCnpj, isValidCnpj } from '../auth/cnpj';
import { validateSlug } from '../auth/slug';
import { normalizeEmail } from '../auth/email';

export interface ProvisionarInput {
  tenantName: string;
  slug: string;
  cnpj: string;
  legalName: string;
  tradeName?: string;
  ownerName: string;
  ownerEmail: string;
  vertical?: string;
}

export interface TenantResumo {
  id: string;
  name: string;
  slug: string;
  cnpj: string | null;
  vertical: string | null;
  createdAt: Date;
  subscriptionStatus: string | null;
}

export interface FiltroTenants {
  /** Busca por nome, slug ou CNPJ. */
  q?: string;
  /** Ids específicos — usado pela carteira do admin, que já sabe quais quer. */
  ids?: string[];
  vertical?: string;
  limit?: number;
  offset?: number;
}

export interface PaginaTenants {
  total: number;
  items: TenantResumo[];
}

function montarWhere(f: FiltroTenants): Prisma.tenantWhereInput {
  const where: Prisma.tenantWhereInput = {};
  if (f.ids?.length) where.id = { in: f.ids };
  if (f.vertical) where.vertical = f.vertical;

  const termo = f.q?.trim();
  if (termo) {
    // CNPJ é guardado só com dígitos; quem busca digita com máscara.
    const digitos = termo.replace(/\D/g, '');
    where.OR = [
      { name: { contains: termo, mode: 'insensitive' } },
      { slug: { contains: termo, mode: 'insensitive' } },
      { legal_name: { contains: termo, mode: 'insensitive' } },
      ...(digitos ? [{ cnpj: { contains: digitos } }] : []),
    ];
  }
  return where;
}

/**
 * API administrativa consumida pelo Orbix Admin (sistema separado).
 *
 * Difere do `/auth/register` self-service em duas coisas que importam: o dono
 * NÃO está presente para escolher senha, e quem chama é uma máquina — por isso
 * a senha é gerada aqui e devolvida UMA vez, para ser repassada ao cliente.
 */
@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly authRepo: AuthRepository,
    private readonly passwords: PasswordService,
    private readonly billing: BillingService,
    private readonly verticais: VerticalRegistry,
    private readonly audit: AuditService,
  ) {}

  /**
   * Cria ambiente + dono + trial, e devolve a credencial de primeiro acesso.
   *
   * A senha provisória volta em texto claro NESTA resposta e nunca mais: ela
   * existe para ser entregue ao cliente, e guardá-la em algum lugar seria criar
   * um alvo sem necessidade. Se perder, o caminho é "esqueci minha senha".
   */
  async provisionar(input: ProvisionarInput) {
    const slugErro = validateSlug(input.slug);
    if (slugErro) throw new BadRequestException(slugErro);

    const cnpj = normalizeCnpj(input.cnpj);
    if (!isValidCnpj(cnpj)) throw new BadRequestException('CNPJ inválido.');

    const email = normalizeEmail(input.ownerEmail);
    if (await this.authRepo.findUserByEmail(email)) {
      throw new BadRequestException('Já existe usuário com este e-mail.');
    }
    if (await this.authRepo.findTenantByCnpj(cnpj)) {
      throw new BadRequestException('Este CNPJ já está cadastrado.');
    }

    // 12 bytes em base64url ≈ 16 chars: forte o bastante para uma senha
    // temporária e curta o bastante para ser ditada por telefone.
    const senhaProvisoria = randomBytes(12).toString('base64url');
    const passwordHash = await this.passwords.hash(senhaProvisoria);

    const ids = await this.authRepo.createTenantWithOwner({
      tenantName: input.tenantName,
      slug: input.slug,
      cnpj,
      legalName: input.legalName,
      tradeName: input.tradeName?.trim() || null,
      fullName: input.ownerName,
      emailNormalized: email,
      passwordHash,
      vertical:
        input.vertical && this.verticais.existe(input.vertical)
          ? input.vertical
          : null,
      createTrial: (tenantId) => this.billing.createTrial(tenantId),
    });

    await this.audit.log(ids.tenantId, ids.userId, 'tenant_provision', ids.tenantId, {
      slug: input.slug,
      por: 'orbix-admin',
    });

    return {
      tenantId: ids.tenantId,
      slug: input.slug,
      ownerEmail: email,
      senhaProvisoria,
    };
  }

  /**
   * Ambientes com o status da assinatura. `tenant` é tabela global (sem RLS),
   * então a leitura é direta; a assinatura vem pelo service público do billing,
   * que é o dono dela.
   *
   * PAGINADO de propósito. O status da assinatura custa uma consulta POR
   * ambiente: devolver a base inteira eram 4.350 consultas e 890 KB numa
   * resposta só — a página do painel não aguentaria crescer.
   */
  async listarTenants(filtro: FiltroTenants = {}): Promise<PaginaTenants> {
    const where = montarWhere(filtro);
    const limite = Math.min(Math.max(filtro.limit ?? 50, 1), 200);

    const [total, tenants] = await Promise.all([
      this.prisma.tenant.count({ where }),
      this.prisma.tenant.findMany({
        where,
        orderBy: { created_at: 'desc' },
        take: limite,
        skip: Math.max(filtro.offset ?? 0, 0),
      }),
    ]);

    // A assinatura é buscada só para a PÁGINA — nunca para a base inteira.
    const items = await Promise.all(tenants.map((t) => this.comAssinatura(t)));
    return { total, items };
  }

  async tenant(tenantId: string): Promise<TenantResumo> {
    const t = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!t) throw new NotFoundException('Ambiente não encontrado.');
    return this.comAssinatura(t);
  }

  private async comAssinatura(t: {
    id: string;
    name: string;
    slug: string;
    cnpj: string | null;
    vertical: string | null;
    created_at: Date;
  }): Promise<TenantResumo> {
    let status: string | null = null;
    try {
      status = await this.billing.getSubscriptionStatus(t.id);
    } catch {
      // Um ambiente sem assinatura legível não pode derrubar a lista inteira.
    }
    return {
      id: t.id,
      name: t.name,
      slug: t.slug,
      cnpj: t.cnpj,
      vertical: t.vertical,
      createdAt: t.created_at,
      subscriptionStatus: status,
    };
  }
}
