import { normalizeWdapiResponse } from './wdapi-plate.provider';

/** Resposta de exemplo da documentação oficial (placa INT8C36), abreviada. */
const docSample: Record<string, unknown> = {
  MARCA: 'VW',
  MODELO: 'CROSSFOX',
  SUBMODELO: 'CROSSFOX',
  VERSAO: 'CROSSFOX',
  ano: '2007',
  anoModelo: '2007',
  chassi: '*****10137',
  cor: 'Prata',
  extra: {
    ano_fabricacao: '2007',
    cilindradas: '1599',
    combustivel: 'Alcool / Gasolina',
    especie: 'Passageiro',
    municipio: 'SAO LEOPOLDO',
    nacionalidade: 'Nacional',
    quantidade_passageiro: '5',
    sub_segmento: 'AU - HATCH PEQUENO',
    tipo_veiculo: 'Automovel',
    uf: 'RS',
  },
  fipe: {
    dados: [
      {
        ano_modelo: '2007',
        codigo_fipe: '005340-6',
        combustivel: 'Álcool',
        mes_referencia: 'maio de 2022 ',
        score: 3,
        texto_marca: 'VW - VolksWagen',
        texto_modelo: 'CROSSFOX 1.6 T.Flex 8V (Antigo)',
        texto_valor: 'R$ 25.000,00',
      },
      {
        ano_modelo: '2007',
        codigo_fipe: '005225-6',
        combustivel: 'Gasolina',
        mes_referencia: 'maio de 2022 ',
        score: 101,
        texto_marca: 'VW - VolksWagen',
        texto_modelo: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
        texto_valor: 'R$ 28.799,00',
      },
    ],
  },
  logo: 'https://apiplacas.com.br/logos/logosMarcas/vw.png',
  mensagemRetorno: 'Sem erros.',
  municipio: 'São Leopoldo',
  origem: 'NACIONAL',
  placa: 'INT8C36',
  placa_alternativa: 'INT8236',
  situacao: 'Sem restrição',
  uf: 'RS',
};

describe('normalizeWdapiResponse', () => {
  it('achata a resposta da doc no PlateHit com os campos do cadastro', () => {
    const hit = normalizeWdapiResponse('INT8C36', docSample);
    expect(hit.placa).toBe('INT8C36');
    expect(hit.placaAlternativa).toBe('INT8236');
    expect(hit.marca).toBe('VW');
    expect(hit.modelo).toBe('CROSSFOX');
    expect(hit.ano).toBe('2007');
    expect(hit.cor).toBe('Prata');
    expect(hit.chassi).toBe('*****10137');
    expect(hit.municipio).toBe('São Leopoldo');
    expect(hit.uf).toBe('RS');
    expect(hit.combustivel).toBe('Alcool / Gasolina');
    expect(hit.cilindradas).toBe('1599');
    expect(hit.passageiros).toBe('5');
    expect(hit.situacao).toBe('Sem restrição');
  });

  it('escolhe a entrada FIPE de MAIOR score (recomendação da doc)', () => {
    const hit = normalizeWdapiResponse('INT8C36', docSample);
    expect(hit.fipe?.score).toBe(101);
    expect(hit.fipe?.valor).toBe('R$ 28.799,00');
    expect(hit.fipe?.codigoFipe).toBe('005225-6');
    // mes_referencia vem com espaço ao fim na API — normalizamos com trim.
    expect(hit.fipe?.mesReferencia).toBe('maio de 2022');
  });

  it('tolera resposta mínima (extra/fipe ausentes — aviso explícito da doc)', () => {
    const hit = normalizeWdapiResponse('ABC1234', {
      marca: 'FIAT',
      modelo: 'UNO',
    });
    expect(hit.placa).toBe('ABC1234');
    expect(hit.marca).toBe('FIAT');
    expect(hit.fipe).toBeUndefined();
    expect(hit.municipio).toBeUndefined();
  });

  it('descarta strings vazias em vez de propagá-las', () => {
    const hit = normalizeWdapiResponse('ABC1234', {
      marca: '  ',
      cor: '',
      extra: { combustivel: ' Gasolina ' },
    });
    expect(hit.marca).toBeUndefined();
    expect(hit.cor).toBeUndefined();
    expect(hit.combustivel).toBe('Gasolina');
  });
});
