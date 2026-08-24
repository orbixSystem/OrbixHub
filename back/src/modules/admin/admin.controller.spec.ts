import { AdminController } from './admin.controller';
import type { AdminService } from './admin.service';
import type { TenantSettingsService } from '../../verticals/tenant-settings.service';
import type { SupportService } from '../support/support.service';
import type { CnpjLookupService } from '../auth/cnpj-lookup.service';
import type { SupportSessionService } from '../auth/support-session.service';
import type { BillingService } from '../billing/billing.service';

const TENANT = '0c615fb2-ce7c-45e6-b6ee-59c3010e4133';

function montar() {
  const admin = {} as AdminService;
  const settings = {
    listar: jest.fn(async () => ({ vertical: 'equipamentos', modules: [] })),
    alternarModulo: jest.fn(async () => ({ vertical: null, modules: [] })),
    alternarFeature: jest.fn(async () => ({ vertical: null, modules: [] })),
  } as unknown as TenantSettingsService;
  const support = {
    ticketsDoTenant: jest.fn(async () => []),
    mensagensParaOrbix: jest.fn(async () => []),
    responderComoOrbix: jest.fn(async () => ({}) as never),
    resolverComoOrbix: jest.fn(async () => undefined),
    reabrirComoOrbix: jest.fn(async () => undefined),
  } as unknown as SupportService;

  const cnpj = { lookup: jest.fn(async () => ({}) as never) } as unknown as CnpjLookupService;
  const billing = {
    assinaturaDoTenant: jest.fn(async () => null),
  } as unknown as BillingService;
  const sessao = {
    criarLink: jest.fn(async () => ({}) as never),
  } as unknown as SupportSessionService;

  return {
    ctrl: new AdminController(admin, settings, support, cnpj, billing, sessao),
    settings,
    support,
    sessao,
  };
}

describe('AdminController', () => {
  // Regressão: o controller passava o `tenantId` como ator da auditoria.
  // `audit_log.actor_user_id` referencia `users`, então a FK estourava DEPOIS
  // do módulo já ter sido gravado — o toggle mudava o ambiente do cliente e
  // devolvia 500, deixando tela e banco discordando.
  it('mudança de módulo vai com ator NULO, não com o id do tenant', async () => {
    const { ctrl, settings } = montar();
    await ctrl.alternarModulo(TENANT, { key: 'expenses', enabled: false });
    expect(settings.alternarModulo).toHaveBeenCalledWith(TENANT, null, 'expenses', false);
  });

  it('mudança de funcionalidade também vai com ator nulo', async () => {
    const { ctrl, settings } = montar();
    await ctrl.alternarFeature(TENANT, { key: 'os.trackingLink', enabled: true });
    expect(settings.alternarFeature).toHaveBeenCalledWith(
      TENANT,
      null,
      'os.trackingLink',
      true,
    );
  });

  it('resposta de suporte leva o nome de quem atendeu', async () => {
    const { ctrl, support } = montar();
    await ctrl.responder(TENANT, 'tk1', { body: 'já vimos', autor: 'Ana' });
    expect(support.responderComoOrbix).toHaveBeenCalledWith(
      TENANT,
      'tk1',
      'já vimos',
      'Ana',
    );
  });

  it('reabrir devolve a lista atualizada', async () => {
    const { ctrl, support } = montar();
    await ctrl.reabrir(TENANT, 'tk1');
    expect(support.reabrirComoOrbix).toHaveBeenCalledWith(TENANT, 'tk1');
    expect(support.ticketsDoTenant).toHaveBeenCalledWith(TENANT);
  });

  it('o link de suporte registra QUEM pediu', async () => {
    const { ctrl, sessao } = montar();
    await ctrl.sessaoDeSuporte(TENANT, { por: 'Ana' });
    expect(sessao.criarLink).toHaveBeenCalledWith(TENANT, 'Ana');
  });

  it('resolver devolve a lista atualizada, não vazio', async () => {
    const { ctrl, support } = montar();
    await ctrl.resolver(TENANT, 'tk1');
    expect(support.resolverComoOrbix).toHaveBeenCalledWith(TENANT, 'tk1');
    expect(support.ticketsDoTenant).toHaveBeenCalledWith(TENANT);
  });
});
