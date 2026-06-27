import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { InventoryModule } from '../inventory/inventory.module';
import { CustomersModule } from '../customers/customers.module';
import { IamModule } from '../iam/iam.module';
import { ReportController } from './report.controller';
import { ReportService } from './report.service';

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
    IamModule,
  ],
  controllers: [ReportController],
  providers: [ReportService],
})
export class ReportModule {}
