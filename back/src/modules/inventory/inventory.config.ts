/**
 * Config do módulo Estoque & Serviços + helpers puros (precificação e saldo).
 * Os VALORES da config ficam em `tenant_module.settings['inventory']` — o módulo
 * lê/grava via `BillingService` ("aponta, não invade"), nunca tocando a tabela.
 */

export const INVENTORY_MODULE_KEY = 'inventory';
export const INVENTORY_CONFIG_KEY = 'inventory';

export interface InventoryConfig {
  /** Unidade pré-selecionada ao cadastrar um produto. */
  defaultUnit: string;
  /** Marca novos produtos como rastreáveis por padrão. */
  trackStockDefault: boolean;
  /** Margem padrão (%) usada pelo helper de markup (null = sem default). */
  defaultMarginPercent: number | null;
  /** Sugestões de categoria para autocomplete (valor salvo é texto livre). */
  categories: string[];
}

export const DEFAULT_INVENTORY_CONFIG: InventoryConfig = {
  defaultUnit: 'un',
  trackStockDefault: true,
  defaultMarginPercent: null,
  categories: [],
};

/** Merge raso e seguro de um patch parcial sobre os defaults/atual. */
export function mergeInventoryConfig(
  current: Partial<InventoryConfig> | null | undefined,
  patch: Partial<InventoryConfig> = {},
): InventoryConfig {
  const base = { ...DEFAULT_INVENTORY_CONFIG, ...(current ?? {}) };
  return {
    defaultUnit: patch.defaultUnit ?? base.defaultUnit,
    trackStockDefault: patch.trackStockDefault ?? base.trackStockDefault,
    defaultMarginPercent:
      patch.defaultMarginPercent !== undefined
        ? patch.defaultMarginPercent
        : base.defaultMarginPercent,
    categories: patch.categories ?? base.categories,
  };
}

/** Preço de venda sugerido (centavos) a partir de custo + margem%. */
export function suggestPriceCents(costCents: number, marginPercent: number): number {
  if (!costCents || costCents < 0) return 0;
  const m = marginPercent && marginPercent > 0 ? marginPercent : 0;
  return Math.round(costCents * (1 + m / 100));
}

export type MovementType = 'in' | 'out' | 'adjust';

/**
 * Saldo resultante de um movimento (em unidades, número simples).
 * - in: soma `amount`; out: subtrai `amount` (erro se negativar);
 * - adjust: `amount` é o saldo-alvo; grava o delta (magnitude) em `quantity`.
 * O repository converte de/para Prisma.Decimal.
 */
export function computeMovement(
  current: number,
  type: MovementType,
  amount: number,
): { quantity: number; balanceAfter: number } {
  if (amount < 0) throw new Error('Quantidade inválida.');
  if (type === 'in') return { quantity: amount, balanceAfter: current + amount };
  if (type === 'out') {
    const balanceAfter = current - amount;
    if (balanceAfter < 0) throw new Error('Saldo não pode ficar negativo.');
    return { quantity: amount, balanceAfter };
  }
  // adjust
  return { quantity: Math.abs(amount - current), balanceAfter: amount };
}
