import type { PacoteVertical } from '../vertical.types';

/**
 * Pacote PADRÃO — vocabulário neutro, serve qualquer nicho de serviço
 * (assistência técnica, manutenção, conserto de equipamento).
 *
 * É o único pacote que traz o vocabulário COMPLETO: os demais declaram só o que
 * diferem e caem aqui no resto. Seis cópias do mesmo texto em pacotes diferentes
 * divergiriam com o tempo — aqui existe uma fonte só.
 *
 * `tenant.vertical` nulo resolve neste pacote (isDefault).
 */
export const EQUIPAMENTOS: PacoteVertical = {
  key: 'equipamentos',
  nome: 'Equipamentos e serviços',
  isDefault: true,

  vocab: {
    // O "objeto" é a entidade `subject`: o que entra pra ser atendido.
    'objeto.singular': 'Equipamento',
    'objeto.plural': 'Equipamentos',
    'objeto.identificador': 'Identificação',
    // Nome do ÍCONE, não o ícone: o backend guarda a escolha e a UI mapeia —
    // mesmo padrão do tema. Um carro desenhado na tela de uma clínica é tão
    // errado quanto a palavra "Veículo".
    'objeto.icone': 'objeto',

    // Status da OS. Seis destes já eram genéricos no código; só `entregue`
    // falava de carro (era 'Veículo entregue' em os.service e os-public.service).
    'os.status.aberta': 'OS aberta',
    'os.status.aguardando_aprovacao': 'Aguardando aprovação',
    'os.status.aprovada': 'Orçamento aprovado',
    'os.status.em_execucao': 'Em execução',
    'os.status.concluida': 'Serviço concluído',
    'os.status.entregue': 'Serviço entregue',
    'os.status.cancelada': 'OS cancelada',
  },

  subjectFields: [
    { chave: 'identifier', rotulo: 'Identificação', tipo: 'text', obrigatorio: false },
    { chave: 'descricao', rotulo: 'Descrição', tipo: 'text', obrigatorio: false },
  ],

  // Só o que serve qualquer nicho. Consulta em base externa e ficha técnica
  // dependem de um provedor que o genérico não tem.
  featuresLigadas: ['os.trackingLink'],
};
