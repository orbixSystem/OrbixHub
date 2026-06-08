import { Global, Module } from '@nestjs/common';
import { DevInboxService } from './dev-inbox.service';
import { DevController } from './dev.controller';

const devEnabled =
  (process.env.DEV_TOOLS_ENABLED ?? '').toLowerCase() === 'true';

@Global()
@Module({
  controllers: devEnabled ? [DevController] : [],
  providers: [DevInboxService],
  exports: [DevInboxService],
})
export class DevtoolsModule {}
