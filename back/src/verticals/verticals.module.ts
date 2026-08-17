import { Global, Module, OnModuleInit } from '@nestjs/common';
import { FeatureCatalog, VerticalRegistry } from './vertical.registry';
import { TenantFeatureRepository } from './tenant-feature.repository';
import { VocabularyService } from './vocabulary.service';
import { FeatureService } from './feature.service';

/**
 * Módulo de verticais (nicho) e funcionalidades.
 *
 * NÃO importa nenhum módulo de negócio, e isso é proposital: os dados que
 * precisaria de terceiros (`tenant.vertical` da Tenancy, módulos habilitados do
 * Billing) vêm pelo CHAMADOR. Com isso a seta de dependência aponta só para
 * cá — Tenancy → Verticals, Settings → Verticals — e não existe forwardRef.
 *
 * `@Global` para que qualquer módulo possa injetar `VocabularyService` sem
 * importar este módulo: na Fase 2 o `os` vai trocar as strings de status por
 * `vocab('os.status.*')`, e um import por módulo consumidor só geraria ruído.
 */
@Global()
@Module({
  providers: [
    VerticalRegistry,
    FeatureCatalog,
    TenantFeatureRepository,
    VocabularyService,
    FeatureService,
  ],
  exports: [VerticalRegistry, FeatureCatalog, VocabularyService, FeatureService],
})
export class VerticalsModule implements OnModuleInit {
  constructor(private readonly catalog: FeatureCatalog) {}

  /**
   * Registro provisório do catálogo de capacidades.
   *
   * O destino é cada MÓDULO declarar as suas (customers declara as de customers,
   * os declara as de os), como já acontece com a seção de configuração no
   * SettingsSectionRegistry. Isso entra na Fase 2, junto com o gate de verdade —
   * mexer nos módulos agora só para mover três linhas aumentaria o diff da Fase 1
   * sem entregar nada. Ficam aqui, visíveis, até lá.
   *
   * `requerImplementacao` fica DESMARCADO de propósito nesta fase: nenhuma
   * vertical registra implementação ainda, e marcar agora deixaria a oficina sem
   * as capacidades dela. A Fase 2 marca e registra no mesmo commit.
   */
  onModuleInit(): void {
    this.catalog.registrar({
      key: 'customers.identifierLookup',
      moduleKey: 'customers',
      nome: 'Consulta por identificador',
      descricao:
        'Consulta o identificador numa base externa e pré-preenche os atributos ' +
        '(placa na oficina, número de série na assistência técnica).',
      defaultEnabled: false,
    });
    this.catalog.registrar({
      key: 'customers.atributosCascata',
      moduleKey: 'customers',
      nome: 'Autocomplete encadeado',
      descricao: 'Sugestões em cascata, onde um campo depende do anterior (marca → modelo → ano).',
      defaultEnabled: false,
    });
    this.catalog.registrar({
      key: 'customers.fichaTecnica',
      moduleKey: 'customers',
      nome: 'Ficha técnica em PDF',
      descricao: 'Gera o dossiê do objeto com os dados técnicos consultados.',
      defaultEnabled: false,
    });
    this.catalog.registrar({
      key: 'os.trackingLink',
      moduleKey: 'os',
      nome: 'Link de acompanhamento',
      descricao: 'Link público para o cliente final acompanhar o andamento da ordem de serviço.',
      defaultEnabled: true,
    });
  }
}
