import { Global, Module } from '@nestjs/common';
import { envSchema, Env } from './env.schema';

export const ENV = Symbol('ENV');

@Global()
@Module({
  providers: [
    {
      provide: ENV,
      useFactory: (): Env => {
        const parsed = envSchema.safeParse(process.env);
        if (!parsed.success) {
          // eslint-disable-next-line no-console
          console.error('Invalid environment:', parsed.error.flatten().fieldErrors);
          throw new Error('Invalid environment variables');
        }
        return parsed.data;
      },
    },
  ],
  exports: [ENV],
})
export class ConfigModule {}
