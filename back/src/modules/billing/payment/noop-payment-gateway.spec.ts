import { NoopPaymentGateway } from './noop-payment-gateway';

const SECRET = 'test_secret_at_least_16_chars';
const gw = new NoopPaymentGateway({ BILLING_WEBHOOK_SECRET: SECRET } as never);

describe('NoopPaymentGateway', () => {
  it('createCheckout returns a deterministic-shaped external id without HTTP', async () => {
    const r = await gw.createCheckout({ tenantId: 't1', planKey: 'pro', priceCents: 9900 });
    expect(r.externalSubscriptionId).toContain('t1');
    expect(r.checkoutUrl).toBeNull();
  });

  it('verifySignature accepts a correct HMAC and rejects a wrong/missing one', () => {
    const body = JSON.stringify({ id: 'evt_1', type: 'subscription.active' });
    const sig = NoopPaymentGateway.sign(body, SECRET);
    expect(gw.verifySignature(body, sig)).toBe(true);
    expect(gw.verifySignature(body, 'deadbeef')).toBe(false);
    expect(gw.verifySignature(body, undefined)).toBe(false);
    expect(gw.verifySignature(body + 'x', sig)).toBe(false);
  });
});
