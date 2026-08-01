import { Injectable, Logger } from '@nestjs/common';
import { LookupOption, SubjectLookupService } from '../subject-lookup.service';
import { PlateFipeMatch, PlateFipeRef, PlateHit } from './plate.provider';

/** Normaliza p/ comparação: sem acento, sem pontuação, minúsculo, 1 espaço. */
export function normalizeName(raw: string): string {
  return raw
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/**
 * Escolhe, entre as opções do NOSSO catálogo, a que melhor corresponde a algum
 * dos textos vindos da consulta de placa. Função pura (testável sem rede).
 *
 * Pontuação: igual (4) > opção começa com o alvo (3) > alvo começa com a opção
 * (2) > contém (1). Empate → opção mais curta, que é a mais genérica
 * ("CROSSFOX 1.6" antes de "CROSSFOX 1.6 Mi Total Flex 8V 5p Highline").
 * Alvos são testados em ordem de confiança (o 1º vale mais).
 */
export function bestMatch(
  options: LookupOption[],
  targets: (string | undefined)[],
): LookupOption | undefined {
  const wanted = targets
    .filter((t): t is string => !!t && t.trim().length > 0)
    .map(normalizeName)
    .filter((t) => t.length > 0);
  if (wanted.length === 0) return undefined;

  let best: { option: LookupOption; score: number } | undefined;
  for (const option of options) {
    const candidate = normalizeName(option.value);
    if (!candidate) continue;
    for (let i = 0; i < wanted.length; i++) {
      const target = wanted[i];
      let score = 0;
      if (candidate === target) score = 4;
      else if (candidate.startsWith(`${target} `)) score = 3;
      else if (target.startsWith(`${candidate} `)) score = 2;
      else if (candidate.includes(target) || target.includes(candidate)) {
        score = 1;
      }
      if (score === 0) continue;
      // Alvos posteriores (menos confiáveis) entram com peso menor.
      const weighted = score * 10 - i;
      const better =
        !best ||
        weighted > best.score ||
        (weighted === best.score &&
          option.value.length < best.option.value.length);
      if (better) best = { option, score: weighted };
    }
  }
  return best?.option;
}

function toRef(option: LookupOption | undefined): PlateFipeRef | undefined {
  if (!option) return undefined;
  const codigo = option.meta?.codigo;
  return {
    value: option.value,
    ...(typeof codigo === 'string' && codigo ? { codigo } : {}),
  };
}

/**
 * Casa o veículo consultado pela placa com o "equivalente" no catálogo FIPE que
 * o cadastro de veículos já usa (mesma fonte dos campos marca/modelo/ano). Sem
 * isso, o autofill escreveria a marca crua do registro ("VW") num campo cuja
 * cascata espera o valor canônico ("VW - VolksWagen") e ficaria sem o código
 * que destrava modelo/ano.
 *
 * Best-effort por natureza: siglas do registro nem sempre existem na FIPE.
 * Falhou/não casou → `undefined`, e o autofill cai no texto cru (comportamento
 * anterior). Nunca lança e nunca bloqueia a consulta, que é a parte cara.
 */
@Injectable()
export class PlateFipeMatcher {
  private readonly logger = new Logger(PlateFipeMatcher.name);

  constructor(private readonly lookup: SubjectLookupService) {}

  async match(hit: PlateHit): Promise<PlateFipeMatch | undefined> {
    try {
      // O texto FIPE da própria consulta ("VW - VolksWagen") é o alvo mais
      // confiável; a marca crua do registro ("VW") é o plano B.
      const marca = await this.matchOne(
        'fipe.marcas',
        [hit.fipe?.marca, hit.marca],
        {},
      );
      if (!marca?.codigo) return marca ? { marca } : undefined;

      const modelo = await this.matchOne(
        'fipe.modelos',
        [hit.fipe?.modelo, hit.modelo, hit.versao],
        { marca: marca.codigo },
      );
      if (!modelo?.codigo) {
        return { marca, ...(modelo ? { modelo } : {}) };
      }

      const ano = await this.matchOne(
        'fipe.anos',
        [hit.anoModelo, hit.fipe?.anoModelo, hit.ano],
        { marca: marca.codigo, modelo: modelo.codigo },
      );
      return { marca, modelo, ...(ano ? { ano } : {}) };
    } catch (err) {
      this.logger.warn(`Equivalente FIPE indisponível: ${(err as Error).message}`);
      return undefined;
    }
  }

  /** Busca candidatos pelo termo mais promissor e pontua a correspondência. */
  private async matchOne(
    fonte: string,
    targets: (string | undefined)[],
    params: { marca?: string; modelo?: string },
  ): Promise<PlateFipeRef | undefined> {
    const usable = targets.filter(
      (t): t is string => !!t && t.trim().length > 0,
    );
    if (usable.length === 0) return undefined;

    // O lookup filtra por `contains` e corta em 50; consultar pelo 1º token
    // ("VW", "CROSSFOX", "2007") mantém o recorte pequeno e certeiro. Se o
    // token não achar nada, tenta sem filtro (listas curtas, como anos).
    for (const term of [firstToken(usable[0]), undefined]) {
      const options = await this.lookup.lookup(fonte, { ...params, q: term });
      if (options.length === 0) continue;
      const hit = bestMatch(options, usable);
      if (hit) return toRef(hit);
    }
    return undefined;
  }
}

/** "VW - VolksWagen" → "VW"; "CROSSFOX 1.6 Mi" → "CROSSFOX". */
function firstToken(raw: string): string {
  return normalizeName(raw).split(' ')[0];
}
