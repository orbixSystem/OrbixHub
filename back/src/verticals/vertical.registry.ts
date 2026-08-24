import { Injectable } from '@nestjs/common';
import type { DefinicaoFeature, PacoteVertical } from './vertical.types';
import { EQUIPAMENTOS } from './packs/equipamentos.pack';
import { VEICULOS } from './packs/veiculos.pack';

/**
 * Catálogo de verticais. Os pacotes embutidos são registrados na construção; a
 * Fase 2 acrescenta `registrarImplementacao` a partir de cada pasta
 * `verticals/<key>/`, sem que módulo genérico nenhum precise mudar.
 */
@Injectable()
export class VerticalRegistry {
  private readonly packs = new Map<string, PacoteVertical>();
  /**
   * Capacidade → verticais que a implementam.
   *
   * É um mapa, e não um conjunto de chaves, porque implementação PERTENCE a um
   * nicho. Guardar só a chave tornava a capacidade disponível para todo mundo
   * assim que qualquer vertical a registrasse: bastava a pasta `veiculos/`
   * existir no processo para a clínica poder ligar consulta de placa.
   */
  private readonly implementacoes = new Map<string, Set<string>>();

  constructor() {
    for (const p of [EQUIPAMENTOS, VEICULOS]) this.registrar(p);
  }

  registrar(pacote: PacoteVertical): void {
    this.packs.set(pacote.key, pacote);
  }

  /**
   * Declara que existe implementação para uma capacidade (ex.: a vertical
   * veículos registrando o enricher de placa). Sem isso, capacidade marcada com
   * `requerImplementacao` fica indisponível — é a trava estrutural que impede a
   * clínica de ligar a consulta por placa.
   */
  registrarImplementacao(featureKey: string, verticalKey: string): void {
    const verticais = this.implementacoes.get(featureKey) ?? new Set<string>();
    verticais.add(verticalKey);
    this.implementacoes.set(featureKey, verticais);
  }

  comImplementacao(): ReadonlyMap<string, ReadonlySet<string>> {
    return this.implementacoes;
  }

  /** Nicho de quem foi criado sem escolher um. */
  chavePadrao(): string | null {
    return this.pacotes().find((p) => p.isDefault)?.key ?? null;
  }

  pacotes(): PacoteVertical[] {
    return [...this.packs.values()];
  }

  /** Chave válida? Usado para recusar escrita de vertical inexistente. */
  existe(key: string): boolean {
    return this.packs.has(key);
  }

  /** Lista para a tela de cadastro (`GET /verticals`) — nada hardcoded no front. */
  listar(): Array<{ key: string; nome: string; isDefault: boolean }> {
    return this.pacotes().map((p) => ({
      key: p.key,
      nome: p.nome,
      isDefault: p.isDefault === true,
    }));
  }
}

/**
 * Catálogo de capacidades. Cada MÓDULO registra as suas em `onModuleInit` — e
 * nunca menciona nicho. Quem diz "no meu nicho isso vem ligado" é o pacote da
 * vertical, via `featuresLigadas`. É o que permite a mesma capacidade servir
 * oficina e assistência de câmera, e faltar na fisioterapia, sem `if` de nicho.
 */
@Injectable()
export class FeatureCatalog {
  private readonly defs = new Map<string, DefinicaoFeature>();

  registrar(def: DefinicaoFeature): void {
    this.defs.set(def.key, def);
  }

  todas(): DefinicaoFeature[] {
    return [...this.defs.values()];
  }

  achar(key: string): DefinicaoFeature | null {
    return this.defs.get(key) ?? null;
  }
}
