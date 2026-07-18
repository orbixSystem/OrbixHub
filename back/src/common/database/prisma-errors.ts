/**
 * Helpers para discriminar erros de unique violation do Prisma (P2002).
 *
 * `meta.target` traz as COLUNAS da constraint violada QUANDO o Postgres expõe o
 * detalhe do erro (roles com BYPASSRLS, ex.: app_owner):
 *  - PK (id duplicado):            `['id']`
 *  - documento do cliente:         `['tenant_id','document']`
 *  - caixa aberto por dispositivo: `['tenant_id','COALESCE(device_id', ...]`
 *
 * ATENÇÃO (verificado empiricamente no Postgres local): sob RLS como `app_user`
 * — o caminho REAL da aplicação — o Postgres SUPRIME o detalhe da constraint e
 * o Prisma devolve `meta.target = null` ("Unique constraint failed on the
 * (not available)"). Ou seja: em produção `isIdUniqueViolation` retorna `false`
 * mesmo quando a PK foi violada.
 *
 * Portanto, para discriminar "id duplicado" (create-with-id do replay offline)
 * de uma natural key (documento, sku/barcode, nº da OS, sessão por dispositivo):
 *  - tabelas SEM outra unique além da PK (subject, service_order_item,
 *    cash_entry): P2002 com `dto.id` presente SÓ pode ser a PK — mapeie direto;
 *  - tabelas COM natural keys: use `isIdUniqueViolation` (cobre o caso com
 *    detalhe disponível) e, se `false`, confirme com uma LEITURA por id em nova
 *    transação (o registro com aquele id existe no tenant ⇒ conflito de id).
 */

interface PrismaKnownError {
  code?: string;
  meta?: { target?: unknown };
}

/** P2002 = unique violation (qualquer constraint). */
export const isUniqueViolation = (e: unknown): boolean =>
  (e as PrismaKnownError)?.code === 'P2002';

/**
 * P2002 comprovadamente na PRIMARY KEY (`meta.target` é exatamente `['id']`).
 * Sob RLS o target vem `null` e isto retorna `false` — combine com a checagem
 * de existência por id (ver doc do módulo).
 */
export function isIdUniqueViolation(e: unknown): boolean {
  if (!isUniqueViolation(e)) return false;
  const target = (e as PrismaKnownError).meta?.target;
  return Array.isArray(target) && target.length === 1 && target[0] === 'id';
}
