/**
 * Tipos do catálogo de verticais (nicho) e de funcionalidades.
 *
 * Design: docs/superpowers/specs/2026-08-17-verticais-nicho-features-design.md
 *
 * DOIS EIXOS ORTOGONAIS:
 *  - NICHO manda só no VOCABULÁRIO (rótulos, campos do formulário, textos de
 *    status). Um tenant tem um nicho; ele NÃO decide comportamento.
 *  - FUNCIONALIDADE é capacidade que liga/desliga POR MÓDULO, independente do
 *    nicho. A prova de que precisam ser eixos separados: a consulta do
 *    identificador numa base externa serve oficina E assistência de câmera, mas
 *    não serve fisioterapia — não é função do nicho.
 *
 * O catálogo mora AQUI, no código, e não no banco: ele só muda com deploy
 * (capacidade nova = código novo), então em tabela cada texto novo viraria uma
 * migration em vez de um objeto com type-check e teste. O que vai pro banco é
 * só o ESTADO do tenant: `tenant.vertical` e `tenant_feature`.
 */

/** Tipo de campo do formulário do subject (espelha SubjectFieldType). */
export type CampoTipo = 'text' | 'number';

/** Campo do formulário do subject, declarado pelo pacote da vertical. */
export interface CampoVertical {
  chave: string;
  rotulo: string;
  tipo: CampoTipo;
  obrigatorio: boolean;
  /** Fonte de autocomplete (ex.: 'fipe.marcas'). Ausente = campo manual. */
  fonte?: string;
  /** Chave do campo do qual este depende na cascata (ex.: modelo→'marca'). */
  dependeDe?: string;
}

/**
 * Pacote de uma vertical. Só o pacote PADRÃO precisa trazer o vocabulário
 * completo; os demais declaram apenas o que DIFEREM dele — chave ausente cai no
 * padrão. Isso evita seis cópias do mesmo texto divergindo com o tempo.
 */
export interface PacoteVertical {
  key: string;
  nome: string;
  /** Exatamente um pacote é o padrão; `tenant.vertical` nulo resolve nele. */
  isDefault?: boolean;
  /** Textos por chave (ex.: 'objeto.singular'). */
  vocab: Record<string, string>;
  /**
   * Campos do formulário do subject. Substituição INTEIRA, não merge por chave:
   * um formulário é uma lista ordenada, não um conjunto de propriedades.
   * Ausente = herda do pacote padrão.
   */
  subjectFields?: CampoVertical[];
  /** Capacidades que este nicho liga por padrão (chaves do FeatureCatalog). */
  featuresLigadas: string[];
}

/**
 * Capacidade genérica declarada por um MÓDULO. O módulo nunca menciona nicho —
 * quem diz "no meu nicho isso vem ligado" é o pacote da vertical, em
 * `featuresLigadas`. É o que permite a mesma capacidade servir dois nichos e
 * faltar num terceiro sem nenhum `if` de vertical no código.
 */
export interface DefinicaoFeature {
  /** Namespaced pelo módulo dono: 'customers.identifierLookup'. */
  key: string;
  /** Módulo dono — a feature morre junto se o módulo estiver desabilitado. */
  moduleKey: string;
  nome: string;
  descricao: string;
  /**
   * Valor quando nem o tenant nem o pacote da vertical se manifestaram.
   * Último recurso da cascata, não o caminho normal.
   */
  defaultEnabled: boolean;
  /**
   * Capacidade que só existe se ALGUMA vertical registrar implementação para o
   * nicho do tenant (ex.: consultar o identificador exige um provedor externo —
   * placa na oficina, número de série na assistência). Sem implementação a
   * capacidade fica INDISPONÍVEL: não aparece nem como toggle, e ligar não
   * adianta. É trava estrutural, não `if` de nicho.
   *
   * Fase 1 declara as capacidades sem esta marca; ela é ligada na Fase 2, junto
   * com o registro das implementações — assim o fasear é dado, não código.
   */
  requerImplementacao?: boolean;
}
