import type { PacoteVertical } from '../vertical.types';

/**
 * Pacote da vertical OFICINA / VEÍCULOS.
 *
 * `vocab` traz SÓ o que difere do pacote padrão — chave ausente cai nele. Por
 * isso aqui aparecem quatro chaves e não onze: dos sete status da OS, só
 * `entregue` falava de carro.
 *
 * `subjectFields` reproduz, campo a campo, o `DEFAULT_CUSTOMERS_CONFIG` que
 * está hoje em customers.config.ts. Isso não é coincidência nem cópia
 * descuidada: é o critério de aceite da migração — os 6 tenants de produção são
 * todos oficina e não podem ver NENHUMA diferença. O teste
 * `veiculos.pack.spec.ts` trava essa igualdade.
 */
export const VEICULOS: PacoteVertical = {
  key: 'veiculos',
  nome: 'Oficina / veículos',

  vocab: {
    'objeto.singular': 'Veículo',
    'objeto.plural': 'Veículos',
    'objeto.identificador': 'Placa',
    // Nome do ÍCONE, não o ícone: o backend guarda a escolha e a UI mapeia —
    // mesmo padrão do tema. Um carro desenhado na tela de uma clínica é tão
    // errado quanto a palavra "Veículo".
    'objeto.icone': 'veiculo',
    'os.status.entregue': 'Veículo entregue',

    // Hints contextuais para formulários de OS
    'objeto.fallback_titulo': 'Veículo',
    'os.hint.fotos': 'Registre o estado do veículo na entrada.',
    'os.hint.template': 'ex.: Revisão simples',
  },

  subjectFields: [
    { chave: 'identifier', rotulo: 'Placa', tipo: 'text', obrigatorio: true },
    { chave: 'marca', rotulo: 'Marca', tipo: 'text', obrigatorio: false, fonte: 'fipe.marcas' },
    { chave: 'modelo', rotulo: 'Modelo', tipo: 'text', obrigatorio: false, fonte: 'fipe.modelos', dependeDe: 'marca' },
    { chave: 'ano', rotulo: 'Ano', tipo: 'number', obrigatorio: false, fonte: 'fipe.anos', dependeDe: 'modelo' },
    { chave: 'cor', rotulo: 'Cor', tipo: 'text', obrigatorio: false },
    { chave: 'km', rotulo: 'KM', tipo: 'number', obrigatorio: false },
  ],

  featuresLigadas: [
    'os.trackingLink',
    'customers.identifierLookup',
    'customers.atributosCascata',
    'customers.fichaTecnica',
  ],
};
