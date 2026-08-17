import { Injectable } from '@nestjs/common';

/** Opção devolvida ao front: `value` (texto salvo), `label` (exibido), `meta`. */
export interface LookupOption {
  value: string;
  label: string;
  meta?: Record<string, unknown>;
}

/**
 * Fonte de autocomplete para um campo de subject.
 *
 * O módulo `customers` conhece o CONCEITO de fonte, nunca a fonte em si: quem
 * sabe o que é FIPE é a vertical veículos, que registra as dela aqui. Antes
 * disso, `SubjectLookupService` tinha um `SOURCES = new Set(['fipe.marcas', …])`
 * cravado — casca de oficina dentro do módulo que deveria ser genérico.
 */
export interface LookupSource {
  /** Chave usada no `fonte` do campo (ex.: 'fipe.marcas'). */
  key: string;
  /**
   * Chaves dos ancestrais da cascata que precisam estar preenchidos. Sem eles a
   * busca nem sai — 'fipe.modelos' sem marca não tem o que sugerir.
   */
  requer?: Array<'marca' | 'modelo'>;
  /** Busca as opções. Pode fazer I/O externo; o cache é do service. */
  buscar(params: { marca?: string; modelo?: string }): Promise<LookupOption[]>;
}

/**
 * Registro aberto de fontes. Uma vertical registra as suas em `onModuleInit`;
 * módulo genérico nenhum precisa mudar quando um nicho novo entra.
 */
@Injectable()
export class SubjectLookupRegistry {
  private readonly sources = new Map<string, LookupSource>();

  registrar(source: LookupSource): void {
    this.sources.set(source.key, source);
  }

  achar(key: string): LookupSource | null {
    return this.sources.get(key) ?? null;
  }

  chaves(): string[] {
    return [...this.sources.keys()];
  }
}
