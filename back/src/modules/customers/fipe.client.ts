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

/** Provider de dados de veículo (casca de carro). Trocável por outra fonte. */
export interface FipeClient {
  brands(): Promise<FipeBrand[]>;
  models(brandCode: string): Promise<FipeModel[]>;
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
}
