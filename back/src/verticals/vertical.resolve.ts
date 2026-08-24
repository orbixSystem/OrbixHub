import type { CampoVertical, DefinicaoFeature, PacoteVertical } from './vertical.types';

/**
 * Resolvedores PUROS (sem Nest, sem banco) das duas cascatas do design.
 * Ficam separados dos services de propósito: é a regra de negócio inteira, e
 * regra testável sem infraestrutura é regra que a gente confia.
 */

/** Acha o pacote da vertical; cai no padrão quando a chave é nula/desconhecida. */
export function acharPacote(
  pacotes: PacoteVertical[],
  verticalKey: string | null | undefined,
): { pacote: PacoteVertical | null; padrao: PacoteVertical | null } {
  const padrao = pacotes.find((p) => p.isDefault) ?? null;
  if (!verticalKey) return { pacote: padrao, padrao };
  // Chave desconhecida (vertical removida do código, dado velho no banco) cai no
  // padrão em vez de explodir: um tenant não pode ficar sem app porque alguém
  // renomeou uma pasta.
  const pacote = pacotes.find((p) => p.key === verticalKey) ?? padrao;
  return { pacote, padrao };
}

/**
 * Vocabulário efetivo.
 *
 *   pacote padrão  →  pacote da vertical  →  overrides do tenant
 *
 * Só a última camada vem do banco (`tenant.settings.vocabOverrides`); as duas
 * primeiras vêm do código e por isso evoluem para todos os tenants de uma vez —
 * é o que impede o snapshot congelado que quebrou o autocomplete FIPE.
 */
export function resolverVocab(
  pacotes: PacoteVertical[],
  verticalKey: string | null | undefined,
  overrides?: Record<string, unknown> | null,
): Record<string, string> {
  const { pacote, padrao } = acharPacote(pacotes, verticalKey);
  const base: Record<string, string> = { ...(padrao?.vocab ?? {}) };
  if (pacote && pacote !== padrao) Object.assign(base, pacote.vocab);
  // Override só sobrescreve chave que já existe e só com texto: um valor
  // estranho salvo no jsonb não deve virar rótulo de tela.
  for (const [k, v] of Object.entries(overrides ?? {})) {
    if (typeof v === 'string' && v.trim() !== '' && k in base) base[k] = v;
  }
  return base;
}

/**
 * Campos do formulário do subject. Substituição INTEIRA, não merge por chave:
 * formulário é lista ordenada, não conjunto de propriedades. Pacote sem
 * `subjectFields` herda os do padrão.
 */
export function resolverCampos(
  pacotes: PacoteVertical[],
  verticalKey: string | null | undefined,
): CampoVertical[] {
  const { pacote, padrao } = acharPacote(pacotes, verticalKey);
  return pacote?.subjectFields ?? padrao?.subjectFields ?? [];
}

/** Estado de uma feature para uma decisão de disponibilidade. */
export interface ContextoFeature {
  /** Módulos habilitados no tenant (vem do billing, pelo chamador). */
  modulosHabilitados: string[];
  /** Capacidade → verticais que a implementam. */
  comImplementacao: ReadonlyMap<string, ReadonlySet<string>>;
  /** Toggles explícitos do tenant (linha em tenant_feature). */
  toggles: Map<string, boolean>;
  /** Pacote da vertical do tenant. */
  verticalKey: string | null | undefined;
}

/**
 * Uma capacidade é DISPONÍVEL quando o módulo dono está habilitado e, se ela
 * exige implementação, o NICHO DESTE TENANT tem uma. Indisponível não é
 * "desligada": não aparece nem como toggle, porque ligar não faria efeito.
 *
 * Casar com o nicho (e não só com "alguém implementou") é o que impede a
 * clínica de ligar consulta de placa só porque a vertical veículos existe no
 * mesmo processo — e o `FeatureAccessGuard`, que confia nesta função, liberar
 * a rota em seguida.
 *
 * É aqui que `plan_feature` entra como mais um `&&` quando houver cobrança —
 * e o front não muda, porque continua lendo a lista pronta do /me.
 */
export function featureDisponivel(def: DefinicaoFeature, ctx: ContextoFeature): boolean {
  if (!ctx.modulosHabilitados.includes(def.moduleKey)) return false;
  if (def.requerImplementacao) {
    const verticais = ctx.comImplementacao.get(def.key);
    if (!ctx.verticalKey || !verticais?.has(ctx.verticalKey)) return false;
  }
  return true;
}

/**
 * Uma capacidade disponível está LIGADA por:
 *   toggle do tenant  ??  featuresLigadas do pacote  ??  defaultEnabled
 *
 * O `??` (e não valor copiado) é o coração do design: capacidade nova entra no
 * pacote e alcança todo tenant daquele nicho sem migration de dados, porque
 * quem não mexeu não tem linha no banco.
 */
export function featureLigada(
  def: DefinicaoFeature,
  ctx: ContextoFeature,
  pacotes: PacoteVertical[],
): boolean {
  if (!featureDisponivel(def, ctx)) return false;
  const explicito = ctx.toggles.get(def.key);
  if (explicito !== undefined) return explicito;
  const { pacote } = acharPacote(pacotes, ctx.verticalKey);
  if (pacote?.featuresLigadas.includes(def.key)) return true;
  return def.defaultEnabled;
}

/** Chaves efetivamente ligadas, ordenadas — é o `features[]` do /me. */
export function featuresLigadas(
  defs: DefinicaoFeature[],
  ctx: ContextoFeature,
  pacotes: PacoteVertical[],
): string[] {
  return defs
    .filter((d) => featureLigada(d, ctx, pacotes))
    .map((d) => d.key)
    .sort();
}
