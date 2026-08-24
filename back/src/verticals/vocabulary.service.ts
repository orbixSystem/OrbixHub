import { Injectable } from '@nestjs/common';
import { VerticalRegistry } from './vertical.registry';
import { resolverCampos, resolverVocab } from './vertical.resolve';
import type { CampoVertical } from './vertical.types';

/**
 * Vocabulário efetivo de um tenant.
 *
 * O CHAMADOR passa `verticalKey` e os overrides. Não é preguiça: é o que evita
 * a dependência circular com a Tenancy (que é dona da tabela `tenant` e monta o
 * /me). A Tenancy já carregou o tenant quando chama aqui, então passar o dado
 * sai de graça — mesmo padrão do módulo `sale`, que recebe o total do chamador
 * em vez de abrir forwardRef.
 */
@Injectable()
export class VocabularyService {
  constructor(private readonly registry: VerticalRegistry) {}

  /** Mapa completo de textos — é o `vocab` do /me. */
  vocab(
    verticalKey: string | null | undefined,
    overrides?: Record<string, unknown> | null,
  ): Record<string, string> {
    return resolverVocab(this.registry.pacotes(), verticalKey, overrides);
  }

  /**
   * Um texto por chave, para uso no servidor (rótulo de status em e-mail, PDF e
   * tela pública). Chave desconhecida devolve `undefined` — quem chama decide o
   * fallback, em vez de a gente inventar um texto errado.
   */
  texto(
    verticalKey: string | null | undefined,
    chave: string,
    overrides?: Record<string, unknown> | null,
  ): string | undefined {
    return this.vocab(verticalKey, overrides)[chave];
  }

  /** Campos do formulário do subject para o nicho. */
  campos(verticalKey: string | null | undefined): CampoVertical[] {
    return resolverCampos(this.registry.pacotes(), verticalKey);
  }
}
