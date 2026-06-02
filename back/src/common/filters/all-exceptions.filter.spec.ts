import { AllExceptionsFilter } from './all-exceptions.filter';
import { BadRequestException } from '@nestjs/common';

function host() {
  const json = jest.fn();
  const status = jest.fn(() => ({ json }));
  return {
    res: { status, json },
    host: {
      switchToHttp: () => ({
        getResponse: () => ({ status }),
        getRequest: () => ({ requestId: 'r1' }),
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
});
