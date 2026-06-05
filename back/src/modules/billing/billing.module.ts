import { Module } from '@nestjs/common';
import { BillingService } from './billing.service';
import { BillingRepository } from './billing.repository';
import { BillingController } from './billing.controller';
import { ModuleAccessGuard } from './module-access.guard';
import { TrialExpiryJob } from './trial-expiry.job';
import { PAYMENT_GATEWAY } from './payment/payment-gateway';
import { NoopPaymentGateway } from './payment/noop-payment-gateway';

@Module({
  controllers: [BillingController],
  providers: [
    BillingService,
    BillingRepository,
    ModuleAccessGuard,
    TrialExpiryJob,
    { provide: PAYMENT_GATEWAY, useClass: NoopPaymentGateway },
  ],
  exports: [BillingService, ModuleAccessGuard],
})
export class BillingModule {}
