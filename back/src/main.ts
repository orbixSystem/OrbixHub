import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { noStore } from './common/http/no-store.middleware';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { rawBody: true });
  // Trust the first proxy hop so req.ip is the real client IP (X-Forwarded-For)
  // behind a load balancer/reverse proxy — required for correct rate limiting.
  app.set('trust proxy', 1);
  app.setGlobalPrefix('api');
  app.use(helmet());
  // Respostas da API nunca devem ser cacheadas pelo browser (isolamento multi-tenant).
  app.use(noStore);
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  app.enableCors({ origin: origins.length ? origins : false, credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  await app.listen(process.env.PORT ? Number(process.env.PORT) : 3000);
}
bootstrap();
