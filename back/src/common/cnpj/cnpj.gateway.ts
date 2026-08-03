import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

/** Dados públicos de uma empresa, já normalizados (fonte isolada aqui). */
export interface CnpjEmpresa {
  razaoSocial: string;
  nomeFantasia: string | null;
  situacao: string | null;
  /** Só dígitos (DDD + número) — quem formata é a UI, que já tem a máscara. */
  telefone: string | null;
  /**
   * Frequentemente VAZIO: a base pública da Receita raramente traz e-mail. Não é
   * falha da consulta — quem chama deve tratar o `null` como normal.
   */
  email: string | null;
  logradouro: string | null;
  numero: string | null;
  bairro: string | null;
  municipio: string | null;
  uf: string | null;
  cep: string | null;
}

/** Resposta crua da BrasilAPI (só o que consumimos). */
interface BrasilApiCnpj {
  razao_social?: string;
  nome_fantasia?: string;
  descricao_situacao_cadastral?: string;
  ddd_telefone_1?: string;
  ddd_telefone_2?: string;
  email?: string;
  logradouro?: string;
  numero?: string;
  bairro?: string;
  municipio?: string;
  uf?: string;
  cep?: string;
}

// Fonte pública (grátis, sem token). Trocar a fonte = trocar este arquivo.
const BRASILAPI_BASE = 'https://brasilapi.com.br/api/cnpj/v1';
const TIMEOUT_MS = 8000;

/**
 * Gateway da consulta pública de CNPJ (Receita Federal via BrasilAPI).
 *
 * Vive em `common/` porque não pertence a domínio nenhum: é infraestrutura de
 * chamada externa, consumida por `auth` (pré-cadastro do tenant) e por
 * `customers` (preencher o cliente PJ). Antes o fetch morava dentro do
 * `CnpjLookupService` do auth, que também consulta o banco de tenants — o que
 * obrigaria `customers` a depender de `auth` para reaproveitar a consulta.
 *
 * NUNCA chamar de dentro de transação de banco (chamada externa em tx é proibida).
 */
@Injectable()
export class CnpjGateway {
  private readonly logger = new Logger(CnpjGateway.name);

  /** Consulta a empresa. [cnpj] deve vir só com dígitos e já validado. */
  async fetch(cnpj: string): Promise<CnpjEmpresa> {
    const data = await this.fetchFromSource(cnpj);
    const razaoSocial = (data.razao_social ?? '').trim();
    if (!razaoSocial) {
      throw new NotFoundException('CNPJ não encontrado na Receita.');
    }
    const digits = (v: string | undefined): string | null => {
      const only = (v ?? '').replace(/\D/g, '');
      return only.length >= 10 ? only : null;
    };
    return {
      razaoSocial,
      nomeFantasia: data.nome_fantasia?.trim() || null,
      situacao: data.descricao_situacao_cadastral?.trim() || null,
      // `ddd_telefone_2` como reserva: muitas empresas só preenchem o segundo.
      telefone: digits(data.ddd_telefone_1) ?? digits(data.ddd_telefone_2),
      email: data.email?.trim() || null,
      logradouro: data.logradouro?.trim() || null,
      numero: data.numero?.trim() || null,
      bairro: data.bairro?.trim() || null,
      municipio: data.municipio?.trim() || null,
      uf: data.uf?.trim() || null,
      cep: (data.cep ?? '').replace(/\D/g, '') || null,
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
