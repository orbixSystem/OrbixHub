/**
 * Regra PURA do "A receber": quem está vencido, o que vem primeiro, que página.
 *
 * Sem Nest, sem banco. É a decisão de negócio que erra em silêncio — um devedor
 * classificado errado não estoura nada, só some da fila de cobrança. E é a
 * regra que o offline (Dart) repete: `receivables-filtro.casos.json` é o
 * contrato lido pelos testes dos DOIS lados.
 */
export type Vencimento = 'todos' | 'vencidos' | 'vence7' | 'a_vencer';
export type Origem = 'todos' | 'os' | 'sale';
export type OrdemDevedores = 'valor' | 'mais_antigo' | 'nome' | 'vencimento';

export interface TituloParaFiltro {
  origin: 'os' | 'sale';
  createdAt: string | null;
  balance: number;
  /** Próxima parcela em aberto (YYYY-MM-DD); null = sem plano. */
  proximaParcelaEm: string | null;
}

export interface DevedorParaFiltro {
  customerId: string | null;
  customerName: string;
  totalDue: number;
  titleCount: number;
  oldestAt: string | null;
  titulos: TituloParaFiltro[];
}

export interface DevedorClassificado extends DevedorParaFiltro {
  /** Vencimento mais próximo entre os títulos (parcela, senão data do título). */
  nextDueAt: string | null;
  /** Ao menos UM título vencido — não é preciso estar tudo vencido. */
  overdue: boolean;
}

export function semAcento(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/** "YYYY-MM-DD" em UTC — comparação por DIA, não por instante. */
function diaUtc(iso: string): string {
  return new Date(iso).toISOString().slice(0, 10);
}

/**
 * O vencimento é o PRAZO COMBINADO — a próxima parcela em aberto. Sem plano de
 * prazo não há vencimento: `null`.
 *
 * Antes isto caía na data da venda, e todo fiado sem prazo aparecia "vencido"
 * no dia seguinte — inflando o KPI "Vencido" e sujando o filtro "Vencidos",
 * que é a fila de cobrança. Fiar sem combinar data é legítimo: a dívida existe
 * (e a idade dela aparece por `oldestAt`), atraso é que não.
 *
 * Uma data ÚNICA combinada ("me paga dia 30") é gravada como plano de UMA
 * parcela — por isso ela chega aqui por `proximaParcelaEm` como qualquer outra.
 */
function vencimentoEfetivo(t: TituloParaFiltro): string | null {
  return t.proximaParcelaEm;
}

export function classificar(
  d: DevedorParaFiltro,
  hoje: Date,
): DevedorClassificado {
  const hojeDia = diaUtc(hoje.toISOString());
  let nextDueAt: string | null = null;
  let overdue = false;
  for (const t of d.titulos) {
    const v = vencimentoEfetivo(t);
    if (!v) continue;
    if (nextDueAt === null || diaUtc(v) < diaUtc(nextDueAt)) nextDueAt = v;
    if (diaUtc(v) < hojeDia) overdue = true;
  }
  return { ...d, nextDueAt, overdue };
}

export function filtrarDevedores<T extends DevedorClassificado>(
  lista: T[],
  f: { q?: string; vencimento: Vencimento; origem: Origem },
  hoje: Date,
): T[] {
  const hojeDia = diaUtc(hoje.toISOString());
  const limite7 = new Date(hoje);
  limite7.setUTCDate(limite7.getUTCDate() + 7);
  const limite7Dia = diaUtc(limite7.toISOString());
  const termo = f.q ? semAcento(f.q.trim()) : '';

  return lista.filter((d) => {
    if (f.origem !== 'todos' && !d.titulos.some((t) => t.origin === f.origem)) {
      return false;
    }
    if (termo && !semAcento(d.customerName).includes(termo)) return false;
    switch (f.vencimento) {
      case 'todos':
        return true;
      case 'vencidos':
        return d.overdue;
      case 'vence7':
        return (
          !d.overdue &&
          d.nextDueAt !== null &&
          diaUtc(d.nextDueAt) >= hojeDia &&
          diaUtc(d.nextDueAt) <= limite7Dia
        );
      case 'a_vencer':
        return !d.overdue && d.nextDueAt !== null;
    }
  });
}

export function ordenarDevedores<T extends DevedorClassificado>(
  lista: T[],
  ordem: OrdemDevedores,
): T[] {
  const copia = [...lista];
  // Desempate SEMPRE por nome sem acento — mesma colação que o Dart consegue
  // reproduzir. `localeCompare` daria ordem diferente da do front.
  const porNome = (a: DevedorClassificado, b: DevedorClassificado) => {
    const x = semAcento(a.customerName);
    const y = semAcento(b.customerName);
    return x < y ? -1 : x > y ? 1 : 0;
  };
  switch (ordem) {
    case 'valor':
      return copia.sort((a, b) => b.totalDue - a.totalDue || porNome(a, b));
    case 'mais_antigo':
      return copia.sort((a, b) => {
        if (a.oldestAt === b.oldestAt) return porNome(a, b);
        if (a.oldestAt === null) return 1;
        if (b.oldestAt === null) return -1;
        return a.oldestAt < b.oldestAt ? -1 : 1;
      });
    case 'nome':
      return copia.sort(porNome);
    case 'vencimento':
      return copia.sort((a, b) => {
        if (a.nextDueAt === b.nextDueAt) return porNome(a, b);
        if (a.nextDueAt === null) return 1; // sem data por último
        if (b.nextDueAt === null) return -1;
        return diaUtc(a.nextDueAt) < diaUtc(b.nextDueAt) ? -1 : 1;
      });
  }
}

export function paginar<T>(
  lista: T[],
  page: number,
  pageSize: number,
): { items: T[]; total: number } {
  const p = Math.max(1, page);
  const inicio = (p - 1) * pageSize;
  return { items: lista.slice(inicio, inicio + pageSize), total: lista.length };
}
