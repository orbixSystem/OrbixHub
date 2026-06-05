export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');

export interface CheckoutResult {
  /** Provider-side subscription id; persisted as subscription.external_subscription_id. */
  externalSubscriptionId: string;
  /** Optional URL to redirect the owner to (null in Noop). */
  checkoutUrl: string | null;
}

export interface CreateCheckoutParams {
  tenantId: string;
  planKey: string;
  priceCents: number;
}

/** Gateway-agnostic contract. No gateway-specific types leak past this seam. */
export interface PaymentGateway {
  /** Start a subscription/checkout. MUST be called OUTSIDE any DB transaction. */
  createCheckout(params: CreateCheckoutParams): Promise<CheckoutResult>;
  /**
   * Verify a webhook signature over the EXACT raw request body.
   * Returns true iff the signature is authentic. Never throws.
   */
  verifySignature(rawBody: Buffer | string, signature: string | undefined): boolean;
}
