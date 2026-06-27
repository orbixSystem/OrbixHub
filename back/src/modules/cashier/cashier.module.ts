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
  exports: [CashierService],
})
export class CashierModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings só se o módulo `cashier` estiver habilitado.
    this.registry.register({
      key: CASHIER_CONFIG_KEY,
      title: 'Caixa',
      moduleKey: 'cashier',
      fields: [
        {
          key: 'requireOpenSession',
          label: 'Exigir caixa aberto para lançar',
          type: 'bool',
        },
        {
          key: 'countCashOnly',
          label: 'Conferir só dinheiro no fechamento',
          type: 'bool',
        },
      ],
    });
  }
}
