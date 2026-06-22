import { SettingsService } from './settings.service';
import { UpdateAppearanceDto } from './dto/settings.dto';
import { COMPANY_SECTION } from './settings.section-registry';

const user = { userId: 'u1', tenantId: 't1', role: 'owner', jti: 'j' } as never;
const storage = { put: jest.fn(), remove: jest.fn(), url: jest.fn() } as never;

describe('SettingsService.getSettings', () => {
  it('core-only: returns sections with exactly [company] when no module sections registered', async () => {
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({})),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(tenancy.getCompanyView).toHaveBeenCalledWith('t1');
    expect(billing.getEnabledModules).toHaveBeenCalledWith('t1');
    expect(result.sections.map((s) => s.key)).toEqual(['company']);
    expect(result.sections[0]).toBe(COMPANY_SECTION);
  });

  it('module section appears only when its moduleKey is enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({})),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(result.sections.map((s) => s.key)).toContain('os-cfg');
  });

  it('getValues callback is invoked and its result is attached as values on the section', async () => {
    const mockValues = { usaSubjects: true, 'subjectLabel.singular': 'Veículo' };
    const customersSection = {
      key: 'clientes_veiculos',
      title: 'Clientes',
      moduleKey: 'customers',
      fields: [],
      getValues: jest.fn(async () => mockValues),
    };
    const registry = { moduleSections: jest.fn(() => [customersSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['customers']) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({})),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(customersSection.getValues).toHaveBeenCalledWith('t1');
    const sec = result.sections.find((s) => s.key === 'clientes_veiculos');
    expect(sec).toBeDefined();
    expect((sec as Record<string, unknown>).values).toEqual(mockValues);
    // getValues function must NOT be present in the returned section (not serializable)
    expect((sec as Record<string, unknown>).getValues).toBeUndefined();
  });

  it('getValues failure is swallowed and section gets empty values', async () => {
    const failingSection = {
      key: 'broken',
      title: 'Broken',
      moduleKey: 'os',
      fields: [],
      getValues: jest.fn(async () => { throw new Error('DB timeout'); }),
    };
    const registry = { moduleSections: jest.fn(() => [failingSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({})),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    const sec = result.sections.find((s) => s.key === 'broken');
    expect(sec).toBeDefined();
    expect((sec as Record<string, unknown>).values).toEqual({});
  });

  it('module section hidden when its moduleKey is NOT enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['customers']) };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({})),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    const keys = result.sections.map((s) => s.key);
    expect(keys).not.toContain('os-cfg');
    expect(keys).toEqual(['company']);
  });

  it('getSettings returns merged company: settings values win, column fallbacks fill missing keys', async () => {
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    // getCompanyView returns merge of fallbacks + saved settings
    const mergedView = { companyName: 'Nome Fantasia', legalName: 'Razão Social Ltda', taxId: '12.345.678/0001-99' };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => mergedView),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(tenancy.getCompanyView).toHaveBeenCalledWith('t1');
    // company on getSettings is the merged view (column fallbacks visible)
    expect(result.company).toEqual(mergedView);
    expect(result.company.companyName).toBe('Nome Fantasia');
    expect(result.company.taxId).toBe('12.345.678/0001-99');
  });

  it('getSettings: saved settings value wins over column fallback', async () => {
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    // Simulates: registration stored trade_name='Reg Name', but settings has companyName='Edited Name'
    // getCompanyView should return the settings value (wins over fallback)
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({})),
      getCompanyView: jest.fn(async () => ({ companyName: 'Edited Name', taxId: '00.000.000/0001-00' })),
    };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const result = await svc.getSettings(user);

    expect(result.company.companyName).toBe('Edited Name');
  });
});

describe('SettingsService.updateCompany', () => {
  it('merges with current settings, persists, syncs identity, audits, and returns company view', async () => {
    const updateCompanySettings = jest.fn(async () => undefined);
    const syncCompanyIdentity = jest.fn(async () => undefined);
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    const viewResult = { companyName: 'new', taxId: '123', legalName: 'Razão Social Ltda' };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'old', taxId: '123' })),
      getCompanyView: jest.fn(async () => viewResult),
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
    // Retorna a view mesclada (com fallbacks das colunas), não o JSONB puro.
    expect(tenancy.getCompanyView).toHaveBeenCalledWith('t1');
    expect(result).toEqual({ company: viewResult });
    expect(result.company.companyName).toBe('new');
    expect(result.company.legalName).toBe('Razão Social Ltda');
  });

  it('updateAppearance: persiste apenas campos de aparência, audita e retorna company view', async () => {
    const updateCompanySettings = jest.fn(async () => undefined);
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    const viewResult = { companyName: 'Empresa', themePreset: 'roxo' };
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'Empresa', themePreset: 'tangerina' })),
      getCompanyView: jest.fn(async () => viewResult),
      updateCompanySettings,
      syncCompanyIdentity: jest.fn(),
    };
    const log = jest.fn(async () => undefined);
    const audit = { log } as never;

    const svc = new SettingsService(registry as never, billing as never, tenancy as never, audit, storage);
    const dto: UpdateAppearanceDto = { themePreset: 'roxo' };
    const result = await svc.updateAppearance(user, dto);

    expect(updateCompanySettings).toHaveBeenCalledWith('t1', expect.objectContaining({ themePreset: 'roxo', companyName: 'Empresa' }));
    expect(log).toHaveBeenCalledWith('t1', 'u1', 'settings_change', 'appearance');
    expect(result).toEqual({ company: viewResult });
  });

  it('faz merge, persiste, sincroniza identidade e audita', async () => {
    const viewResult2 = { companyName: 'Novo', legalName: 'Novo ME', taxId: '123' };
    const tenancy2 = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'Velho' })),
      getCompanyView: jest.fn(async () => viewResult2),
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
    // Retorna a view (merge de colunas + JSONB), que inclui companyName.
    expect(tenancy2.getCompanyView).toHaveBeenCalledWith('t1');
    expect(res.company.companyName).toBe('Novo');
  });
});
