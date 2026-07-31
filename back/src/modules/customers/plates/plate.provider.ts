/** Token de DI do provedor de consulta de placas (padrão CATALOG_PROVIDER). */
export const PLATE_PROVIDER = Symbol('PLATE_PROVIDER');

/** Regex compartilhada: placa antiga (AAA9999) ou Mercosul (AAA9A99). */
const PLATE_RE = /^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$/;

/**
 * Normaliza a placa digitada (maiúsculas, sem separadores) e valida o formato.
 * Retorna `null` quando inválida — valide ANTES de gastar cota/chamada externa.
 */
export function normalizePlate(raw: string): string | null {
  const p = raw.toUpperCase().replace(/[^0-9A-Z]/g, '');
  return PLATE_RE.test(p) ? p : null;
}

/** Melhor correspondência FIPE da consulta (a de maior `score`, ver doc da API). */
export interface PlateFipe {
  codigoFipe?: string;
  marca?: string; // texto_marca ("VW - VolksWagen")
  modelo?: string; // texto_modelo ("CROSSFOX 1.6 Mi Total Flex 8V 5p")
  valor?: string; // texto_valor ("R$ 28.799,00")
  combustivel?: string;
  anoModelo?: string;
  mesReferencia?: string;
  score?: number;
}

/**
 * Dados normalizados do veículo — é isto que vai pro cache (`plate_cache.payload`)
 * e pro front (autofill do cadastro + ficha em PDF). Chaves em PT-BR, alinhadas
 * ao vocabulário do produto (marca/modelo/ano/cor são as chaves dos campos do
 * cadastro de veículo em `customers.config`).
 */
export interface PlateHit {
  placa: string;
  placaAlternativa?: string;
  marca?: string;
  modelo?: string;
  versao?: string;
  ano?: string; // ano de fabricação
  anoModelo?: string;
  cor?: string;
  chassi?: string; // mascarado pela própria API
  municipio?: string;
  uf?: string;
  situacao?: string;
  origem?: string;
  combustivel?: string;
  cilindradas?: string;
  especie?: string;
  tipoVeiculo?: string;
  passageiros?: string;
  segmento?: string;
  nacionalidade?: string;
  logoUrl?: string;
  fipe?: PlateFipe;
}

/**
 * Resultado da chamada externa, discriminado pelos códigos da API
 * (200 ok · 406 sem resultados · 401 placa inválida · 429 limite do provedor ·
 * resto/rede → indisponível). O service decide o que consome cota e o que devolve.
 */
export type PlateLookupOutcome =
  | { status: 'ok'; hit: PlateHit }
  | { status: 'not_found' }
  | { status: 'invalid' }
  | { status: 'provider_limit' }
  | { status: 'unavailable' };

/** Contrato do provedor. Impl real: wdapi2 (API Placas). Noop: sempre indisponível. */
export abstract class PlateProvider {
  abstract lookup(plate: string): Promise<PlateLookupOutcome>;
}

/** Default quando PLACAS_ENABLED=false ou sem token — nunca chama fora. */
export class NoopPlateProvider extends PlateProvider {
  lookup(): Promise<PlateLookupOutcome> {
    return Promise.resolve({ status: 'unavailable' });
  }
}
