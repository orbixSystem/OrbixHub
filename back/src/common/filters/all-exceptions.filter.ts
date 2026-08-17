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

    // Correlação: o MESMO id vai no log e na resposta (e no header
    // `x-request-id`, posto pelo RequestIdMiddleware). É o que permite pegar o
    // id que apareceu na tela/console do app e achar a linha exata no servidor.
    const requestId = (req as { requestId?: string } | undefined)?.requestId;
    const where = `${req?.method ?? '?'} ${req?.originalUrl ?? req?.url ?? '?'}`;
    const id = requestId ?? '-';

    // Erros 5xx (inclui qualquer exceção não-HTTP, ex.: Prisma) são logados com
    // stack — a resposta ao cliente segue genérica/sem vazar detalhe. A PRIMEIRA
    // linha resume tudo (id, rota, status, classe e causa) para não ser preciso
    // ler a stack inteira só para saber o que quebrou e onde.
    if (statusCode >= 500) {
      const causa =
        exception instanceof Error
          ? `${exception.name}: ${exception.message}`
          : String(exception);
      const stack = exception instanceof Error ? exception.stack : '';
      this.logger.error(
        `5xx [${id}] ${where} -> ${statusCode} ${causa}` +
          (stack ? `\n${stack}` : ''),
      );
    } else if (statusCode >= 400 && statusCode !== HttpStatus.UNAUTHORIZED) {
      // 4xx é diagnóstico, não ruído: é o 403 do módulo bloqueado e o 400 do
      // DTO que hoje somem sem deixar rastro. 401 fica de fora porque é o
      // fluxo NORMAL do refresh de token — logá-lo enterraria todo o resto.
      const detalhe = Array.isArray(message) ? message.join(', ') : message;
      this.logger.warn(`${statusCode} [${id}] ${where}: ${detalhe}`);
    }

    res.status(statusCode).json({ statusCode, error, message, requestId });
  }
}
