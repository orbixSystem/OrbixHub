import { Logger, Module, OnModuleInit } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { OrderLockRegistry } from '../os/order-lock.registry';
import { OsModule } from '../os/os.module';
import { SaleModule } from '../sale/sale.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { TenancyModule } from '../tenancy/tenancy.module';
import { InvoiceController } from './invoice.controller';
import { InvoiceWebhookController } from './invoice-webhook.controller';
import { InvoiceService } from './invoice.service';
import { InvoiceOrderLock } from './invoice-order-lock';
import { InvoiceRepository } from './invoice.repository';
import { INVOICE_CONFIG_KEY } from './invoice.config';
import { FISCAL_GATEWAY, FiscalGateway } from './fiscal/fiscal-gateway';
import { NoopFiscalGateway } from './fiscal/noop-fiscal-gateway';
import { NuvemFiscalClient } from './fiscal/nuvemfiscal-client';
import { GovBrNfseGateway } from './fiscal/govbr/govbr-nfse-gateway';
import { NfseHttp } from './fiscal/govbr/nfse-http';
import { InvoiceCertificateService } from './invoice-certificate.service';

/**
 * Escolhe o gateway pelo FISCAL_PROVIDER. `govbr` = emissão direta na NFS-e
 * Nacional (gratuita) e exige o cofre de certificados configurado — sem a chave
 * o servidor nem sobe, em vez de falhar só na primeira nota.
 * `nuvemfiscal` ainda não tem emissão implementada (só cadastro) → Noop.
 */
function fiscalGatewayFactory(env: Env, noop: NoopFiscalGateway, govbr: GovBrNfseGateway): FiscalGateway {
  if (env.FISCAL_PROVIDER === 'govbr') {
    if (!env.FISCAL_CERT_KEY) {
      throw new Error('FISCAL_PROVIDER=govbr exige FISCAL_CERT_KEY (32 bytes em base64).');
    }
    return govbr;
  }
  if (env.FISCAL_PROVIDER !== 'noop') {
    new Logger('InvoiceModule').warn(`FISCAL_PROVIDER=${env.FISCAL_PROVIDER} sem emissão implementada — usando Noop.`);
  }
  return noop;
}

/**
 * Módulo Nota Fiscal — emissão a partir da OS (ONLINE-ONLY) via gateway fiscal
 * abstrato (Noop em dev; GovBrNfseGateway = NFS-e Nacional direto no gov.br). Contratável
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
    InvoiceOrderLock,
    NuvemFiscalClient,
    InvoiceCertificateService,
    NfseHttp,
    NoopFiscalGateway,
    GovBrNfseGateway,
    {
      provide: FISCAL_GATEWAY,
      inject: [ENV, NoopFiscalGateway, GovBrNfseGateway],
      useFactory: fiscalGatewayFactory,
    },
  ],
  exports: [InvoiceService],
})
export class InvoiceModule implements OnModuleInit {
  constructor(
    private readonly registry: SettingsSectionRegistry,
    private readonly orderLocks: OrderLockRegistry,
    private readonly orderLock: InvoiceOrderLock,
  ) {}

  onModuleInit(): void {
    // OS com nota ativa não pode ser reaberta nem excluída — quem sabe disso é
    // o Fiscal, então é ele quem registra o impedimento na OS.
    this.orderLocks.registrar(this.orderLock);
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
