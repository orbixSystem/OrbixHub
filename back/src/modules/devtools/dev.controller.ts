import { Controller, Get } from '@nestjs/common';
import { Public } from '../../common/auth/decorators';
import { DevInboxService } from './dev-inbox.service';

@Controller()
export class DevController {
  constructor(private readonly inbox: DevInboxService) {}

  // Dev-only: gated by env at module registration; no auth so deslogado flows can be tested.
  @Public()
  @Get('dev/inbox')
  list() {
    return this.inbox.list();
  }
}
