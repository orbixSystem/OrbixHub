import type { Request, Response, NextFunction } from 'express';

/**
 * Marca toda resposta da API como não-cacheável.
 *
 * Multi-tenant: respostas autenticadas (ex.: GET /settings) NUNCA devem ser
 * servidas do cache do browser para outro tenant. Sem `Cache-Control: no-store`
 * o navegador pode reusar uma resposta heurísticamente cacheada após troca de
 * conta, exibindo dados da empresa anterior. `no-store` elimina esse vetor.
 */
export function noStore(_req: Request, res: Response, next: NextFunction): void {
  res.setHeader('Cache-Control', 'no-store');
  next();
}
