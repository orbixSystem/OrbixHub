import { SettingsService } from './settings.service';
import { COMPANY_SECTION } from './settings.section-registry';

const user = { userId: 'u1', tenantId: 't1', role: 'owner', jti: 'j' } as never;
const storage = { put: jest.fn(), delete: jest.fn(), url: jest.fn() } as never;

describe('SettingsService.getSettings', () => {
  it('core-only: returns sections with exactly [company] when no module sections registered', async () => {
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const tenancy = { getCompanySettings: jest.fn(async () => ({})) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(tenancy.getCompanySettings).toHaveBeenCalledWith('t1');
    expect(billing.getEnabledModules).toHaveBeenCalledWith('t1');
    expect(result.sections.map((s) => s.key)).toEqual(['company']);
    expect(result.sections[0]).toBe(COMPANY_SECTION);
  });

  it('module section appears only when its moduleKey is enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const tenancy = { getCompanySettings: jest.fn(async () => ({})) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(result.sections.map((s) => s.key)).toContain('os-cfg');
  });

  it('module section hidden when its moduleKey is NOT enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['customers']) };
    const tenancy = { getCompanySettings: jest.fn(async () => ({})) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    const keys = result.sections.map((s) => s.key);
    expect(keys).not.toContain('os-cfg');
    expect(keys).toEqual(['company']);
  });
});

describe('SettingsService.updateCompany', () => {
  it('merges with current settings, persists, syncs identity, audits, and returns merged company', async () => {
    const updateCompanySettings = jest.fn(async () => undefined);
    const syncCompanyIdentity = jest.fn(async () => undefined);
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'old', taxId: '123' })),
      updateCompanySettings,
      syncCompanyIdentity,
    };
    const log = jest.fn(async () => undefined);
    const audit = { log } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.updateCompany(user, { companyName: 'new' });

    expect(updateCompanySettings).toHaveBeenCalledWith('t1', {
      companyName: 'new',
      taxId: '123',
    });
    expect(syncCompanyIdentity).toHaveBeenCalledWith('t1', { tradeName: 'new', legalName: undefined, cnpj: undefined });
    expect(log).toHaveBeenCalledWith('t1', 'u1', 'settings_change', 'company');
    expect(result).toEqual({ company: { companyName: 'new', taxId: '123' } });
  });

  it('faz merge, persiste, sincroniza identidade e audita', async () => {
    const tenancy2 = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'Velho' })),
      updateCompanySettings: jest.fn(async () => undefined),
      syncCompanyIdentity: jest.fn(async () => undefined),
    };
    const audit2 = { log: jest.fn(async () => undefined) };
    const billing2 = { getEnabledModules: jest.fn(async () => []) };
    const registry2 = { moduleSections: () => [] };
    const svc = new SettingsService(registry2 as never, billing2 as never, tenancy2 as never, audit2 as never, storage);
    const u = { tenantId: 't1', userId: 'u1' } as never;

    const res = await svc.updateCompany(u, { companyName: 'Novo', legalName: 'Novo ME', taxId: '123' } as never);

    expect(tenancy2.updateCompanySettings).toHaveBeenCalledWith('t1', expect.objectContaining({ companyName: 'Novo' }));
    expect(tenancy2.syncCompanyIdentity).toHaveBeenCalledWith('t1', { tradeName: 'Novo', legalName: 'Novo ME', cnpj: '123' });
    expect(audit2.log).toHaveBeenCalledWith('t1', 'u1', 'settings_change', 'company');
    expect(res.company.companyName).toBe('Novo');
  });
});
