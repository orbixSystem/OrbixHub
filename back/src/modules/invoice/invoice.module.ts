import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { OsModule } from '../os/os.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { InvoiceController } from './invoice.controller';
import { InvoiceWebhookController } from './invoice-webhook.controller';
import { InvoiceService } from './invoice.service';
import { InvoiceRepository } from './invoice.repository';
import { INVOICE_CONFIG_KEY } from './invoice.config';
import { FISCAL_GATEWAY } from './fiscal/fiscal-gateway';
import { NoopFiscalGateway } from './fiscal/noop-fiscal-gateway';

/**
 * Módulo Nota Fiscal — emissão a partir da OS (ONLINE-ONLY) via gateway fiscal
 * abstrato (Noop em dev; GovBrNfseGateway real futuro). Contratável
 * (@RequiresModule('invoice')). Importa BillingModule (ModuleAccessGuard),
 * OsModule e CustomersModule (services públicos — "aponta, não invade") e
 * SettingsModule (registra a própria seção de config no host).
 */
@Module({
  imports: [BillingModule, OsModule, CustomersModule, SettingsModule],
  controllers: [InvoiceController, InvoiceWebhookController],
  providers: [
    InvoiceService,
    InvoiceRepository,
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
