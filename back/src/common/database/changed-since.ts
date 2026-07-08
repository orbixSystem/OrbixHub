import { Prisma } from '@prisma/client';
import type { PrismaService } from './prisma.service';
import type { TxClient } from './tenant-context';

/** Cursor de paginação por (coluna de tempo, id) — opaco para o chamador. */
export interface ChangeCursor {
  ts: string;
  id: string;
}

export interface ChangedSincePage {
  rows: Record<string, unknown>[];
  nextCursor: ChangeCursor | null;
}

/**
 * Alias da coluna auxiliar de cursor (texto, precisão de microssegundo). Nome
 * fixo (nunca vem do request) — `Prisma.raw` é seguro aqui.
 */
const CURSOR_TS_ALIAS = '__changed_since_cursor_ts';

/**
 * `SELECT * FROM <table> WHERE (<column>, id) > (cursor) ORDER BY <column>, id
 * LIMIT n` — usado pelo pull de sync offline (`listChangedSince` de cada
 * módulo dono). Roda sob o cliente tx-scoped (RLS já restringe ao tenant).
 *
 * `table`/`column` são identificadores SQL embutidos via `Prisma.raw` — o
 * CHAMADOR deve sempre passar um literal validado contra uma whitelist fixa
 * (nunca uma string vinda direto do request), já que `Prisma.raw` não escapa.
 *
 * O cursor NÃO usa o `Date` que o driver devolve para `<column>` — `Date` só
 * tem precisão de milissegundo, mas `timestamptz` no Postgres guarda
 * microssegundos. Truncar perderia a fração de microssegundo e faria a MESMA
 * linha reaparecer na página seguinte sempre que outra linha compartilhasse o
 * mesmo milissegundo (comum em cargas em lote). Por isso a query também seleciona
 * `<column>` como texto UTC com microssegundos (`CURSOR_TS_ALIAS`), que vira o
 * `ts` do `nextCursor` — e é removido do objeto devolvido ao chamador.
 */
export async function queryChangedSince(
  db: PrismaService | TxClient,
  table: string,
  column: 'updated_at' | 'created_at',
  cursor: ChangeCursor | null,
  limit: number,
): Promise<ChangedSincePage> {
  const tableIdent = Prisma.raw(table);
  const colIdent = Prisma.raw(column);
  const cursorTsExpr = Prisma.sql`to_char(${colIdent} AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || 'Z' AS ${Prisma.raw(CURSOR_TS_ALIAS)}`;
  const rawRows = await db.$queryRaw<Record<string, unknown>[]>(
    cursor
      ? Prisma.sql`
          SELECT *, ${cursorTsExpr}
          FROM ${tableIdent}
          WHERE (${colIdent}, id) > (${cursor.ts}::timestamptz, ${cursor.id}::uuid)
          ORDER BY ${colIdent}, id
          LIMIT ${limit}
        `
      : Prisma.sql`
          SELECT *, ${cursorTsExpr}
          FROM ${tableIdent}
          ORDER BY ${colIdent}, id
          LIMIT ${limit}
        `,
  );
  if (rawRows.length === 0) return { rows: rawRows, nextCursor: null };

  const last = rawRows[rawRows.length - 1];
  const lastTs = String(last[CURSOR_TS_ALIAS]);
  const lastId = String(last.id);
  const rows = rawRows.map((r) => {
    const { [CURSOR_TS_ALIAS]: _cursorTs, ...rest } = r;
    return rest;
  });
  return {
    rows,
    nextCursor: rawRows.length < limit ? null : { ts: lastTs, id: lastId },
  };
}

/** Clampa o limite de página do pull de sync ao intervalo [1, 500] (anti-DoS). */
export function clampChangedSinceLimit(limit: number): number {
  if (!Number.isFinite(limit)) return 500;
  return Math.min(500, Math.max(1, Math.trunc(limit)));
}
