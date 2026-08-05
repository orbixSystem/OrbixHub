import { buildInventoryCsv, buildInventoryPdf } from './inventory-export';
import type { InventoryMetricsReport } from '../../inventory/dto/metrics.dto';

/**
 * Coluna de MARGEM no export de estoque — a resposta ao pedido de "lucro na
 * tela de relatório". É ponto-no-tempo (preços ATUAIS), mesmo critério já
 * usado no `stockValue` do relatório: não há snapshot de custo por venda, então
 * isto responde "qual a margem hoje", não "quanto lucrei nas vendas passadas".
 */
function row(over: Partial<InventoryMetricsReport['rows'][number]> = {}) {
  return {
    id: 'i1',
    name: 'Filtro de óleo',
    sku: 'FO-1',
    current_stock: 5,
    min_stock: 2,
    cost_price: null,
    sale_price: null,
    stockValue: 0,
    belowMin: false,
    ...over,
  };
}

describe('buildInventoryCsv — coluna Margem', () => {
  it('calcula (venda-custo)/custo, arredondada a 1 casa', () => {
    const csv = buildInventoryCsv({
      rows: [row({ cost_price: 20, sale_price: 35.9 })],
      stockValue: 100,
    });
    const texto = csv.toString('utf-8');
    // (35,90 - 20) / 20 = 79,5%
    expect(texto).toContain('79,5%');
  });

  it('sem os dois preços, mostra travessão — não inventa 0%', () => {
    const csv = buildInventoryCsv({
      rows: [row({ cost_price: null, sale_price: 35.9 })],
      stockValue: 0,
    });
    const linhas = csv.toString('utf-8').split('\r\n');
    const linhaItem = linhas[1];
    expect(linhaItem.endsWith(';—')).toBe(true);
  });

  it('custo zero não gera divisão por zero (mostra travessão)', () => {
    const csv = buildInventoryCsv({
      rows: [row({ cost_price: 0, sale_price: 10 })],
      stockValue: 0,
    });
    expect(csv.toString('utf-8').split('\r\n')[1].endsWith(';—')).toBe(true);
  });

  it('cabeçalho inclui a coluna Margem', () => {
    const csv = buildInventoryCsv({ rows: [], stockValue: 0 });
    expect(csv.toString('utf-8').split('\r\n')[0]).toContain('Margem');
  });
});

describe('buildInventoryPdf — não quebra com a 9ª coluna', () => {
  it('gera um PDF válido (bytes com o cabeçalho %PDF)', async () => {
    const buf = await buildInventoryPdf({
      rows: [row({ cost_price: 20, sale_price: 35.9 })],
      stockValue: 100,
    });
    expect(buf.subarray(0, 4).toString('ascii')).toBe('%PDF');
  });
});
