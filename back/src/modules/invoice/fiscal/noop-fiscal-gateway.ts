import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import {
  FiscalCancelParams,
  FiscalCancelResult,
  FiscalGateway,
  FiscalIssueParams,
  FiscalIssueResult,
} from './fiscal-gateway';

/**
 * Gateway fiscal da fase de validação (dev/teste). Sem HTTP externo: autoriza a
 * nota de forma síncrona com dados sintéticos, para exercitar todo o fluxo do
 * módulo sem depender de certificado A1 nem adesão de município ao ADN.
 *
 * Webhooks são autenticados por HMAC-SHA256 do corpo cru com INVOICE_WEBHOOK_SECRET,
 * então e2e (e o adaptador real futuro) compartilham um contrato de assinatura.
 * A impl real (`GovBrNfseGateway`) devolveria `processing` e confirmaria via webhook.
 */
@Injectable()
export class NoopFiscalGateway implements FiscalGateway {
  constructor(@Inject(ENV) private readonly env: Env) {}

  async issue(params: FiscalIssueParams): Promise<FiscalIssueResult> {
    const seq = Math.floor(Math.random() * 900000) + 100000;
    return {
      externalId: `noop_inv_${params.invoiceId}`,
      status: 'authorized',
      number: String(seq),
      series: '1',
      accessKey: randomUUID().replace(/-/g, ''),
      pdfUrl: null,
      xmlUrl: null,
      rejectionReason: null,
    };
  }

  async cancel(_params: FiscalCancelParams): Promise<FiscalCancelResult> {
    return { status: 'canceled', rejectionReason: null };
  }

  verifySignature(rawBody: Buffer | string, signature: string | undefined): boolean {
    if (!signature) return false;
    const expected = NoopFiscalGateway.sign(rawBody, this.env.INVOICE_WEBHOOK_SECRET);
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  }

  /** Assinador compartilhado — usado pelo adaptador e por testes p/ forjar eventos. */
  static sign(rawBody: Buffer | string, secret: string): string {
    return createHmac('sha256', secret).update(rawBody).digest('hex');
  }
}
