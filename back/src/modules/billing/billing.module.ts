import { forwardRef, Module } from '@nestjs/common';
import { BillingService } from './billing.service';
import { BillingRepository } from './billing.repository';
import { BillingController } from './billing.controller';
import { ModuleAccessGuard } from './module-access.guard';
import { TrialExpiryJob } from './trial-expiry.job';
import { PAYMENT_GATEWAY } from './payment/payment-gateway';
import { NoopPaymentGateway } from './payment/noop-payment-gateway';
import { CobrancaMailService } from './cobranca-mail.service';
import { IamModule } from '../iam/iam.module';

@Module({
  // `forwardRef` porque a dependência é mútua: o Auth importa o Billing (para
  // provisionar o trial no registro) e o Iam importa o Auth — então o Billing
  // pedir o Iam fecha o ciclo. Mesmo padrão já usado entre customers/os/sale.
  // O Billing precisa do Iam para saber PARA QUEM mandar a cobrança: o dono
  // mora em `membership`, e ler essa tabela por fora seria invadir o Iam.
  imports: [forwardRef(() => IamModule)],
  controllers: [BillingController],
  providers: [
    BillingService,
    BillingRepository,
    ModuleAccessGuard,
    TrialExpiryJob,
    CobrancaMailService,
    { provide: PAYMENT_GATEWAY, useClass: NoopPaymentGateway },
  ],
  exports: [BillingService, ModuleAccessGuard],
})
export class BillingModule {}
