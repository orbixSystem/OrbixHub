import type { Request, Response } from 'express';
import { noStore } from './no-store.middleware';

describe('noStore middleware', () => {
  it('marca toda resposta como Cache-Control: no-store e segue a cadeia', () => {
    const headers: Record<string, string> = {};
    const res = {
      setHeader: (k: string, v: string) => {
        headers[k] = v;
      },
    } as unknown as Response;
    const next = jest.fn();

    noStore({} as Request, res, next);

    expect(headers['Cache-Control']).toBe('no-store');
    expect(next).toHaveBeenCalledTimes(1);
  });
});
