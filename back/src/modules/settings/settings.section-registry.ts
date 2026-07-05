import { Injectable } from '@nestjs/common';

export type SettingsFieldType =
  | 'text' | 'email' | 'tel' | 'url' | 'color' | 'bool' | 'select' | 'image';

export interface SettingsFieldOption { value: string; label: string }

export interface SettingsFieldSchema {
  key: string;
  label: string;
  type: SettingsFieldType;
  options?: SettingsFieldOption[]; // só para type 'select'
  group?: string;                  // subtítulo p/ agrupar na UI (ex.: 'Fiscal')
}

export interface SettingsSection {
  key: string;
  title: string;
  moduleKey: string | null; // null = núcleo; senão aparece só se o módulo estiver habilitado
  fields: SettingsFieldSchema[];
  /**
   * Callback opcional invocado pelo SettingsService ao montar GET /settings.
   * Retorna um mapa plano dos valores efetivos da seção (defaults ∪ salvos).
   * NÃO é serializado na resposta HTTP — o service extrai o resultado e o anexa
   * como `values` na seção. Módulos declaram aqui sem depender do schema de outro.
   */
  getValues?: (tenantId: string) => Promise<Record<string, unknown>>;
}

@Injectable()
export class SettingsSectionRegistry {
  private readonly sections = new Map<string, SettingsSection>();
  register(section: SettingsSection): void {
    this.sections.set(section.key, section);
  }
  moduleSections(): SettingsSection[] {
    return [...this.sections.values()].filter((s) => s.moduleKey !== null);
  }
}

const UFS = [
  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB',
  'PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO',
].map((u) => ({ value: u, label: u }));

const REGIMES: SettingsFieldOption[] = [
  { value: 'simples', label: 'Simples Nacional' },
  { value: 'mei', label: 'MEI' },
  { value: 'presumido', label: 'Lucro Presumido' },
  { value: 'real', label: 'Lucro Real' },
];

// Presets de tema (a UI mapeia value->cor-semente; o back só guarda a escolha).
export const THEME_PRESETS: SettingsFieldOption[] = [
  { value: 'roxo', label: 'Roxo (padrão)' },
  { value: 'azul', label: 'Azul' },
  { value: 'petroleo', label: 'Petróleo' },
  { value: 'verde', label: 'Verde' },
  { value: 'tangerina', label: 'Tangerina' },
  { value: 'rosa', label: 'Rosa' },
  { value: 'vermelho', label: 'Vermelho' },
  { value: 'ardosia', label: 'Ardósia' },
];

export const COMPANY_SECTION: SettingsSection = {
  key: 'company',
  title: 'Empresa & Identidade visual',
  moduleKey: null,
  fields: [
    // Identidade
    { key: 'companyName', label: 'Nome fantasia', type: 'text', group: 'Identidade' },
    { key: 'legalName', label: 'Razão social', type: 'text', group: 'Identidade' },
    { key: 'taxId', label: 'CNPJ / documento', type: 'text', group: 'Identidade' },
    { key: 'phone', label: 'Telefone / WhatsApp', type: 'tel', group: 'Identidade' },
    { key: 'email', label: 'E-mail', type: 'email', group: 'Identidade' },
    { key: 'website', label: 'Site', type: 'url', group: 'Identidade' },
    { key: 'logoUrl', label: 'Logo', type: 'image', group: 'Identidade' },
    // Fiscal (para o módulo de Nota Fiscal)
    { key: 'inscricaoEstadual', label: 'Inscrição Estadual', type: 'text', group: 'Fiscal' },
    { key: 'inscricaoMunicipal', label: 'Inscrição Municipal', type: 'text', group: 'Fiscal' },
    { key: 'regimeTributario', label: 'Regime tributário', type: 'select', options: REGIMES, group: 'Fiscal' },
    { key: 'cnae', label: 'CNAE principal', type: 'text', group: 'Fiscal' },
    // Endereço fiscal estruturado (NF-e exige)
    { key: 'cep', label: 'CEP', type: 'text', group: 'Endereço' },
    { key: 'logradouro', label: 'Logradouro', type: 'text', group: 'Endereço' },
    { key: 'numero', label: 'Número', type: 'text', group: 'Endereço' },
    { key: 'complemento', label: 'Complemento', type: 'text', group: 'Endereço' },
    { key: 'bairro', label: 'Bairro', type: 'text', group: 'Endereço' },
    { key: 'municipio', label: 'Município', type: 'text', group: 'Endereço' },
    { key: 'uf', label: 'UF', type: 'select', options: UFS, group: 'Endereço' },
    // Aparência
    { key: 'themePreset', label: 'Tema do sistema', type: 'select', options: THEME_PRESETS, group: 'Aparência' },
    { key: 'primaryColor', label: 'Cor primária', type: 'color', group: 'Aparência' },
    { key: 'secondaryColor', label: 'Cor secundária', type: 'color', group: 'Aparência' },
  ],
};
