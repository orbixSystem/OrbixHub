import { Module } from '@nestjs/common';
import { CashierModule } from '../cashier/cashier.module';
import { ExpenseRecurrenceJob } from './expense-recurrence.job';
import { ExpensesController } from './expenses.controller';
import { ExpensesRepository } from './expenses.repository';
import { ExpensesService } from './expenses.service';

/**
 * Módulo Despesas (contas a pagar / lembrete de pagamento). Contratável — gated
 * por `@RequiresModule('expenses')`.
 *
 * Importa o `CashierModule` para consumir o token abstrato `CashierService`
 * (porta pública). Dar baixa numa despesa registra a saída no livro caixa e
 * guarda só o `cash_entry_id` — este módulo nunca toca `cash_entry`, e o caixa
 * não sabe o que é uma conta a pagar ("aponta, não invade").
 */
@Module({
  imports: [CashierModule],
  controllers: [ExpensesController],
  providers: [ExpensesRepository, ExpensesService, ExpenseRecurrenceJob],
  exports: [ExpensesService],
})
export class ExpensesModule {}
