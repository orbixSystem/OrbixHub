import { plainToInstance, type ClassConstructor } from 'class-transformer';
import type { AuthUser } from '../../common/auth/auth.types';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import { OsService } from '../os/os.service';
import { MessagesService } from '../messages/messages.service';
import { CashierServiceImpl } from '../cashier/cashier.service.impl';
import { SaleService } from '../sale/sale.service';
import {
  CreateCustomerDto,
  UpdateCustomerDto,
} from '../customers/dto/customer.dto';
import {
  CreateSubjectDto,
  UpdateSubjectDto,
} from '../customers/dto/subject.dto';
import {
  CreateInventoryItemDto,
  UpdateInventoryItemDto,
} from '../inventory/dto/item.dto';
import {
  ChangeStatusDto,
  CreateOrderDto,
  UpdateOrderDto,
} from '../os/dto/order.dto';
import { CreateItemDto, UpdateItemDto } from '../os/dto/item.dto';
import { CreateNoteDto } from '../os/dto/note.dto';
import { OpenSessionDto, CloseSessionDto } from '../cashier/dto/session.dto';
import {
  CorrectEntryDto,
  CreateEntryDto,
  ReverseEntryDto,
  UpdateEntryDto,
} from '../cashier/dto/entry.dto';
import {
  CreateInstallmentPlanDto,
  PayInstallmentDto,
} from '../cashier/dto/installment.dto';
import {
  CreateExpenseTemplateDto,
  UpdateExpenseTemplateDto,
} from '../cashier/dto/expense-template.dto';
import {
  CancelSaleDto,
  CreateSaleDto,
  UpdateSaleDto,
} from '../sale/dto/sale.dto';
import { EmptyPayloadDto } from './dto/push.dto';
import { ExpensesService } from '../expenses/expenses.service';
import {
  CreateExpenseDto,
  PayExpenseDto,
  UpdateExpenseDto,
} from '../expenses/dto/expense.dto';
import {
  CreateExpenseCategoryDto,
  UpdateExpenseCategoryDto,
} from '../expenses/dto/category.dto';

/**
 * Serviços públicos dos módulos donos, injetados no `SyncService`. O `sync`
 * NUNCA toca as tabelas alheias — ele só compõe estes services ("aponta, não
 * invade"). `cashier` é a implementação concreta: o pull usa `listChangedSince`
 * (contrato) e o push usa as escritas (open/close/entry/reverse), que vivem só
 * no impl — por isso injetamos o `CashierServiceImpl` (não o token abstrato, que
 * expõe apenas leitura).
 */
export interface SyncServices {
  customers: CustomersService;
  inventory: InventoryService;
  os: OsService;
  cashier: CashierServiceImpl;
  messages: MessagesService;
  sale: SaleService;
  expenses: ExpensesService;
}

/** Payload já validado (chaves estruturais + campos do DTO). */
export type SyncPayload = Record<string, unknown>;

/**
 * Definição de UMA operação de replay (whitelist S7). O `entity.op` só é aceito
 * se estiver aqui. Payloads de update/sub-item carregam chaves estruturais
 * (`id`, `itemId`, `templateId`, `customerId`) que são extraídas ANTES da
 * validação — o resto é validado contra o DTO existente do módulo dono.
 */
export interface SyncOpDef {
  /** DTO do módulo dono, usado na 2ª passada de validação (whitelist). */
  dto: ClassConstructor<object>;
  /**
   * Chave do MÓDULO comercial dono (`module.key`) — o `/sync/*` não tem
   * `@RequiresModule` (uma rota, N entidades), então o gating de plano/assinatura
   * é feito POR ENTIDADE no service, com a MESMA régua do `ModuleAccessGuard`.
   */
  module: string;
  /** Permissão exigida — espelha o `@Permissions(...)` da rota HTTP equivalente. */
  permission: string;
  /**
   * Chaves de roteamento retiradas do payload antes de validar contra o DTO.
   * Vazio para creates cujo DTO já inclui o `id` opcional (customer/order/…).
   */
  structuralKeys?: string[];
  /**
   * Marca ops de create (uuid gerado offline, preservado no replay). Informativo:
   * a política de id já existente é `error` (S9 + isolamento de tenant exigem
   * "nunca sobrescreve"). NÃO fazemos "idempotent-recovery" convertendo id
   * duplicado em `applied` — seria indistinguível de S9 no nível do erro do banco
   * (sem autoria por linha). O caso de crash entre apply e record é raro e o
   * cliente reconcilia via pull (a linha volta na próxima página de mudanças).
   */
  create?: boolean;
  /**
   * Alvo do Last-Write-Wins: lê o `updated_at` atual via service público. Ausente
   * em ops sem alvo LWW (status, sub-itens, notas, caixa) — elas aplicam e deixam
   * a regra de negócio do service decidir.
   */
  lww?: {
    getUpdatedAt: (
      s: SyncServices,
      u: AuthUser,
      p: SyncPayload,
    ) => Promise<Date | null>;
  };
  /** Aplica a mutação chamando o service público do módulo dono. */
  apply: (
    s: SyncServices,
    u: AuthUser,
    p: SyncPayload,
  ) => Promise<{ id?: string } | null>;
}

/** Chave estrutural (id/itemId/…) → string. */
const str = (v: unknown): string => v as string;

/**
 * Reinterpreta o payload já validado como o DTO do módulo dono. Seguro: o
 * payload passou pela 2ª validação (whitelist) contra este mesmo DTO.
 */
const asDto = <T>(p: SyncPayload): T => p as unknown as T;

/** Rota de pull: módulo dono + permissão de LEITURA exigida. */
export interface PullRouteDef {
  service: keyof SyncServices;
  /** Chave do módulo comercial dono (gating de plano/assinatura — ver [SyncOpDef.module]). */
  module: string;
  /** Espelha o `@Permissions(...)` dos GETs do módulo dono. */
  permission: string;
}

/**
 * Roteamento entity → módulo dono para o pull incremental (`GET /sync/changes`).
 * Cada service valida a entity e clampa o limite internamente (A4). A permissão
 * de leitura é checada em `SyncService.getChanges` (mesma resolução do push) —
 * o pull nunca é mais permissivo que o online: sem ela, um cargo sem
 * `cashier.read` (ex.: mechanic) puxaria o extrato do caixa offline, dado que
 * as rotas GET do caixa lhe negam.
 */
export const PULL_ROUTES: Record<string, PullRouteDef> = {
  customer: { service: 'customers', module: 'customers', permission: 'customer.read' },
  subject: { service: 'customers', module: 'customers', permission: 'subject.read' },
  inventory_item: { service: 'inventory', module: 'inventory', permission: 'inventory.read' },
  stock_movement: { service: 'inventory', module: 'inventory', permission: 'inventory.read' },
  service_order: { service: 'os', module: 'os', permission: 'os.read' },
  service_order_item: { service: 'os', module: 'os', permission: 'os.read' },
  service_order_event: { service: 'os', module: 'os', permission: 'os.read' },
  service_order_photo: { service: 'os', module: 'os', permission: 'os.read' },
  service_order_template: { service: 'os', module: 'os', permission: 'os.read' },
  cash_session: { service: 'cashier', module: 'cashier', permission: 'cashier.read' },
  cash_entry: { service: 'cashier', module: 'cashier', permission: 'cashier.read' },
  cash_expense_template: {
    service: 'cashier',
    module: 'cashier',
    permission: 'cashier.read',
  },
  // Parcelamento de fiado: o balcão precisa ver/criar/quitar parcela sem rede.
  receivable_installment: {
    service: 'cashier',
    module: 'cashier',
    permission: 'cashier.read',
  },
  sale: { service: 'sale', module: 'sale', permission: 'sale.read' },
  sale_item: { service: 'sale', module: 'sale', permission: 'sale.read' },
  // Mensagens são gated pelo módulo `os` e usam `os.read` (como no messages.controller) —
  // só PULL: o histórico é sincronizado ao SQLite p/ leitura offline; enviar continua online.
  conversation: { service: 'messages', module: 'os', permission: 'os.read' },
  message: { service: 'messages', module: 'os', permission: 'os.read' },
  // Despesas: as três tabelas descem para o espelho local porque a tela abre no
  // mês e precisa dos rótulos (categoria) e da regra junto — sem elas a lista
  // offline mostraria contas sem ícone nem nome de categoria.
  expense: { service: 'expenses', module: 'expenses', permission: 'finance.read' },
  expense_category: {
    service: 'expenses',
    module: 'expenses',
    permission: 'finance.read',
  },
  expense_recurrence: {
    service: 'expenses',
    module: 'expenses',
    permission: 'finance.read',
  },
};

/**
 * Whitelist S7 de ops de push. Permissões espelham EXATAMENTE o `@Permissions`
 * da rota HTTP equivalente (o caminho offline nunca pode ser mais permissivo que
 * o online). Caixa: abrir/fechar sessão e estornar são `cashier.manage` (como no
 * controller); lançar é `cashier.write`. Nuances internas (categorias sensíveis)
 * já são checadas dentro do `CashierServiceImpl` — não duplicamos.
 */
export const SYNC_OPS: Record<string, SyncOpDef> = {
  // ---------------- customer ----------------
  'customer.create': {
    dto: CreateCustomerDto,
    module: 'customers',
    permission: 'customer.write',
    create: true,
    apply: (s, u, p) => s.customers.createCustomer(u, asDto(p)),
  },
  'customer.update': {
    dto: UpdateCustomerDto,
    module: 'customers',
    permission: 'customer.write',
    structuralKeys: ['id'],
    lww: {
      getUpdatedAt: (s, u, p) =>
        s.customers.getCustomer(u, str(p.id)).then((c) => c.updated_at ?? null),
    },
    apply: (s, u, p) =>
      s.customers.updateCustomer(u, str(p.id), asDto(p)),
  },
  'customer.archive': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.archiveCustomer(u, str(p.id)),
  },
  'customer.unarchive': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.unarchiveCustomer(u, str(p.id)),
  },
  'customer.delete': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.deleteCustomer(u, str(p.id)),
  },

  // ---------------- subject ----------------
  'subject.create': {
    dto: CreateSubjectDto,
    module: 'customers',
    permission: 'subject.write',
    create: true,
    structuralKeys: ['customerId'],
    apply: (s, u, p) =>
      s.customers.createSubject(u, str(p.customerId), asDto(p)),
  },
  'subject.update': {
    dto: UpdateSubjectDto,
    module: 'customers',
    permission: 'subject.write',
    structuralKeys: ['id'],
    lww: {
      getUpdatedAt: (s, u, p) =>
        s.customers.getSubject(u, str(p.id)).then((x) => x.updated_at ?? null),
    },
    apply: (s, u, p) =>
      s.customers.updateSubject(u, str(p.id), asDto(p)),
  },
  'subject.archive': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.archiveSubject(u, str(p.id)),
  },
  'subject.unarchive': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.unarchiveSubject(u, str(p.id)),
  },
  'subject.delete': {
    dto: EmptyPayloadDto,
    module: 'customers',
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.deleteSubject(u, str(p.id)),
  },

  // ---------------- inventory_item ----------------
  'inventory_item.create': {
    dto: CreateInventoryItemDto,
    module: 'inventory',
    permission: 'inventory.write',
    create: true,
    apply: (s, u, p) => s.inventory.createItem(u, asDto(p)),
  },
  'inventory_item.update': {
    dto: UpdateInventoryItemDto,
    module: 'inventory',
    permission: 'inventory.write',
    structuralKeys: ['id'],
    lww: {
      getUpdatedAt: (s, _u, p) =>
        s.inventory.getItemOrThrow(str(p.id)).then((x) => x.updated_at ?? null),
    },
    apply: (s, u, p) =>
      s.inventory.updateItem(u, str(p.id), asDto(p)),
  },
  'inventory_item.archive': {
    dto: EmptyPayloadDto,
    module: 'inventory',
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.archiveItem(u, str(p.id)),
  },
  'inventory_item.unarchive': {
    dto: EmptyPayloadDto,
    module: 'inventory',
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.unarchiveItem(u, str(p.id)),
  },
  'inventory_item.delete': {
    dto: EmptyPayloadDto,
    module: 'inventory',
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.deleteItem(u, str(p.id)),
  },

  // ---------------- service_order ----------------
  'service_order.create': {
    dto: CreateOrderDto,
    module: 'os',
    permission: 'os.write',
    create: true,
    apply: (s, u, p) => s.os.createOrder(u, asDto(p)),
  },
  'service_order.update': {
    dto: UpdateOrderDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id'],
    lww: {
      getUpdatedAt: (s, _u, p) =>
        s.os.getOrderOrThrow(str(p.id)).then((o) => o.updated_at ?? null),
    },
    apply: (s, u, p) => s.os.updateOrder(u, str(p.id), asDto(p)),
  },
  'service_order.changeStatus': {
    dto: ChangeStatusDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.os.changeStatus(u, str(p.id), asDto(p)),
  },
  'service_order.addItem': {
    // A OS-pai é endereçada por `orderId` — NUNCA por `id`: `CreateItemDto`
    // DECLARA um campo `id` (uuid opcional do item), e uma chave estrutural
    // homônima colidiria com ele (o `id` da OS seria sobrescrito por `undefined`
    // na 2ª validação e o item se perderia). `assertNoStructuralCollisions`
    // abaixo impede que essa classe de bug volte.
    // O uuid offline do item NÃO é preservado (o service gera o id do item e ele
    // volta no `entityId` da resposta para o cliente reconciliar).
    dto: CreateItemDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['orderId'],
    apply: (s, u, p) => s.os.addItem(u, str(p.orderId), asDto(p)),
  },
  'service_order.updateItem': {
    dto: UpdateItemDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id', 'itemId'],
    apply: (s, u, p) =>
      s.os.updateItem(u, str(p.id), str(p.itemId), asDto(p)),
  },
  'service_order.deleteItem': {
    dto: EmptyPayloadDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id', 'itemId'],
    apply: (s, u, p) => s.os.deleteItem(u, str(p.id), str(p.itemId)),
  },
  'service_order.createNote': {
    dto: CreateNoteDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.os.createNote(u, str(p.id), asDto(p)),
  },
  'service_order.applyTemplate': {
    dto: EmptyPayloadDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id', 'templateId'],
    apply: (s, u, p) => s.os.applyTemplate(u, str(p.id), str(p.templateId)),
  },

  // Declarar fiado (recebeu ZERO no caixa). Sem LWW: é um carimbo de uma via, e
  // o service ignora a segunda declaração — reenvio de push não faz estrago.
  'service_order.markFiado': {
    dto: EmptyPayloadDto,
    module: 'os',
    permission: 'os.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.os.markFiado(u, str(p.id)),
  },

  // ---------------- cash_session / cash_entry ----------------
  'cash_session.open': {
    dto: OpenSessionDto,
    module: 'cashier',
    permission: 'cashier.manage',
    create: true,
    apply: (s, u, p) => s.cashier.openSession(u, asDto(p)),
  },
  'cash_session.close': {
    dto: CloseSessionDto,
    module: 'cashier',
    permission: 'cashier.manage',
    apply: (s, u, p) => s.cashier.closeSession(u, asDto(p)),
  },
  'cash_entry.create': {
    dto: CreateEntryDto,
    module: 'cashier',
    permission: 'cashier.write',
    create: true,
    apply: (s, u, p) => s.cashier.createEntry(u, asDto(p)),
  },
  // ---------------- sale ----------------
  // Venda de balcão criada offline. O uuid vem do cliente (campo `id` do DTO —
  // por isso NÃO é chave estrutural: seria a mesma colisão de `addItem`). O
  // NÚMERO é sempre do servidor: offline o aparelho mostra um provisório
  // (`VND-P1`) e o pull traz esta linha já numerada.
  'sale.create': {
    dto: CreateSaleDto,
    module: 'sale',
    permission: 'sale.write',
    create: true,
    apply: (s, u, p) => s.sale.createSale(u, asDto(p)),
  },
  // Reatribuir o cliente da venda (o dinheiro não se edita — ver UpdateSaleDto).
  'sale.update': {
    dto: UpdateSaleDto,
    module: 'sale',
    permission: 'sale.write',
    structuralKeys: ['id'],
    lww: {
      // `getSaleWithItems` devolve a LINHA crua (com `updated_at`); o
      // `getSaleOrThrow` devolve o modelo de leitura enriquecido, sem ela.
      getUpdatedAt: (s, _u, p) =>
        s.sale.getSaleWithItems(str(p.id)).then((v) => v.updated_at ?? null),
    },
    apply: (s, u, p) => s.sale.updateSale(u, str(p.id), asDto(p)),
  },
  // Cancelar é o único "editar" do dinheiro da venda (sem LWW: quem cancelou,
  // cancelou — a regra de reentrância vive no service, que rejeita cancelar 2×).
  'sale.cancel': {
    dto: CancelSaleDto,
    module: 'sale',
    permission: 'sale.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.sale.cancelSale(u, str(p.id), asDto(p)),
  },

  // Mesmo carimbo da OS, do lado da venda de balcão.
  'sale.markFiado': {
    dto: EmptyPayloadDto,
    module: 'sale',
    permission: 'sale.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.sale.markFiado(u, str(p.id)),
  },

  // ---------------- receivable_installment (parcelamento de fiado) ----------------
  // `installmentIds` (dentro do DTO) preserva os uuids gerados offline, um por
  // parcela — mesmo espírito de `sale.create`: sem eles, reenviar o push
  // duplicaria o plano inteiro.
  'receivable_installment.create_plan': {
    dto: CreateInstallmentPlanDto,
    module: 'cashier',
    permission: 'cashier.write',
    create: true,
    apply: async (s, u, p) => {
      await s.cashier.createInstallmentPlan(u, asDto(p));
      // `createMany` não devolve linha; o contrato do registry espera
      // `{id?} | null` (mesmo caso de `expense.cancel`).
      return null;
    },
  },
  // Quitar espelha um lançamento no caixa — `cashEntryId` (dentro do DTO) evita
  // duplicar o lançamento no replay, mesmo idioma de `expense.pay`.
  'receivable_installment.pay': {
    dto: PayInstallmentDto,
    module: 'cashier',
    permission: 'cashier.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.payInstallment(u, str(p.id), asDto(p)),
  },
  'cash_entry.reverse': {
    dto: ReverseEntryDto,
    module: 'cashier',
    permission: 'cashier.manage',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.reverseEntry(u, str(p.id), asDto(p)),
  },
  // Editar o TEXTO do lançamento (descrição/categoria de mesma direção). Sem
  // LWW: o alvo é campo livre e a última edição do operador é a que vale.
  'cash_entry.update': {
    dto: UpdateEntryDto,
    module: 'cashier',
    permission: 'cashier.manage',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.updateEntry(u, str(p.id), asDto(p)),
  },
  // Corrigir o VALOR: estorna e relança. `newId` (uuid do lançamento novo, gerado
  // offline) viaja NO DTO — não é chave estrutural, e por isso não colide com o
  // `id` do original, que é.
  'cash_entry.correct': {
    dto: CorrectEntryDto,
    module: 'cashier',
    permission: 'cashier.manage',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.correctEntry(u, str(p.id), asDto(p)),
  },
  // ---------------- despesas fixas (modelos) ----------------
  // Cadastrar o atalho offline importa: quem está sem rede é quem mais precisa
  // lançar rápido, e o modelo é só um preset — nada de dinheiro viaja aqui.
  // `id` está DENTRO do DTO (não é chave estrutural) para o replay preservar o
  // uuid gerado no cliente, como em `cash_entry.create`.
  'cash_expense_template.create': {
    dto: CreateExpenseTemplateDto,
    module: 'cashier',
    permission: 'cashier.manage',
    create: true,
    apply: (s, u, p) => s.cashier.createExpenseTemplate(u, asDto(p)),
  },
  'cash_expense_template.update': {
    dto: UpdateExpenseTemplateDto,
    module: 'cashier',
    permission: 'cashier.manage',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.updateExpenseTemplate(u, str(p.id), asDto(p)),
  },
  // ---------------- despesas (contas a pagar) ----------------
  // Cadastrar e dar baixa offline importa: a cliente confere as contas do mês
  // onde estiver, não só com rede.
  //
  // `expense.create` leva o `id` DENTRO do DTO (não como chave estrutural) para
  // o replay preservar o uuid gerado no cliente — mesma razão de
  // `cash_entry.create`, e é o que impede a conta de duplicar se o push repetir.
  'expense.create': {
    dto: CreateExpenseDto,
    module: 'expenses',
    permission: 'finance.write',
    create: true,
    apply: (s, u, p) => s.expenses.create(u, asDto(p)),
  },
  'expense.update': {
    dto: UpdateExpenseDto,
    module: 'expenses',
    permission: 'finance.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.expenses.update(u, str(p.id), asDto(p)),
  },
  // A baixa espelha um lançamento no caixa. O `cashEntryId` viaja no payload
  // justamente para o replay NÃO criar um segundo lançamento: o caixa recebe o
  // mesmo uuid e rejeita o duplicado.
  'expense.pay': {
    dto: PayExpenseDto,
    module: 'expenses',
    permission: 'finance.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.expenses.pay(u, str(p.id), asDto(p)),
  },
  'expense.unpay': {
    dto: EmptyPayloadDto,
    module: 'expenses',
    permission: 'finance.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.expenses.unpay(u, str(p.id)),
  },
  'expense.cancel': {
    dto: EmptyPayloadDto,
    module: 'expenses',
    permission: 'finance.write',
    structuralKeys: ['id'],
    apply: async (s, u, p) => {
      await s.expenses.cancel(u, str(p.id));
      // `cancel` não devolve linha; o contrato do registry espera `{id?} | null`.
      return null;
    },
  },
  'expense_category.create': {
    dto: CreateExpenseCategoryDto,
    module: 'expenses',
    permission: 'finance.write',
    create: true,
    apply: (s, u, p) => s.expenses.createCategory(u, asDto(p)),
  },
  'expense_category.update': {
    dto: UpdateExpenseCategoryDto,
    module: 'expenses',
    permission: 'finance.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.expenses.updateCategory(u, str(p.id), asDto(p)),
  },
};

/**
 * Invariante do registry: NENHUMA chave estrutural pode ter o mesmo nome de um
 * campo DECLARADO no DTO daquela op.
 *
 * Por quê: `plainToInstance(dto, rest)` materializa TODOS os campos declarados
 * do DTO como propriedades próprias (`undefined` quando ausentes). Se uma chave
 * estrutural colidir com uma delas, o valor de roteamento (o id da OS-pai, por
 * exemplo) é apagado — foi exatamente assim que `service_order.addItem`
 * (estrutural `id` × `CreateItemDto.id`) perdia TODO item adicionado offline.
 * O `validatePayload` hoje aplica as estruturais POR ÚLTIMO (roteamento sempre
 * vence), e esta asserção — executada no load do módulo — impede que a colisão
 * seja reintroduzida.
 */
export function structuralCollisions(): string[] {
  const found: string[] = [];
  for (const [key, def] of Object.entries(SYNC_OPS)) {
    if (!def.structuralKeys?.length) continue;
    // Campos declarados do DTO = as chaves que o plainToInstance materializa.
    const declared = new Set(Object.keys(plainToInstance(def.dto, {})));
    for (const sk of def.structuralKeys) {
      if (declared.has(sk)) found.push(`${key}.${sk}`);
    }
  }
  return found;
}

const collisions = structuralCollisions();
if (collisions.length) {
  throw new Error(
    `sync.registry: chave estrutural colide com campo do DTO: ${collisions.join(', ')}`,
  );
}
