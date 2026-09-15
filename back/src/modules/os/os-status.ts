/** Os 11 estados do workflow da OS, em ordem de fluxo. */
export const OS_STATUSES = [
  'aberta',
  'aguardando_aprovacao',
  'aprovada',
  'em_execucao',
  'aguardando_pecas',
  'pendente',
  'sem_conserto',
  'concluida',
  'a_receber',
  'entregue',
  'cancelada',
] as const;
export type OsStatus = (typeof OS_STATUSES)[number];

/**
 * Os GRUPOS de status da OS — fonte única para quem agrega, cobra ou conta.
 *
 * Existe porque a lista de status cresceu de 7 para 11 (`a_receber`,
 * `aguardando_pecas`, `pendente`, `sem_conserto`) e cada consumidor tinha a sua
 * cópia literal do conjunto: as métricas, o faturamento por dia, o tempo de
 * ciclo, o relatório e o fiado. Nenhuma foi atualizada junto, e o sintoma não é
 * um erro — é um número mais baixo do que a realidade, calado.
 *
 * Mora aqui, e não no DTO, para ser importável sem arrastar `class-validator`
 * junto: enquanto a lista vivia em `dto/order.dto.ts`, qualquer arquivo que só
 * quisesse saber quais status existem puxava os decorators e exigia
 * `reflect-metadata` carregado.
 *
 * Quem precisar de um grupo novo **acrescenta aqui**, não no seu próprio
 * arquivo. O teste `os-status.spec.ts` garante que todo status caiu em algum
 * balde, então um status novo quebra o teste em vez de sumir de um relatório.
 */

/**
 * O trabalho acabou e vale dinheiro: já pode ser faturado, cobrado e entra no
 * tempo de ciclo.
 *
 * `a_receber` está aqui porque é literalmente "serviço pronto, falta o
 * pagamento" — deixá-lo de fora fazia o faturamento CAIR no instante em que a
 * OS era marcada como a receber, e sumir da carteira de cobrança justamente o
 * status cujo nome é cobrar.
 *
 * `sem_conserto` NÃO está: não houve serviço a faturar. Se a oficina cobra a
 * diagnose, isso vira item da OS e ela é concluída — não fica em sem_conserto.
 */
export const FATURAVEIS: ReadonlySet<OsStatus> = new Set([
  'concluida',
  'a_receber',
  'entregue',
]);

/**
 * A OS saiu do fluxo de trabalho — não está mais "acontecendo". Inclui as
 * faturáveis, a sem conserto e a cancelada.
 *
 * É o conjunto do ATRASO: só uma OS viva pode estourar prazo. Antes faltavam
 * `a_receber` e `sem_conserto` aqui, então uma OS já encerrada continuava
 * contada como atrasada para sempre no painel.
 */
export const ENCERRADAS: ReadonlySet<OsStatus> = new Set([
  ...FATURAVEIS,
  'sem_conserto',
  'cancelada',
]);

/** Trabalho acontecendo: tudo que não encerrou. */
export const EM_ANDAMENTO: ReadonlySet<OsStatus> = new Set(
  OS_STATUSES.filter((s) => !ENCERRADAS.has(s)),
);

/** Forma pronta para `Prisma { in: ... }` / `notIn`. */
export const lista = (s: ReadonlySet<OsStatus>): OsStatus[] => [...s];
