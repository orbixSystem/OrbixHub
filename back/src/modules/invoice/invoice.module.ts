import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { OsModule } from '../os/os.module';
import { SaleModule } from '../sale/sale.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { TenancyModule } from '../tenancy/tenancy.module';
import { InvoiceController } from './invoice.controller';
import { InvoiceWebhookController } from './invoice-webhook.controller';
import { InvoiceService } from './invoice.service';
import { InvoiceRepository } from './invoice.repository';
import { INVOICE_CONFIG_KEY } from './invoice.config';
import { FISCAL_GATEWAY } from './fiscal/fiscal-gateway';
import { NoopFiscalGateway } from './fiscal/noop-fiscal-gateway';
import { NuvemFiscalClient } from './fiscal/nuvemfiscal-client';

/**
 * Módulo Nota Fiscal — emissão a partir da OS (ONLINE-ONLY) via gateway fiscal
 * abstrato (Noop em dev; GovBrNfseGateway real futuro). Contratável
 * (@RequiresModule('invoice')). Importa BillingModule (ModuleAccessGuard),
 * OsModule e CustomersModule (services públicos — "aponta, não invade") e
 * SettingsModule (registra a própria seção de config no host). TenancyModule
 * dá acesso à identidade fiscal do núcleo (CNPJ, endereço, ...) via
 * TenancyService.getCompanyView — sem tocar a tabela `tenant` diretamente.
 */
@Module({
  imports: [
    BillingModule,
    OsModule,
    SaleModule,
    CustomersModule,
    SettingsModule,
    TenancyModule,
  ],
  controllers: [InvoiceController, InvoiceWebhookController],
  providers: [
    InvoiceService,
    InvoiceRepository,
    NuvemFiscalClient,
    { provide: FISCAL_GATEWAY, useClass: NoopFiscalGateway },
  ],
  exports: [InvoiceService],
})
export class InvoiceModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings só se o módulo `invoice` estiver habilitado.
    // Credenciais sensíveis (certificado A1, CSC, série, ambiente) serão geridas
    // por endpoints próprios do módulo (tenant_module.settings['invoice']).
    this.registry.register({
      key: INVOICE_CONFIG_KEY,
      title: 'Nota Fiscal',
      moduleKey: 'invoice',
      fields: [],
    });
  }
}
