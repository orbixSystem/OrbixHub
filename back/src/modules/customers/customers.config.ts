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

/** Defaults do vertical oficina (genéricos por design — trocáveis por config). */
export const DEFAULT_CUSTOMERS_CONFIG: CustomersConfig = {
  usaSubjects: true,
  subjectLabel: { singular: 'Veículo', plural: 'Veículos' },
  subjectFields: [
    { chave: 'identifier', rotulo: 'Placa', tipo: 'text', obrigatorio: true },
    { chave: 'marca', rotulo: 'Marca', tipo: 'text', obrigatorio: false, fonte: 'fipe.marcas' },
    { chave: 'modelo', rotulo: 'Modelo', tipo: 'text', obrigatorio: false, fonte: 'fipe.modelos', dependeDe: 'marca' },
    { chave: 'ano', rotulo: 'Ano', tipo: 'number', obrigatorio: false },
    { chave: 'cor', rotulo: 'Cor', tipo: 'text', obrigatorio: false },
    { chave: 'km', rotulo: 'KM', tipo: 'number', obrigatorio: false },
  ],
  documentRequired: false,
};

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
    subjectFields: patch.subjectFields ?? base.subjectFields,
  };
}
