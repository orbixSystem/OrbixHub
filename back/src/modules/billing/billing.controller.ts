import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Post,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { Public, Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { BillingService } from './billing.service';
import { SubscribeDto, ChangePlanDto } from './dto/billing.dto';

@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  @Get('plans')
  plans() {
    return this.billing.getPlans();
  }

  @Get('subscription')
  subscription() {
    return this.billing.getSubscription();
  }

  @Post('subscribe')
  @Permissions('billing.manage')
  @HttpCode(200)
  subscribe(@CurrentUser() user: AuthUser, @Body() dto: SubscribeDto) {
    return this.billing.subscribe(user.tenantId, user.userId, dto.planKey);
  }

  @Post('change-plan')
  @Permissions('billing.manage')
  @HttpCode(200)
  changePlan(@CurrentUser() user: AuthUser, @Body() dto: ChangePlanDto) {
    return this.billing.changePlan(user.tenantId, user.userId, dto.planKey);
  }

  @Public()
  @Post('webhook')
  @HttpCode(200)
  async webhook(
    @Req() req: Request & { rawBody?: Buffer },
    @Headers('x-webhook-signature') signature: string | undefined,
  ) {
    const body: unknown = req.body;
    const raw = req.rawBody ?? Buffer.from(JSON.stringify(body ?? {}));
    await this.billing.processWebhook(raw, signature);
    return { received: true };
  }
}
