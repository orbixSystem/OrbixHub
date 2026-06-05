import { createHmac, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import {
  CheckoutResult,
  CreateCheckoutParams,
  PaymentGateway,
} from './payment-gateway';

/**
 * Validation-phase gateway. No external HTTP. Webhooks are authenticated with
 * an HMAC-SHA256 of the raw body keyed by BILLING_WEBHOOK_SECRET, so e2e tests
 * (and a future real adapter) share one signature contract.
 */
@Injectable()
export class NoopPaymentGateway implements PaymentGateway {
  constructor(@Inject(ENV) private readonly env: Env) {}

  async createCheckout(params: CreateCheckoutParams): Promise<CheckoutResult> {
    return {
      externalSubscriptionId: `noop_sub_${params.tenantId}_${params.planKey}`,
      checkoutUrl: null,
    };
  }

  verifySignature(rawBody: Buffer | string, signature: string | undefined): boolean {
    if (!signature) return false;
    const expected = NoopPaymentGateway.sign(rawBody, this.env.BILLING_WEBHOOK_SECRET);
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  }

  /** Shared signer — used by the adapter and by tests to forge valid events. */
  static sign(rawBody: Buffer | string, secret: string): string {
    return createHmac('sha256', secret).update(rawBody).digest('hex');
  }
}
