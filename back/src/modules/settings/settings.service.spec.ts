import { SettingsService } from './settings.service';
import { COMPANY_SECTION } from './settings.section-registry';

const user = { userId: 'u1', tenantId: 't1', role: 'owner', jti: 'j' } as never;

describe('SettingsService.getSettings', () => {
  it('core-only: returns sections with exactly [company] when no module sections registered', async () => {
    const repo = {
      getCompany: jest.fn(async () => ({})),
    };
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(repo as never, registry as never, billing as never, audit);
    const result = await svc.getSettings(user);

    expect(billing.getEnabledModules).toHaveBeenCalledWith('t1');
    expect(result.sections.map((s) => s.key)).toEqual(['company']);
    expect(result.sections[0]).toBe(COMPANY_SECTION);
  });

  it('module section appears only when its moduleKey is enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const repo = {
      getCompany: jest.fn(async () => ({})),
    };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['os']) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(repo as never, registry as never, billing as never, audit);
    const result = await svc.getSettings(user);

    expect(result.sections.map((s) => s.key)).toContain('os-cfg');
  });

  it('module section hidden when its moduleKey is NOT enabled', async () => {
    const osSection = { key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] };
    const repo = {
      getCompany: jest.fn(async () => ({})),
    };
    const registry = { moduleSections: jest.fn(() => [osSection]) };
    const billing = { getEnabledModules: jest.fn(async () => ['customers']) };
    const audit = { log: jest.fn() } as never;

    const svc = new SettingsService(repo as never, registry as never, billing as never, audit);
    const result = await svc.getSettings(user);

    const keys = result.sections.map((s) => s.key);
    expect(keys).not.toContain('os-cfg');
    expect(keys).toEqual(['company']);
  });
});

describe('SettingsService.updateCompany', () => {
  it('merges with current settings, persists, audits, and returns merged company', async () => {
    const updateCompany = jest.fn(async () => undefined);
    const repo = {
      getCompany: jest.fn(async () => ({ companyName: 'old', taxId: '123' })),
      updateCompany,
    };
    const registry = { moduleSections: jest.fn(() => []) };
    const billing = { getEnabledModules: jest.fn(async () => []) };
    const log = jest.fn(async () => undefined);
    const audit = { log } as never;

    const svc = new SettingsService(repo as never, registry as never, billing as never, audit);
    const result = await svc.updateCompany(user, { companyName: 'new' });

    expect(updateCompany).toHaveBeenCalledWith('t1', {
      companyName: 'new',
      taxId: '123',
    });
    expect(log).toHaveBeenCalledWith('t1', 'u1', 'settings_change', 'company');
    expect(result).toEqual({ company: { companyName: 'new', taxId: '123' } });
  });
});
