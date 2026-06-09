// back/src/modules/customers/fipe.client.ts

/** Token de DI para a interface (permite trocar provider/fake em teste). */
export const FIPE_CLIENT = Symbol('FIPE_CLIENT');

/** Base pública da FIPE (Parallelum v2). Não é segredo; const por ora. */
export const FIPE_BASE_URL = 'https://fipe.parallelum.com.br/api/v2';

export interface FipeBrand {
  code: string;
  name: string;
}
export interface FipeModel {
  code: string;
  name: string;
}
export interface FipeYear {
  code: string;
  /** Ex.: "2024 Gasolina"; "32000 Gasolina" = zero km. */
  name: string;
}

/** Provider de dados de veículo (casca de carro). Trocável por outra fonte. */
export interface FipeClient {
  brands(): Promise<FipeBrand[]>;
  models(brandCode: string): Promise<FipeModel[]>;
  years(brandCode: string, modelCode: string): Promise<FipeYear[]>;
}

/**
 * URL do logo da marca num dataset público (casca de carro, best-effort). Nomes
 * estranhos da FIPE ("VW - VolksWagen", "GM - Chevrolet") são normalizados para
 * o slug do dataset; o que não casar cai num ícone genérico no front.
 */
export function brandLogoUrl(name: string): string {
  const base = name.includes(' - ') ? name.split(' - ').pop()! : name;
  const slug = base
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return `https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/thumb/${slug}.png`;
}

/** Impl real via `fetch` (Node 24). Lança em status != 2xx — o caller degrada. */
export class HttpFipeClient implements FipeClient {
  constructor(private readonly baseUrl: string = FIPE_BASE_URL) {}

  async brands(): Promise<FipeBrand[]> {
    const res = await fetch(`${this.baseUrl}/cars/brands`);
    if (!res.ok) throw new Error(`FIPE brands HTTP ${res.status}`);
    return (await res.json()) as FipeBrand[];
  }

  async models(brandCode: string): Promise<FipeModel[]> {
    const res = await fetch(
      `${this.baseUrl}/cars/brands/${encodeURIComponent(brandCode)}/models`,
    );
    if (!res.ok) throw new Error(`FIPE models HTTP ${res.status}`);
    return (await res.json()) as FipeModel[];
  }

  async years(brandCode: string, modelCode: string): Promise<FipeYear[]> {
    const res = await fetch(
      `${this.baseUrl}/cars/brands/${encodeURIComponent(brandCode)}/models/${encodeURIComponent(modelCode)}/years`,
    );
    if (!res.ok) throw new Error(`FIPE years HTTP ${res.status}`);
    return (await res.json()) as FipeYear[];
  }
}
