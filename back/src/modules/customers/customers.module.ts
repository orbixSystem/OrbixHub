import { forwardRef, Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { OsSubjectHistoryProvider } from '../os/os-subject-history.provider';
import { SaleModule } from '../sale/sale.module';
import { SaleSubjectHistoryProvider } from '../sale/sale-subject-history.provider';
import { CompositeSubjectHistoryProvider } from './composite-subject-history.provider';
import { SettingsModule } from '../settings/settings.module';
import { TenancyModule } from '../tenancy/tenancy.module';
import { CustomersController } from './customers.controller';
import { SubjectsController } from './subjects.controller';
import { CustomersService } from './customers.service';
import { CustomersMetricsService } from './customers-metrics.service';
import { CustomersRepository } from './customers.repository';
import { SubjectHistoryProvider } from './subject-history.provider';
import { SubjectLookupService } from './subject-lookup.service';
import { SubjectLookupRegistry } from './subject-lookup.registry';

/**
 * Módulo Clientes & Objetos — cadastros-base, GENÉRICO de verdade.
 *
 * Não há mais nada de veículo aqui: o cliente FIPE, a consulta de placa e as
 * fontes de autocomplete da cascata moraram neste módulo até 17/08/2026 e agora
 * vivem em `src/verticals/veiculos/`, que se registra nos pontos de extensão
 * daqui (`SubjectLookupRegistry`). A seta aponta numa direção só: a vertical
 * importa este módulo, este módulo não sabe que ela existe.
 *
 * Importa TenancyModule para perguntar o nicho do tenant (`tenant.vertical`) —
 * a tabela é da Tenancy, então se pergunta a ela em vez de ler a coluna.
 */
@Module({
  imports: [
    BillingModule,
    SettingsModule,
    TenancyModule,
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
    SubjectLookupRegistry,
  ],
  // SubjectLookupRegistry é exportado para a vertical registrar as fontes dela.
  exports: [CustomersService, CustomersMetricsService, SubjectLookupRegistry],
})
export class CustomersModule {}
