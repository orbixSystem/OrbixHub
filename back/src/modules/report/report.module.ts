import { Module } from '@nestjs/common';
import { AI_TEXT_GATEWAY } from '../../common/ai/ai-text.gateway';
import { GeminiTextGateway } from '../../common/ai/gemini-text.gateway';
import { NotificationsModule } from '../notifications/notifications.module';
import { ReceivablesModule } from '../receivables/receivables.module';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { InventoryModule } from '../inventory/inventory.module';
import { CustomersModule } from '../customers/customers.module';
import { CashierModule } from '../cashier/cashier.module';
import { ExpensesModule } from '../expenses/expenses.module';
import { SaleModule } from '../sale/sale.module';
import { IamModule } from '../iam/iam.module';
import { ReportController } from './report.controller';
import { ReportService } from './report.service';
import { MonthlyAggregatesService } from './monthly/monthly-aggregates.service';
import { MonthlySummaryJob } from './monthly/monthly-summary.job';
import { MonthlySummaryNotifier } from './monthly/monthly-summary.notifier';
import { MonthlySummaryRepository } from './monthly/monthly-summary.repository';
import { MonthlySummaryService } from './monthly/monthly-summary.service';

/**
 * Módulo `report` — relatórios contratáveis (gated por @RequiresModule('report')).
 * SEM tabela nova: compõe on-the-fly chamando os services públicos exportados por
 * OsModule/InventoryModule/CustomersModule (regra "aponta, não invade" — nenhum
 * repository/Prisma aqui). Importa BillingModule (ModuleAccessGuard +
 * getEnabledModules para decidir quais relatórios servir).
 */
@Module({
  imports: [
    BillingModule,
    OsModule,
    InventoryModule,
    CustomersModule,
    CashierModule,
    ExpensesModule,
    SaleModule,
    IamModule,
    NotificationsModule,
    ReceivablesModule,
  ],
  controllers: [ReportController],
  providers: [
    ReportService,
    MonthlyAggregatesService,
    MonthlySummaryService,
    MonthlySummaryRepository,
    MonthlySummaryNotifier,
    MonthlySummaryJob,
    // Gateway de IA: o Gemini já resolve sozinho a ausência de chave caindo no
    // texto determinístico, então não há dois providers a escolher aqui —
    // haveria duas maneiras de o sistema ficar sem IA, e uma delas passaria
    // despercebida.
    { provide: AI_TEXT_GATEWAY, useClass: GeminiTextGateway },
  ],
  // Só o job sai daqui, e só para o gatilho administrativo
  // (`POST /admin/report/monthly/run`) poder chamá-lo fora do dia 1º.
  // O resto fica dentro: quem quiser um relatório pede pela rota, não
  // injetando o service de outro módulo.
  exports: [MonthlySummaryJob],
})
export class ReportModule {}
