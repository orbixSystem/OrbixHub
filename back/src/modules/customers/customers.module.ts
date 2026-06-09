import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { CustomersController } from './customers.controller';
import { SubjectsController } from './subjects.controller';
import { CustomersService } from './customers.service';
import { CustomersRepository } from './customers.repository';
import {
  EmptySubjectHistoryProvider,
  SubjectHistoryProvider,
} from './subject-history.provider';
import { CUSTOMERS_CONFIG_KEY } from './customers.config';
import { SubjectLookupService } from './subject-lookup.service';
import { FIPE_CLIENT, HttpFipeClient } from './fipe.client';

/**
 * Módulo Clientes & Veículos — núcleo de cadastros-base (genérico/multi-vertical).
 * Importa BillingModule (config em `tenant_module.settings` + ModuleAccessGuard)
 * e SettingsModule (registra a própria seção de config no host).
 */
@Module({
  imports: [BillingModule, SettingsModule],
  controllers: [CustomersController, SubjectsController],
  providers: [
    CustomersService,
    CustomersRepository,
    { provide: SubjectHistoryProvider, useClass: EmptySubjectHistoryProvider },
    SubjectLookupService,
    { provide: FIPE_CLIENT, useFactory: () => new HttpFipeClient() },
  ],
  exports: [CustomersService],
})
export class CustomersModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings apenas se o módulo `customers` estiver
    // habilitado no tenant. Campos ricos (subjectFields) são geridos pelos
    // endpoints próprios do módulo (GET/PATCH /customers/config).
    this.registry.register({
      key: CUSTOMERS_CONFIG_KEY,
      title: 'Clientes & Veículos',
      moduleKey: 'customers',
      fields: [
        { key: 'usaSubjects', label: 'Usa "veículos"?', type: 'bool' },
        { key: 'subjectLabel.singular', label: 'Rótulo (singular)', type: 'text' },
        { key: 'subjectLabel.plural', label: 'Rótulo (plural)', type: 'text' },
        { key: 'documentRequired', label: 'Documento obrigatório?', type: 'bool' },
      ],
    });
  }
}
