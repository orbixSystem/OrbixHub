import { SetMetadata } from '@nestjs/common';

export const REQUIRES_MODULE = 'requiresModule';
export const RequiresModule = (moduleKey: string) =>
  SetMetadata(REQUIRES_MODULE, moduleKey);
