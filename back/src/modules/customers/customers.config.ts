/**
 * Config do módulo Clientes & Veículos.
 *
 * Os VALORES ficam em `tenant_module.settings['clientes_veiculos']` — tabela do
 * billing. Este módulo nunca toca `tenant_module`: lê/grava via os métodos
 * públicos `BillingService.getModuleSettings` / `setModuleSettings`
 * ("aponta, não invade").
 *
 * O rótulo do subject ("Veículo" na oficina, "Pet" no petshop) e os campos do
 * formulário são genéricos e vêm daqui em runtime — nada de termo de vertical
 * hardcoded no código nem no front.
 */

/** Chave do módulo no catálogo (`module.key`). */
export const CUSTOMERS_MODULE_KEY = 'customers';

/** Chave da config dentro de `tenant_module.settings`. */
export const CUSTOMERS_CONFIG_KEY = 'clientes_veiculos';

export type SubjectFieldType = 'text' | 'number';

export interface SubjectFieldConfig {
  chave: string;
  rotulo: string;
  tipo: SubjectFieldType;
  obrigatorio: boolean;
  /** Fonte de autocomplete (ex.: 'fipe.marcas'). Ausente = campo manual. */
  fonte?: string;
  /** Chave do campo do qual este depende na cascata (ex.: modelo→'marca'). */
  dependeDe?: string;
}

export interface SubjectLabelConfig {
  singular: string;
  plural: string;
}

export interface CustomersConfig {
  /** Liga/desliga a entidade subject (ex.: salão = false). */
  usaSubjects: boolean;
  /** Rótulo dinâmico do subject exibido na UI. */
  subjectLabel: SubjectLabelConfig;
  /** Campos que montam o formulário do subject (placa = `identifier`). */
  subjectFields: SubjectFieldConfig[];
  /** Quando true, exige `document` no cadastro de cliente. */
  documentRequired: boolean;
}

/**
 * Base GENÉRICA da config — sem nenhum termo de vertical.
 *
 * O rótulo do objeto e os campos do formulário NÃO moram mais aqui: vêm do
 * pacote da vertical do tenant (`back/src/verticals/`), resolvidos em runtime
 * por `CustomersService.getConfig`. Este objeto só carrega o que independe de
 * nicho, e serve de piso quando nenhum pacote responde.
 *
 * Antes, este arquivo continha os defaults de oficina ("Veículo", "Placa",
 * cascata FIPE) — era a casca de vertical cravada no módulo que se dizia
 * genérico. Ver docs/superpowers/specs/2026-08-17-verticais-nicho-features-design.md
 */
export const DEFAULT_CUSTOMERS_CONFIG: CustomersConfig = {
  usaSubjects: true,
  subjectLabel: { singular: 'Objeto', plural: 'Objetos' },
  subjectFields: [],
  documentRequired: false,
};

/**
 * Reaplica `fonte`/`dependeDe` dos defaults a campos salvos com a mesma `chave`
 * mas sem esses atributos. Snapshots de config persistidos antes da introdução
 * de uma fonte (ex.: FIPE em marca/modelo) ficam congelados; isto restaura o
 * autocomplete em runtime, sem migration de dados, e blinda futuras adições de
 * default. Campos personalizados (sem default correspondente) ficam intactos.
 */
function withFieldSourceDefaults(
  fields: SubjectFieldConfig[],
  defaults: SubjectFieldConfig[],
): SubjectFieldConfig[] {
  const defaultsByChave = new Map(defaults.map((f) => [f.chave, f]));
  return fields.map((field) => {
    const def = defaultsByChave.get(field.chave);
    if (!def) return field;
    return {
      ...field,
      ...(field.fonte == null && def.fonte != null
        ? { fonte: def.fonte }
        : {}),
      ...(field.dependeDe == null && def.dependeDe != null
        ? { dependeDe: def.dependeDe }
        : {}),
    };
  });
}

/** Merge raso e seguro de um patch parcial sobre os defaults/atual. */
export function mergeCustomersConfig(
  current: Partial<CustomersConfig> | null | undefined,
  patch: Partial<CustomersConfig> = {},
): CustomersConfig {
  const base = { ...DEFAULT_CUSTOMERS_CONFIG, ...(current ?? {}) };
  return {
    usaSubjects: patch.usaSubjects ?? base.usaSubjects,
    documentRequired: patch.documentRequired ?? base.documentRequired,
    subjectLabel: { ...base.subjectLabel, ...(patch.subjectLabel ?? {}) },
    // Os defaults de fonte/dependeDe vêm da BASE (hoje: o pacote da vertical),
    // não mais de uma constante fixa. Assim um tenant com config antiga salva
    // recupera o autocomplete em runtime, sem migration de dados.
    subjectFields: withFieldSourceDefaults(
      patch.subjectFields ?? base.subjectFields,
      base.subjectFields,
    ),
  };
}
