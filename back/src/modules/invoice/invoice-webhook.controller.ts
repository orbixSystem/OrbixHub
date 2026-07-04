import { Controller, Headers, HttpCode, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../../common/auth/decorators';
import { InvoiceService } from './invoice.service';

/**
 * Webhook do provedor fiscal (público, SEM JWT e SEM gate de módulo). O corpo cru
 * é autenticado por HMAC (assinatura) no service; o tenant é resolvido no servidor
 * por função SECURITY DEFINER — nunca do payload. Controller separado do gated
 * `InvoiceController` justamente para não herdar @RequiresModule/JwtAuthGuard.
 */
@Controller('invoices')
export class InvoiceWebhookController {
  constructor(private readonly invoice: InvoiceService) {}

  @Public()
  @Post('webhook')
  @HttpCode(200)
  async webhook(
    @Req() req: Request & { rawBody?: Buffer },
    @Headers('x-webhook-signature') signature: string | undefined,
  ) {
    const body: unknown = req.body;
    const raw = req.rawBody ?? Buffer.from(JSON.stringify(body ?? {}));
    await this.invoice.processWebhook(raw, signature);
    return { received: true };
  }
}
