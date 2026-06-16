import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('AllExceptionsFilter');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
    let error = 'Internal Server Error';
    let message: string | string[] = 'Internal server error';

    if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
        error = exception.name.replace(/Exception$/, '');
      } else if (typeof body === 'object' && body) {
        const b = body as { message?: string | string[]; error?: string };
        message = b.message ?? exception.message;
        error = b.error ?? exception.name.replace(/Exception$/, '');
      }
    }
    // Map common Nest names to HTTP reason phrases
    const reason: Record<number, string> = {
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      409: 'Conflict',
      429: 'Too Many Requests',
      500: 'Internal Server Error',
    };
    error = reason[statusCode] ?? error;

    // Erros 5xx (inclui qualquer exceção não-HTTP, ex.: Prisma) são logados com
    // stack — a resposta ao cliente segue genérica/sem vazar detalhe.
    if (statusCode >= 500) {
      const where = `${req?.method ?? '?'} ${req?.originalUrl ?? req?.url ?? '?'}`;
      const stack =
        exception instanceof Error ? exception.stack : String(exception);
      this.logger.error(`5xx em ${where}: ${stack}`);
    }

    res.status(statusCode).json({ statusCode, error, message });
  }
}
