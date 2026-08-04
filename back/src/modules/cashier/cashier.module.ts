import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { CashierController } from './cashier.controller';
import { CashierService } from './cashier.service';
import { CashierServiceImpl } from './cashier.service.impl';
import { CashierRepository } from './cashier.repository';
import { CASHIER_CONFIG_KEY } from './cashier.config';

/**
 * Módulo Caixa (Caixa do dia + extrato/livro caixa). Registrador de dinheiro e
 * fonte do status de pagamento das vendas — a OS/vendas perguntam aqui pelo
 * contrato `CashierService` ("aponta, não invade": a venda passa o próprio total,
 * o caixa só sabe o que recebeu). Contratável (gated por @RequiresModule('cashier')).
 *
 * O token `CashierService` (contrato congelado, 2 métodos) resolve para a
 * implementação real via `useExisting` — a mesma instância serve o controller
 * (que precisa das operações completas) e a OS (que só vê o contrato).
 */
@Module({
  imports: [BillingModule, SettingsModule],
  controllers: [CashierController],
  providers: [
    CashierRepository,
    CashierServiceImpl,
    { provide: CashierService, useExisting: CashierServiceImpl },
  ],
  // CashierService (contrato/leitura) é consumido pela OS ("aponta, não invade").
  // CashierServiceImpl é exportado a MAIS para o módulo `sync`: o replay offline
  // precisa das ESCRITAS (open/close/entry/reverse), que vivem só no impl — o
  // contrato abstrato expõe apenas leitura. Sync compõe o service público; nunca
  // toca as tabelas do caixa.
  exports: [CashierService, CashierServiceImpl],
})
export class CashierModule implements OnModuleInit {
  constructor(
    private readonly registry: SettingsSectionRegistry,
    private readonly cashier: CashierServiceImpl,
  ) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings só se o módulo `cashier` estiver habilitado.
    this.registry.register({
      key: CASHIER_CONFIG_KEY,
      title: 'Caixa',
      moduleKey: 'cashier',
      // Seção sem campos: os dois toggles que existiam aqui ("Exigir caixa
      // aberto" e "Conferir só dinheiro no fechamento") descreviam a cerimônia de
      // abrir/fechar, que foi REMOVIDA do produto. Um toggle que o backend
      // normaliza, ou que fala de um fechamento que o usuário nunca vê, é pior
      // que nenhum. As chaves seguem na config interna (o cálculo do esperado usa
      // `countCashOnly`), só deixaram de ser administráveis.
      fields: [
      ],
      // Sem `getValues` a seção era exibida com os valores VAZIOS: o toggle
      // aparecia desligado mesmo com a exigência ligada no tenant.
      getValues: async (tenantId) => {
        const cfg = await this.cashier.getConfig(tenantId);
        return {
          requireOpenSession: cfg.requireOpenSession,
          countCashOnly: cfg.countCashOnly,
        };
      },
      // Contraparte de escrita: o host encaminha o patch e QUEM valida/persiste é
      // o caixa (o `settings` não conhece a config dele).
      setValues: async (user, patch) => {
        const cfg = await this.cashier.updateConfig(user, {
          requireOpenSession: patch.requireOpenSession as boolean | undefined,
          countCashOnly: patch.countCashOnly as boolean | undefined,
        });
        return {
          requireOpenSession: cfg.requireOpenSession,
          countCashOnly: cfg.countCashOnly,
        };
      },
    });
  }
}
