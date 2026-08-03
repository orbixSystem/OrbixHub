import { forwardRef, Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { OsSubjectHistoryProvider } from '../os/os-subject-history.provider';
import { SaleModule } from '../sale/sale.module';
import { SaleSubjectHistoryProvider } from '../sale/sale-subject-history.provider';
import { CompositeSubjectHistoryProvider } from './composite-subject-history.provider';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { CustomersController } from './customers.controller';
import { SubjectsController } from './subjects.controller';
import { CustomersService } from './customers.service';
import { CustomersMetricsService } from './customers-metrics.service';
import { CustomersRepository } from './customers.repository';
import { SubjectHistoryProvider } from './subject-history.provider';
import { CUSTOMERS_CONFIG_KEY } from './customers.config';
import { SubjectLookupService } from './subject-lookup.service';
import { FIPE_CLIENT, HttpFipeClient } from './fipe.client';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { NoopPlateProvider, PLATE_PROVIDER } from './plates/plate.provider';
import { WdapiPlateProvider } from './plates/wdapi-plate.provider';
import { PlateCacheStore } from './plates/plate-cache.store';
import { PlateQuotaStore } from './plates/plate-quota.store';
import { PlateLookupService } from './plates/plate-lookup.service';
import { PlateFipeMatcher } from './plates/plate-fipe-matcher.service';

/**
 * Módulo Clientes & Veículos — núcleo de cadastros-base (genérico/multi-vertical).
 * Importa BillingModule (config em `tenant_module.settings` + ModuleAccessGuard)
 * e SettingsModule (registra a própria seção de config no host).
 */
@Module({
  imports: [
    BillingModule,
    SettingsModule,
    forwardRef(() => OsModule),
    forwardRef(() => SaleModule),
  ],
  controllers: [CustomersController, SubjectsController],
  providers: [
    CustomersService,
    CustomersMetricsService,
    CustomersRepository,
    // Histórico do cliente = OS ∪ vendas de balcão. Cada módulo dono implementa
    // sua fonte e o compositor as une em ordem cronológica — `customers` nunca
    // toca as tabelas deles. forwardRef p/ as dependências mútuas
    // (OsModule/SaleModule ↔ CustomersModule).
    {
      provide: SubjectHistoryProvider,
      useFactory: (
        os: OsSubjectHistoryProvider,
        vendas: SaleSubjectHistoryProvider,
      ) => new CompositeSubjectHistoryProvider([os, vendas]),
      inject: [OsSubjectHistoryProvider, SaleSubjectHistoryProvider],
    },
    SubjectLookupService,
    { provide: FIPE_CLIENT, useFactory: () => new HttpFipeClient() },
    // Consulta de placa (API Placas): cache global + cota mensal + provider real
    // só quando habilitado por env (senão Noop — nunca chama fora).
    PlateCacheStore,
    PlateQuotaStore,
    PlateFipeMatcher,
    PlateLookupService,
    {
      provide: PLATE_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env) =>
        env.PLACAS_ENABLED && env.PLACAS_TOKEN
          ? new WdapiPlateProvider(env)
          : new NoopPlateProvider(),
    },
  ],
  exports: [CustomersService, CustomersMetricsService],
})
export class CustomersModule implements OnModuleInit {
  constructor(
    private readonly registry: SettingsSectionRegistry,
    private readonly customersService: CustomersService,
  ) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings apenas se o módulo `customers` estiver
    // habilitado no tenant. Campos ricos (subjectFields) são geridos pelos
    // endpoints próprios do módulo (GET/PATCH /customers/config).
    //
    // getValues: retorna o mapa plano dos valores efetivos (DEFAULT ∪ salvo).
    // O service.getConfig já aplica mergeCustomersConfig com os defaults.
    // Achatamos subjectLabel.{singular,plural} para bater com as chaves dos fields.
    const svc = this.customersService;
    this.registry.register({
      key: CUSTOMERS_CONFIG_KEY,
      title: 'Clientes',
      moduleKey: 'customers',
      fields: [
        { key: 'usaSubjects', label: 'Usa "veículos"?', type: 'bool' },
        { key: 'subjectLabel.singular', label: 'Rótulo (singular)', type: 'text' },
        { key: 'subjectLabel.plural', label: 'Rótulo (plural)', type: 'text' },
        { key: 'documentRequired', label: 'Documento obrigatório?', type: 'bool' },
      ],
      getValues: async (tenantId: string): Promise<Record<string, unknown>> => {
        const cfg = await svc.getConfig(tenantId);
        return {
          usaSubjects: cfg.usaSubjects,
          'subjectLabel.singular': cfg.subjectLabel.singular,
          'subjectLabel.plural': cfg.subjectLabel.plural,
          documentRequired: cfg.documentRequired,
        };
      },
    });
  }
}
