import { Inject, Module, OnModuleInit } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { BillingModule } from '../../modules/billing/billing.module';
import { CustomersModule } from '../../modules/customers/customers.module';
import { SubjectLookupRegistry } from '../../modules/customers/subject-lookup.registry';
import { VerticalRegistry } from '../vertical.registry';
import { FIPE_CLIENT, HttpFipeClient, brandLogoUrl, type FipeClient } from './fipe.client';
import { NoopPlateProvider, PLATE_PROVIDER } from './plates/plate.provider';
import { WdapiPlateProvider } from './plates/wdapi-plate.provider';
import { PlateCacheStore } from './plates/plate-cache.store';
import { PlateQuotaStore } from './plates/plate-quota.store';
import { PlateLookupService } from './plates/plate-lookup.service';
import { PlateFipeMatcher } from './plates/plate-fipe-matcher.service';
import { PlatesController } from './plates/plates.controller';

/**
 * VERTICAL OFICINA / VEÍCULOS — toda a casca de carro do backend.
 *
 * A seta aponta numa direção só: esta pasta importa `customers` para se
 * registrar nos pontos de extensão dele; `customers` NÃO importa nada daqui e
 * não sabe que veículo existe. Vertical nova = pasta nova, sem tocar no
 * genérico.
 *
 * Aqui moram: o cliente FIPE, a consulta de placa (WDAPI + cache + cota) e o
 * registro das fontes de autocomplete. Antes tudo isso vivia dentro do módulo
 * `customers`, que se dizia genérico.
 */
@Module({
  imports: [BillingModule, CustomersModule],
  controllers: [PlatesController],
  providers: [
    { provide: FIPE_CLIENT, useFactory: () => new HttpFipeClient() },
    PlateCacheStore,
    PlateQuotaStore,
    PlateFipeMatcher,
    PlateLookupService,
    // Provider real só quando habilitado por env (senão Noop — nunca chama fora).
    {
      provide: PLATE_PROVIDER,
      inject: [ENV],
      useFactory: (env: Env) =>
        env.PLACAS_ENABLED && env.PLACAS_TOKEN
          ? new WdapiPlateProvider(env)
          : new NoopPlateProvider(),
    },
  ],
  exports: [PlateLookupService],
})
export class VeiculosVerticalModule implements OnModuleInit {
  constructor(
    private readonly lookups: SubjectLookupRegistry,
    private readonly verticais: VerticalRegistry,
    @Inject(FIPE_CLIENT) private readonly fipe: FipeClient,
  ) {}

  onModuleInit(): void {
    this.registrarFontesFipe();
    this.registrarImplementacoes();
  }

  /**
   * Fontes de autocomplete da cascata marca → modelo → ano. Ficavam num
   * `SOURCES = new Set([...])` cravado dentro do `SubjectLookupService`; agora
   * são registradas aqui, e o service genérico só sabe cachear e filtrar.
   */
  private registrarFontesFipe(): void {
    this.lookups.registrar({
      key: 'fipe.marcas',
      buscar: async () =>
        (await this.fipe.brands()).map((b) => ({
          value: b.name,
          label: b.name,
          meta: { codigo: b.code, logoUrl: brandLogoUrl(b.name) },
        })),
    });

    this.lookups.registrar({
      key: 'fipe.modelos',
      requer: ['marca'],
      buscar: async ({ marca }) =>
        (await this.fipe.models(marca as string)).map((m) => ({
          value: m.name,
          label: m.name,
          meta: { codigo: m.code },
        })),
    });

    this.lookups.registrar({
      key: 'fipe.anos',
      requer: ['marca', 'modelo'],
      // A FIPE devolve "2024 Gasolina" / "32000 Gasolina" (zero km). Mostramos só
      // o ano, deduplicado entre combustíveis; 32000 vira "0 km".
      buscar: async ({ marca, modelo }) => {
        const seen = new Set<string>();
        const out = [];
        for (const y of await this.fipe.years(marca as string, modelo as string)) {
          const head = y.name.split(' ')[0];
          const label = head === '32000' ? '0 km' : head;
          if (seen.has(label)) continue;
          seen.add(label);
          out.push({ value: label, label });
        }
        return out;
      },
    });
  }

  /**
   * Declara que ESTA vertical implementa as capacidades marcadas com
   * `requerImplementacao`. Sem este registro elas ficam indisponíveis — é o que
   * impede um tenant de nicho genérico ligar a consulta por placa: não existe
   * base externa para o objeto dele, e ligar não faria efeito nenhum.
   */
  private registrarImplementacoes(): void {
    this.verticais.registrarImplementacao('customers.identifierLookup');
    this.verticais.registrarImplementacao('customers.atributosCascata');
    this.verticais.registrarImplementacao('customers.fichaTecnica');
  }
}
