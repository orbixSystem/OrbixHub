import { AllExceptionsFilter } from './all-exceptions.filter';
import { BadRequestException, Logger } from '@nestjs/common';

function host(req: Record<string, unknown> = { requestId: 'r1' }) {
  const json = jest.fn();
  const status = jest.fn(() => ({ json }));
  return {
    res: { status, json },
    host: {
      switchToHttp: () => ({
        getResponse: () => ({ status }),
        getRequest: () => req,
      }),
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any,
  };
}

describe('AllExceptionsFilter', () => {
  const filter = new AllExceptionsFilter();

  it('maps HttpException to { statusCode, error, message }', () => {
    const { res, host: h } = host();
    filter.catch(new BadRequestException('bad input'), h);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 400,
        error: 'Bad Request',
        message: 'bad input',
      }),
    );
  });

  it('maps unknown errors to 500 with generic message', () => {
    const { res, host: h } = host();
    filter.catch(new Error('boom'), h);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 500,
        error: 'Internal Server Error',
      }),
    );
  });

  // A resposta precisa carregar o MESMO id que vai no log. Sem isso, quem vê o
  // erro na tela não tem como achar a linha correspondente no servidor.
  it('devolve o requestId da requisição no corpo do erro', () => {
    const { res, host: h } = host({ requestId: 'req-abc' });
    filter.catch(new Error('boom'), h);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-abc' }),
    );
  });

  it('loga 5xx numa primeira linha com requestId, rota e causa', () => {
    const spy = jest.spyOn(Logger.prototype, 'error').mockImplementation();
    const { host: h } = host({
      requestId: 'req-abc',
      method: 'GET',
      originalUrl: '/api/sales?page=1',
    });
    filter.catch(new Error('column sale.discount does not exist'), h);

    const linha = String(spy.mock.calls[0][0]).split('\n')[0];
    expect(linha).toContain('req-abc');
    expect(linha).toContain('GET /api/sales?page=1');
    expect(linha).toContain('Error');
    expect(linha).toContain('column sale.discount does not exist');
    spy.mockRestore();
  });

  // 4xx não é ruído: é o 403 do módulo bloqueado, o 400 do DTO. Sem log, some.
  it('loga 4xx como warn com requestId e rota', () => {
    const spy = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    const { host: h } = host({
      requestId: 'req-4xx',
      method: 'POST',
      originalUrl: '/api/os',
    });
    filter.catch(new BadRequestException('CNPJ inválido.'), h);

    const linha = String(spy.mock.calls[0][0]);
    expect(linha).toContain('req-4xx');
    expect(linha).toContain('POST /api/os');
    expect(linha).toContain('CNPJ inválido.');
    spy.mockRestore();
  });

  // 401 é o fluxo NORMAL do refresh de token — logar todo 401 enterra o resto.
  it('não loga 401 (ruído do refresh de token)', () => {
    const spy = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    const { host: h } = host({ requestId: 'r', method: 'GET', originalUrl: '/api/me' });
    filter.catch(new BadRequestException('x'), h);
    spy.mockClear();

    const { UnauthorizedException } = jest.requireActual<
      typeof import('@nestjs/common')
    >('@nestjs/common');
    filter.catch(new UnauthorizedException('token expirado'), h);
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });
});
