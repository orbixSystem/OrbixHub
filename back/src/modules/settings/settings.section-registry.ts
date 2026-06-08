import { Injectable } from '@nestjs/common';

export type SettingsFieldType = 'text' | 'color' | 'url';
export interface SettingsFieldSchema {
  key: string;
  label: string;
  type: SettingsFieldType;
}
export interface SettingsSection {
  key: string;
  title: string;
  moduleKey: string | null; // null = core section; otherwise shown only if that module is enabled
  fields: SettingsFieldSchema[];
}

/**
 * Incremental-host mechanism: each product module REGISTERS its own config
 * section here (at boot). The host (SettingsService) builds GET /settings from
 * the core section + registered sections whose moduleKey is enabled in
 * tenant_module. Documented in docs/configuracao.md. A new module just registers
 * its section — the host is never edited.
 */
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

export const COMPANY_SECTION: SettingsSection = {
  key: 'company',
  title: 'Empresa & Identidade visual',
  moduleKey: null,
  fields: [
    { key: 'companyName', label: 'Nome fantasia', type: 'text' },
    { key: 'legalName', label: 'Razão social', type: 'text' },
    { key: 'taxId', label: 'CNPJ / documento', type: 'text' },
    { key: 'address', label: 'Endereço', type: 'text' },
    { key: 'phone', label: 'Telefone / WhatsApp', type: 'text' },
    { key: 'email', label: 'E-mail', type: 'text' },
    { key: 'logoUrl', label: 'Logo (URL)', type: 'url' },
    { key: 'primaryColor', label: 'Cor primária', type: 'color' },
    { key: 'secondaryColor', label: 'Cor secundária', type: 'color' },
  ],
};
