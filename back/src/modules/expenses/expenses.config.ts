/**
 * Config + helpers PUROS do módulo Despesas (contas a pagar).
 *
 * Sem Nest aqui: as funções de data são o miolo da esteira de recorrência e
 * precisam ser testadas isoladamente — fevereiro, ano bissexto e virada de ano
 * são o tipo de coisa que só se pega com teste barato.
 */

export const EXPENSES_MODULE_KEY = 'expenses';

/** Espelha o CHECK de `expense.paid_method` / `expense_recurrence.method`. */
export const PAYMENT_METHODS = [
  'pix',
  'dinheiro',
  'cartao_credito',
  'cartao_debito',
  'outro',
] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

/** Espelha o CHECK de `expense_recurrence.frequency`. */
export const FREQUENCIES = ['monthly', 'yearly'] as const;
export type Frequency = (typeof FREQUENCIES)[number];

/**
 * Quantas ocorrências a esteira materializa à frente.
 *
 * 12 meses: cobre o horizonte que a cliente enxerga (ela navega mês a mês, não
 * anos) sem encher a tabela. Um job diário completa a esteira, então a janela
 * anda sozinha — não é um teto, é um adiantamento.
 */
export const MESES_DE_ESTEIRA = 12;

/** Último dia do mês (1..12) — resolve fevereiro e ano bissexto. */
export function ultimoDiaDoMes(ano: number, mes: number): number {
  // Dia 0 do mês seguinte = último dia deste mês. `Date.UTC` evita que o fuso
  // local empurre a data para o dia anterior.
  return new Date(Date.UTC(ano, mes, 0)).getUTCDate();
}

/**
 * Data de vencimento de uma ocorrência.
 *
 * Mês curto ENCURTA o dia: "todo dia 31" cai em 28/02 (ou 29 em bissexto), não
 * transborda para 03/03. Transbordar faria a conta de fevereiro aparecer em
 * março e sumir do mês em que ela é devida.
 */
export function dataDaOcorrencia(
  ano: number,
  mes: number,
  diaPedido: number,
): Date {
  const ultimo = ultimoDiaDoMes(ano, mes);
  const dia = diaPedido > ultimo ? ultimo : diaPedido;
  return new Date(Date.UTC(ano, mes - 1, dia));
}

/**
 * Datas das próximas ocorrências de uma regra, a partir de (exclusive) o que já
 * foi gerado.
 *
 * `desde` é o último vencimento já materializado (null = nada ainda). Devolve no
 * máximo [MESES_DE_ESTEIRA] datas, parando em `ends_on` quando houver.
 */
export function proximasOcorrencias(args: {
  frequency: Frequency;
  dayOfMonth: number;
  monthOfYear?: number | null;
  startsOn: Date;
  endsOn?: Date | null;
  desde?: Date | null;
  quantidade?: number;
}): Date[] {
  const {
    frequency,
    dayOfMonth,
    monthOfYear,
    startsOn,
    endsOn,
    desde,
    quantidade = MESES_DE_ESTEIRA,
  } = args;

  const datas: Date[] = [];
  // Ponto de partida: o mês do último gerado (para andar a partir dele) ou o
  // mês de início da regra.
  const base = desde ?? startsOn;
  let ano = base.getUTCFullYear();
  let mes = base.getUTCMonth() + 1;

  for (let i = 0; i < quantidade; i++) {
    if (frequency === 'monthly') {
      mes += 1;
      if (mes > 12) {
        mes = 1;
        ano += 1;
      }
    } else {
      ano += 1;
      mes = monthOfYear ?? mes;
    }

    const data = dataDaOcorrencia(ano, mes, dayOfMonth);
    // Antes do início da regra não existe ocorrência (caso da primeira geração,
    // quando `desde` é nulo e a base é o próprio `starts_on`).
    if (data < startsOn) continue;
    if (endsOn && data > endsOn) break;
    datas.push(data);
  }
  return datas;
}

/**
 * A PRIMEIRA ocorrência de uma regra recém-criada: o próprio vencimento
 * informado. A conta que a cliente acabou de cadastrar é a deste mês; a esteira
 * só cuida das seguintes.
 */
export function primeiraOcorrencia(startsOn: Date): Date {
  return new Date(
    Date.UTC(
      startsOn.getUTCFullYear(),
      startsOn.getUTCMonth(),
      startsOn.getUTCDate(),
    ),
  );
}

/** Arredonda a 2 casas (centavos) evitando ruído de ponto flutuante. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Recorte de um mês: [primeiro dia, primeiro dia do mês seguinte).
 * Intervalo semiaberto para não depender de "23:59:59.999".
 */
export function limitesDoMes(ano: number, mes: number): { de: Date; ate: Date } {
  return {
    de: new Date(Date.UTC(ano, mes - 1, 1)),
    ate: new Date(Date.UTC(ano, mes, 1)),
  };
}
