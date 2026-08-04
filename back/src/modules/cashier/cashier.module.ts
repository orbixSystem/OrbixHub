import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CashierController } from './cashier.controller';
import { CashierService } from './cashier.service';
import { CashierServiceImpl } from './cashier.service.impl';
import { CashierRepository } from './cashier.repository';

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
  imports: [BillingModule],
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
/// O módulo NÃO registra seção em Configurações.
///
/// Ele tinha uma ("Caixa", com "Exigir caixa aberto" e "Conferir só dinheiro no
/// fechamento"), mas os dois campos descreviam a cerimônia de abrir/fechar, que
/// foi REMOVIDA do produto. Sem campos, a seção virava um cartão vazio na tela —
/// pior que não existir. As chaves seguem na config interna do módulo
/// (`cashier.config.ts`, lida por `GET /cashier/config`); elas apenas deixaram de
/// ser administráveis pelo usuário.
export class CashierModule {}
