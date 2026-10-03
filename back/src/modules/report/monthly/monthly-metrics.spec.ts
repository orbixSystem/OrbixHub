import {
  NumerosDoMes,
  calcularMetricasMensais,
  variacao,
} from './monthly-metrics';

/**
 * A regra do resumo mensal.
 *
 * É aqui que mora a inteligência do recurso — NÃO no prompt. O modelo recebe
 * sinais já calculados e só escreve; se a decisão de "o que merece atenção"
 * morasse no texto, cada mês diria uma coisa diferente sobre os mesmos números,
 * e ninguém poderia conferir nada.
 *
 * Por isso a regra é pura: sem Nest, sem banco, sem rede. Cada sinal tem um
 * caso, e os casos de borda (oficina nova, mês parado) têm os seus — são eles
 * que produzem relatório constrangedor quando ninguém olha.
 */

/// Um mês qualquer, saudável, para servir de base aos casos.
const base: NumerosDoMes = {
  faturado: 50000,
  transacoes: 100,
  recebido: 48000,
  saiu: 30000,
  despesas: 30000,
  despesasPorCategoria: [
    { categoria: 'Peças', total: 18000 },
    { categoria: 'Aluguel', total: 6000 },
    { categoria: 'Energia', total: 6000 },
  ],
  aReceber: 5000,
  aReceberVencido: 500,
  osConcluidas: 80,
  osCanceladas: 4,
  osAbertas: 10,
  clientesNovos: 12,
  clientesAtendidos: 70,
  estoqueValor: 20000,
  estoqueAbaixoMinimo: 2,
};

const periodo = { de: '2026-09-01', ate: '2026-09-30', rotulo: 'Setembro/2026' };

function calcular(
  mes: Partial<NumerosDoMes> = {},
  anterior: Partial<NumerosDoMes> | null = {},
) {
  return calcularMetricasMensais({
    periodo,
    mes: { ...base, ...mes },
    anterior: anterior === null ? null : { ...base, ...anterior },
  });
}

/** Atalho: o sinal de chave `k` saiu? */
function sinal(r: ReturnType<typeof calcular>, k: string) {
  return r.sinais.find((s) => s.chave === k);
}

describe('variacao — a conta que vira seta na tela', () => {
  it('calcula a diferença percentual', () => {
    expect(variacao(110, 100)?.pct).toBe(10);
    expect(variacao(90, 100)?.pct).toBe(-10);
  });

  it('mês anterior ZERADO não vira infinito nem 100%', () => {
    // Oficina nova, ou primeira vez que a categoria aparece. "Cresceu ∞%" e
    // "cresceu 100%" são igualmente mentirosos: não há com o que comparar.
    expect(variacao(5000, 0)).toBeNull();
  });

  it('dois zeros não é queda', () => {
    expect(variacao(0, 0)).toBeNull();
  });

  it('arredonda para uma casa — 33,333% não ajuda ninguém', () => {
    expect(variacao(400, 300)?.pct).toBe(33.3);
  });
});

describe('KPIs', () => {
  it('traz os números do mês com a variação contra o anterior', () => {
    const r = calcular({ faturado: 55000 }, { faturado: 50000 });
    const fat = r.kpis.find((k) => k.chave === 'faturado')!;
    expect(fat.valor).toBe(55000);
    expect(fat.variacao?.pct).toBe(10);
  });

  it('diz quando SUBIR é bom e quando é ruim', () => {
    const r = calcular();
    const porChave = Object.fromEntries(r.kpis.map((k) => [k.chave, k]));
    // Sem isto a seta verde apareceria em cima de despesa crescendo — a tela
    // comemorando o que o dono precisa cortar.
    expect(porChave.faturado.maiorEhMelhor).toBe(true);
    expect(porChave.recebido.maiorEhMelhor).toBe(true);
    expect(porChave.despesas.maiorEhMelhor).toBe(false);
    expect(porChave.aReceber.maiorEhMelhor).toBe(false);
  });

  it('o resultado é o que entrou MENOS o que saiu do caixa', () => {
    const r = calcular({ recebido: 48000, saiu: 30000 });
    expect(r.kpis.find((k) => k.chave === 'resultado')!.valor).toBe(18000);
  });

  it('ticket médio é faturado ÷ transações, e não quebra sem transação', () => {
    expect(calcular({ faturado: 50000, transacoes: 100 })
      .kpis.find((k) => k.chave === 'ticket')!.valor).toBe(500);
    expect(calcular({ faturado: 0, transacoes: 0 })
      .kpis.find((k) => k.chave === 'ticket')!.valor).toBe(0);
  });

  it('sem mês anterior (primeiro mês de uso), nenhuma variação é inventada', () => {
    const r = calcular({}, null);
    expect(r.kpis.every((k) => k.variacao === null)).toBe(true);
  });
});

describe('sinais — o que merece atenção', () => {
  it('fiado crescendo MAIS que a receita', () => {
    // O caso clássico: o mês "cresceu", mas o crescimento foi fiado. Faturar
    // sem receber é o jeito mais comum de uma oficina quebrar vendendo bem.
    const r = calcular(
      { faturado: 55000, aReceber: 15000 },
      { faturado: 50000, aReceber: 5000 },
    );
    const s = sinal(r, 'fiado_crescendo')!;
    expect(s).toBeDefined();
    expect(s.severidade).toBe('alerta');
  });

  it('fiado crescendo junto com a receita NÃO é alerta', () => {
    const r = calcular(
      { faturado: 60000, aReceber: 6000 },
      { faturado: 50000, aReceber: 5000 },
    );
    expect(sinal(r, 'fiado_crescendo')).toBeUndefined();
  });

  it('fiado alto em valor absoluto pequeno não vira alarme', () => {
    // 50 → 200 reais é +300%, e não é notícia. Sem piso absoluto, o resumo
    // gritaria por qualquer troco e o dono aprenderia a ignorar os alertas.
    const r = calcular(
      { faturado: 50000, aReceber: 200 },
      { faturado: 50000, aReceber: 50 },
    );
    expect(sinal(r, 'fiado_crescendo')).toBeUndefined();
  });

  it('despesa subindo mais que o faturamento', () => {
    const r = calcular(
      { faturado: 51000, despesas: 40000 },
      { faturado: 50000, despesas: 30000 },
    );
    expect(sinal(r, 'despesa_subindo')).toBeDefined();
  });

  it('resultado negativo: saiu mais do que entrou', () => {
    const r = calcular({ recebido: 20000, saiu: 32000 });
    const s = sinal(r, 'resultado_negativo')!;
    expect(s.severidade).toBe('critico');
  });

  it('ticket médio caindo de forma relevante', () => {
    const r = calcular(
      { faturado: 40000, transacoes: 100 }, // 400
      { faturado: 50000, transacoes: 100 }, // 500
    );
    expect(sinal(r, 'ticket_caindo')).toBeDefined();
  });

  it('queda pequena de ticket é ruído, não sinal', () => {
    const r = calcular(
      { faturado: 49000, transacoes: 100 },
      { faturado: 50000, transacoes: 100 },
    );
    expect(sinal(r, 'ticket_caindo')).toBeUndefined();
  });

  it('cancelamento acima do aceitável', () => {
    const r = calcular({ osConcluidas: 70, osCanceladas: 20 });
    expect(sinal(r, 'cancelamento_alto')).toBeDefined();
  });

  it('vencido tomando conta do que há para receber', () => {
    const r = calcular({ aReceber: 10000, aReceberVencido: 6000 });
    const s = sinal(r, 'vencido_alto')!;
    expect(s.severidade).toBe('critico');
  });

  it('itens abaixo do mínimo viram sinal acionável', () => {
    const r = calcular({ estoqueAbaixoMinimo: 7 });
    expect(sinal(r, 'estoque_abaixo_minimo')).toBeDefined();
  });

  it('mês SEM movimento diz isso, e não dispara os outros sinais', () => {
    // Oficina de férias, ou tenant que não usou o sistema. Sem este caso, o
    // resumo sairia falando de quedas de 100% em tudo — tecnicamente certo e
    // completamente inútil.
    const r = calcular(
      {
        faturado: 0,
        transacoes: 0,
        recebido: 0,
        saiu: 0,
        despesas: 0,
        despesasPorCategoria: [],
        aReceber: 0,
        aReceberVencido: 0,
        osConcluidas: 0,
        osCanceladas: 0,
        osAbertas: 0,
        clientesNovos: 0,
        clientesAtendidos: 0,
        estoqueAbaixoMinimo: 0,
      },
      { faturado: 50000 },
    );
    expect(sinal(r, 'sem_movimento')).toBeDefined();
    expect(r.sinais).toHaveLength(1);
  });

  it('os sinais saem do mais grave para o menos', () => {
    const r = calcular({
      recebido: 10000,
      saiu: 30000, // crítico
      estoqueAbaixoMinimo: 7, // informativo
    });
    const severidades = r.sinais.map((s) => s.severidade);
    expect(severidades[0]).toBe('critico');
    expect(severidades.indexOf('critico')).toBeLessThan(
      severidades.indexOf('info'),
    );
  });

  it('mês saudável não inventa problema', () => {
    const r = calcular();
    expect(r.sinais.filter((s) => s.severidade !== 'info')).toHaveLength(0);
  });

  it('cada sinal carrega os números que o sustentam', () => {
    // O texto do modelo é escrito EM CIMA destes números. Sinal sem número
    // seria um convite a inventar a cifra que falta.
    const r = calcular({ recebido: 20000, saiu: 32000 });
    expect(sinal(r, 'resultado_negativo')!.numeros).toEqual(
      expect.objectContaining({ recebido: 20000, saiu: 32000 }),
    );
  });
});

describe('o pacote que vai para o modelo', () => {
  it('leva período, KPIs e sinais — e nada além', () => {
    const r = calcular();
    expect(Object.keys(r).sort()).toEqual(['kpis', 'periodo', 'sinais']);
    expect(r.periodo.rotulo).toBe('Setembro/2026');
  });
});
