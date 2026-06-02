import { JwtAuthGuard } from './jwt-auth.guard';
import { AccessTokenService } from './jwt.service';
import { Reflector } from '@nestjs/core';
import { UnauthorizedException } from '@nestjs/common';
import type { Env } from '../config/env.schema';

const env = {
  JWT_ACCESS_SECRET: 'x'.repeat(40),
  JWT_ACCESS_TTL: '15m',
} as unknown as Env;

function ctxWith(headers: Record<string, string>) {
  const req: { headers: Record<string, string>; user?: unknown } = { headers };
  return {
    switchToHttp: () => ({ getRequest: () => req }),
    getHandler: () => () => undefined,
    getClass: () => class {},
    _req: req,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

describe('JwtAuthGuard', () => {
  const tokens = new AccessTokenService(env);
  const reflector = {
    getAllAndOverride: () => false,
  } as unknown as Reflector;
  const guard = new JwtAuthGuard(reflector, tokens);

  it('rejects when no bearer header', () => {
    expect(() => guard.canActivate(ctxWith({}))).toThrow(UnauthorizedException);
  });

  it('accepts a valid token and sets req.user with tid from token', () => {
    const token = tokens.sign({ sub: 'u1', tid: 't1', role: 'owner', jti: 'j1' });
    const ctx = ctxWith({ authorization: `Bearer ${token}` });
    expect(guard.canActivate(ctx)).toBe(true);
    expect(ctx._req.user).toMatchObject({
      userId: 'u1',
      tenantId: 't1',
      role: 'owner',
    });
  });

  it('allows public routes without a token', () => {
    const publicReflector = {
      getAllAndOverride: () => true,
    } as unknown as Reflector;
    const g = new JwtAuthGuard(publicReflector, tokens);
    expect(g.canActivate(ctxWith({}))).toBe(true);
  });
});
