/**
 * Config do módulo Estoque & Produtos + validador puro de `attributes`.
 * Os VALORES ficam em `tenant_module.settings['inventory']` — lidos/gravados via
 * `BillingService` ("aponta, não invade"). Campos da vertical entram por `itemFields`
 * (mesmo padrão do `subjectFields` do módulo Clientes); o inventory é genérico e
 * nunca conhece "veículo".
 */

export const INVENTORY_MODULE_KEY = 'inventory';
export const INVENTORY_CONFIG_KEY = 'inventory';

export type ItemFieldType = 'text' | 'number' | 'tags' | 'select';

export interface ItemFieldConfig {
  key: string;
  label: string;
  type: ItemFieldType;
  required: boolean;
  /** Opções quando type === 'select'. */
  options?: string[];
}

export interface InventoryConfig {
  /** Campos extras da vertical que montam o formulário do item. */
  itemFields: ItemFieldConfig[];
}

/** Default genérico: nenhum campo de vertical (a casca da vertical semeia os seus). */
export const DEFAULT_INVENTORY_CONFIG: InventoryConfig = {
  itemFields: [],
};

/** Merge raso e seguro de um patch parcial sobre os defaults/atual. */
export function mergeInventoryConfig(
  current: Partial<InventoryConfig> | null | undefined,
  patch: Partial<InventoryConfig> = {},
): InventoryConfig {
  const base = { ...DEFAULT_INVENTORY_CONFIG, ...(current ?? {}) };
  return {
    itemFields: patch.itemFields ?? base.itemFields,
  };
}

/**
 * Valida `attributes` (whitelist) contra `itemFields`. Retorna lista de erros
 * (vazia = ok) — puro, sem Nest. Regras:
 *  - chave fora do itemFields => erro;
 *  - tipo errado (text→string, number→number finito, tags→string[], select→string ∈ options) => erro;
 *  - campo required ausente/vazio => erro.
 */
export function validateAttributes(
  attributes: Record<string, unknown> | null | undefined,
  itemFields: ItemFieldConfig[],
): string[] {
  const attrs = attributes ?? {};
  const errors: string[] = [];
  const byKey = new Map(itemFields.map((f) => [f.key, f]));

  for (const key of Object.keys(attrs)) {
    if (!byKey.has(key)) {
      errors.push(`Campo desconhecido em attributes: "${key}".`);
      continue;
    }
    const field = byKey.get(key)!;
    const value = attrs[key];
    if (value === null || value === undefined) continue; // ausência tratada no required abaixo
    switch (field.type) {
      case 'text':
        if (typeof value !== 'string') errors.push(`"${field.key}" deve ser texto.`);
        break;
      case 'number':
        if (typeof value !== 'number' || !Number.isFinite(value))
          errors.push(`"${field.key}" deve ser número.`);
        break;
      case 'tags':
        if (!Array.isArray(value) || value.some((v) => typeof v !== 'string'))
          errors.push(`"${field.key}" deve ser uma lista de textos.`);
        break;
      case 'select':
        if (typeof value !== 'string' || !(field.options ?? []).includes(value))
          errors.push(`"${field.key}" deve ser uma das opções válidas.`);
        break;
    }
  }

  for (const field of itemFields) {
    if (!field.required) continue;
    const v = attrs[field.key];
    const empty =
      v === null ||
      v === undefined ||
      (typeof v === 'string' && v.trim() === '') ||
      (Array.isArray(v) && v.length === 0);
    if (empty) errors.push(`Campo obrigatório ausente: "${field.key}".`);
  }

  return errors;
}
