import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { SaleModule } from '../sale/sale.module';
import { ReceivablesController } from './receivables.controller';
import { ReceivablesService } from './receivables.service';

/**
 * Módulo Fiado / contas a receber — ORQUESTRADOR puro: nenhuma tabela própria,
 * nenhuma migration, nenhuma permissão nova.
 *
 * Compõe os services públicos de OS e Vendas (que já derivam o pagamento do
 * caixa em batch) e agrupa a dívida por cliente. Não importa `CashierModule`
 * porque não precisa: quem sabe o total é o dono da venda, e ele já pergunta ao
 * caixa. Do ponto de vista comercial é parte do Caixa, então é gated por
 * `@RequiresModule('cashier')` + `cashier.read`.
 *
 * A DIREÇÃO das dependências importa: OS e Vendas já dependem do Cashier, então
 * este módulo tinha de ficar FORA dele — colocar a orquestração no `cashier`
 * criaria um ciclo cashier↔os/sale. Mesmo desenho do módulo `sync`.
 */
@Module({
  imports: [BillingModule, OsModule, SaleModule],
  controllers: [ReceivablesController],
  providers: [ReceivablesService],
  exports: [ReceivablesService],
})
export class ReceivablesModule {}
