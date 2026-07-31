import { Logger } from '@nestjs/common';
import type { Env } from '../../../common/config/env.schema';
import {
  PlateFipe,
  PlateHit,
  PlateLookupOutcome,
  PlateProvider,
} from './plate.provider';

export const WDAPI_BASE_URL = 'https://wdapi2.com.br';

/** Timeout curto: consulta é interativa (usuário esperando no formulário). */
const WDAPI_TIMEOUT_MS = 10_000;

/**
 * Provedor real — API Placas (apiplacas.com.br), servida em wdapi2.com.br.
 * `GET {base}/consulta/{placa}/{token}`. O token é segredo de plataforma
 * (PLACAS_TOKEN, só via env — NUNCA vai pro front). Erros degradam para um
 * outcome tipado; este client não lança (padrão CosmosCatalogProvider).
 */
export class WdapiPlateProvider extends PlateProvider {
  private readonly logger = new Logger(WdapiPlateProvider.name);

  constructor(
    private readonly env: Env,
    // Injetável nos testes; default vem do env p/ apontar homolog/mocks.
    private readonly baseUrl: string = env.PLACAS_BASE_URL || WDAPI_BASE_URL,
  ) {
    super();
  }

  async lookup(plate: string): Promise<PlateLookupOutcome> {
    if (!this.env.PLACAS_ENABLED || !this.env.PLACAS_TOKEN) {
      return { status: 'unavailable' };
    }
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), WDAPI_TIMEOUT_MS);
    try {
      const url = `${this.baseUrl}/consulta/${encodeURIComponent(plate)}/${this.env.PLACAS_TOKEN}`;
      const res = await fetch(url, { signal: controller.signal });
      // Códigos documentados: 401 placa inválida · 406 sem resultados ·
      // 429 limite do plano no provedor · 402 token inválido.
      if (res.status === 406) return { status: 'not_found' };
      if (res.status === 401) return { status: 'invalid' };
      if (res.status === 429) {
        this.logger.warn('API Placas: limite de consultas do plano atingido');
        return { status: 'provider_limit' };
      }
      if (!res.ok) {
        this.logger.warn(`API Placas: HTTP ${res.status} para a consulta`);
        return { status: 'unavailable' };
      }
      const body = (await res.json()) as Record<string, unknown>;
      return { status: 'ok', hit: normalizeWdapiResponse(plate, body) };
    } catch (err) {
      this.logger.warn(`API Placas indisponível: ${(err as Error).message}`);
      return { status: 'unavailable' };
    } finally {
      clearTimeout(timeout);
    }
  }
}

/** String não-vazia e aparada, ou undefined (payload do cache fica enxuto). */
function s(v: unknown): string | undefined {
  if (typeof v !== 'string' && typeof v !== 'number') return undefined;
  const t = String(v).trim();
  return t.length > 0 ? t : undefined;
}

/**
 * Achata a resposta crua da wdapi2 no PlateHit. Campos do `extra` e da FIPE
 * "são exibidos sempre que disponíveis, mas podem estar incompletos ou ausentes"
 * (doc) — tudo aqui é defensivo. Da FIPE escolhemos a entrada de maior `score`
 * (melhor correspondência nome↔marca, recomendação da própria doc).
 */
export function normalizeWdapiResponse(
  plate: string,
  raw: Record<string, unknown>,
): PlateHit {
  const extra = (raw.extra ?? {}) as Record<string, unknown>;
  const fipeDados = (raw.fipe as { dados?: unknown } | undefined)?.dados;
  let fipe: PlateFipe | undefined;
  if (Array.isArray(fipeDados) && fipeDados.length > 0) {
    const best = [...fipeDados].sort(
      (a, b) =>
        (Number((b as Record<string, unknown>).score) || 0) -
        (Number((a as Record<string, unknown>).score) || 0),
    )[0] as Record<string, unknown>;
    fipe = {
      codigoFipe: s(best.codigo_fipe),
      marca: s(best.texto_marca),
      modelo: s(best.texto_modelo),
      valor: s(best.texto_valor),
      combustivel: s(best.combustivel),
      anoModelo: s(best.ano_modelo),
      mesReferencia: s(best.mes_referencia),
      score: Number(best.score) || undefined,
    };
  }
  return {
    placa: s(raw.placa) ?? plate,
    placaAlternativa: s(raw.placa_alternativa),
    marca: s(raw.MARCA) ?? s(raw.marca),
    modelo: s(raw.MODELO) ?? s(raw.modelo),
    versao: s(raw.VERSAO) ?? s(raw.SUBMODELO),
    ano: s(raw.ano) ?? s(extra.ano_fabricacao),
    anoModelo: s(raw.anoModelo) ?? s(extra.ano_modelo),
    cor: s(raw.cor),
    chassi: s(raw.chassi),
    municipio: s(raw.municipio) ?? s(extra.municipio),
    uf: s(raw.uf) ?? s(extra.uf),
    situacao: s(raw.situacao),
    origem: s(raw.origem),
    combustivel: s(extra.combustivel),
    cilindradas: s(extra.cilindradas),
    especie: s(extra.especie),
    tipoVeiculo: s(extra.tipo_veiculo),
    passageiros: s(extra.quantidade_passageiro),
    segmento: s(extra.sub_segmento),
    nacionalidade: s(extra.nacionalidade),
    logoUrl: s(raw.logo),
    ...(fipe ? { fipe } : {}),
  };
}
