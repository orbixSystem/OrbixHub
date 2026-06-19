import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AuthRepository } from './auth.repository';
import { isValidCnpj, normalizeCnpj, formatCnpj } from './cnpj';

/** Normalized company data returned to the registration UI. */
export interface CnpjLookupResult {
  cnpj: string; // formatado XX.XXX.XXX/XXXX-XX
  razaoSocial: string;
  nomeFantasia: string | null;
  situacao: string | null;
  municipio: string | null;
  uf: string | null;
  /** true quando já existe um tenant cadastrado com esse CNPJ. */
  alreadyRegistered: boolean;
}

// Fonte pública (grátis, sem token). Trocar a fonte = trocar este endpoint/parser.
const BRASILAPI_BASE = 'https://brasilapi.com.br/api/cnpj/v1';
const TIMEOUT_MS = 8000;

interface BrasilApiCnpj {
  razao_social?: string;
  nome_fantasia?: string;
  descricao_situacao_cadastral?: string;
  municipio?: string;
  uf?: string;
}

/**
 * Consulta dados públicos de empresa a partir do CNPJ (Receita Federal via
 * BrasilAPI). Service fino com a fonte isolada — chamada externa NUNCA dentro de
 * transação de banco; este fluxo é público (pré-cadastro), sem JWT.
 */
@Injectable()
export class CnpjLookupService {
  private readonly logger = new Logger(CnpjLookupService.name);

  constructor(private readonly repo: AuthRepository) {}

  async lookup(rawCnpj: string): Promise<CnpjLookupResult> {
    const cnpj = normalizeCnpj(rawCnpj);
    if (!isValidCnpj(cnpj)) {
      throw new BadRequestException('CNPJ inválido.');
    }

    const data = await this.fetchFromSource(cnpj);
    const razaoSocial = (data.razao_social ?? '').trim();
    if (!razaoSocial) {
      throw new NotFoundException('CNPJ não encontrado na Receita.');
    }

    const existing = await this.repo.findTenantByCnpj(cnpj);

    return {
      cnpj: formatCnpj(cnpj),
      razaoSocial,
      nomeFantasia: data.nome_fantasia?.trim() || null,
      situacao: data.descricao_situacao_cadastral?.trim() || null,
      municipio: data.municipio?.trim() || null,
      uf: data.uf?.trim() || null,
      alreadyRegistered: existing !== null,
    };
  }

  private async fetchFromSource(cnpj: string): Promise<BrasilApiCnpj> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const res = await fetch(`${BRASILAPI_BASE}/${cnpj}`, {
        signal: controller.signal,
        // BrasilAPI (edge na Vercel) bloqueia com 403 o User-Agent padrão do
        // undici/Node — qualquer UA explícito passa. Sem isto o fetch falha.
        headers: { accept: 'application/json', 'user-agent': 'OrbixHub/1.0' },
      });
      if (res.status === 404) {
        throw new NotFoundException('CNPJ não encontrado na Receita.');
      }
      if (!res.ok) {
        throw new ServiceUnavailableException(
          'Não foi possível consultar o CNPJ agora. Tente novamente.',
        );
      }
      return (await res.json()) as BrasilApiCnpj;
    } catch (e) {
      if (e instanceof NotFoundException) throw e;
      this.logger.warn(`Falha ao consultar CNPJ na fonte: ${String(e)}`);
      throw new ServiceUnavailableException(
        'Não foi possível consultar o CNPJ agora. Tente novamente.',
      );
    } finally {
      clearTimeout(timer);
    }
  }
}
