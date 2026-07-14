import { plainToInstance, type ClassConstructor } from 'class-transformer';
import type { AuthUser } from '../../common/auth/auth.types';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import { OsService } from '../os/os.service';
import { CashierServiceImpl } from '../cashier/cashier.service.impl';
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
import { CreateEntryDto, ReverseEntryDto } from '../cashier/dto/entry.dto';
import { EmptyPayloadDto } from './dto/push.dto';

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
  customer: { service: 'customers', permission: 'customer.read' },
  subject: { service: 'customers', permission: 'subject.read' },
  inventory_item: { service: 'inventory', permission: 'inventory.read' },
  stock_movement: { service: 'inventory', permission: 'inventory.read' },
  service_order: { service: 'os', permission: 'os.read' },
  service_order_item: { service: 'os', permission: 'os.read' },
  service_order_event: { service: 'os', permission: 'os.read' },
  service_order_photo: { service: 'os', permission: 'os.read' },
  service_order_template: { service: 'os', permission: 'os.read' },
  cash_session: { service: 'cashier', permission: 'cashier.read' },
  cash_entry: { service: 'cashier', permission: 'cashier.read' },
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
    permission: 'customer.write',
    create: true,
    apply: (s, u, p) => s.customers.createCustomer(u, asDto(p)),
  },
  'customer.update': {
    dto: UpdateCustomerDto,
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
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.archiveCustomer(u, str(p.id)),
  },
  'customer.unarchive': {
    dto: EmptyPayloadDto,
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.unarchiveCustomer(u, str(p.id)),
  },
  'customer.delete': {
    dto: EmptyPayloadDto,
    permission: 'customer.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.deleteCustomer(u, str(p.id)),
  },

  // ---------------- subject ----------------
  'subject.create': {
    dto: CreateSubjectDto,
    permission: 'subject.write',
    create: true,
    structuralKeys: ['customerId'],
    apply: (s, u, p) =>
      s.customers.createSubject(u, str(p.customerId), asDto(p)),
  },
  'subject.update': {
    dto: UpdateSubjectDto,
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
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.archiveSubject(u, str(p.id)),
  },
  'subject.unarchive': {
    dto: EmptyPayloadDto,
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.unarchiveSubject(u, str(p.id)),
  },
  'subject.delete': {
    dto: EmptyPayloadDto,
    permission: 'subject.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.customers.deleteSubject(u, str(p.id)),
  },

  // ---------------- inventory_item ----------------
  'inventory_item.create': {
    dto: CreateInventoryItemDto,
    permission: 'inventory.write',
    create: true,
    apply: (s, u, p) => s.inventory.createItem(u, asDto(p)),
  },
  'inventory_item.update': {
    dto: UpdateInventoryItemDto,
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
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.archiveItem(u, str(p.id)),
  },
  'inventory_item.unarchive': {
    dto: EmptyPayloadDto,
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.unarchiveItem(u, str(p.id)),
  },
  'inventory_item.delete': {
    dto: EmptyPayloadDto,
    permission: 'inventory.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.inventory.deleteItem(u, str(p.id)),
  },

  // ---------------- service_order ----------------
  'service_order.create': {
    dto: CreateOrderDto,
    permission: 'os.write',
    create: true,
    apply: (s, u, p) => s.os.createOrder(u, asDto(p)),
  },
  'service_order.update': {
    dto: UpdateOrderDto,
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
    permission: 'os.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.os.changeStatus(u, str(p.id), asDto(p)),
  },
  'service_order.addItem': {
    // A OS-pai é endereçada por `orderId` — NUNCA por `id`: `CreateItemDto`
    // DECLARA um campo `id` (uuid opcional do item), e uma chave estrutural
    // homônima colidiria com ele (o `id` da OS seria sobrescrito por `undefined`
    // na 2ª validação e o item se perderia). `structuralCollisions` abaixo impede
    // que essa classe de bug volte.
    // O uuid offline do item NÃO é preservado (o service gera o id do item e ele
    // volta no `entityId` da resposta para o cliente reconciliar).
    dto: CreateItemDto,
    permission: 'os.write',
    structuralKeys: ['orderId'],
    apply: (s, u, p) => s.os.addItem(u, str(p.orderId), asDto(p)),
  },
  'service_order.updateItem': {
    dto: UpdateItemDto,
    permission: 'os.write',
    structuralKeys: ['id', 'itemId'],
    apply: (s, u, p) =>
      s.os.updateItem(u, str(p.id), str(p.itemId), asDto(p)),
  },
  'service_order.deleteItem': {
    dto: EmptyPayloadDto,
    permission: 'os.write',
    structuralKeys: ['id', 'itemId'],
    apply: (s, u, p) => s.os.deleteItem(u, str(p.id), str(p.itemId)),
  },
  'service_order.createNote': {
    dto: CreateNoteDto,
    permission: 'os.write',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.os.createNote(u, str(p.id), asDto(p)),
  },
  'service_order.applyTemplate': {
    dto: EmptyPayloadDto,
    permission: 'os.write',
    structuralKeys: ['id', 'templateId'],
    apply: (s, u, p) => s.os.applyTemplate(u, str(p.id), str(p.templateId)),
  },

  // ---------------- cash_session / cash_entry ----------------
  'cash_session.open': {
    dto: OpenSessionDto,
    permission: 'cashier.manage',
    create: true,
    apply: (s, u, p) => s.cashier.openSession(u, asDto(p)),
  },
  'cash_session.close': {
    dto: CloseSessionDto,
    permission: 'cashier.manage',
    apply: (s, u, p) => s.cashier.closeSession(u, asDto(p)),
  },
  'cash_entry.create': {
    dto: CreateEntryDto,
    permission: 'cashier.write',
    create: true,
    apply: (s, u, p) => s.cashier.createEntry(u, asDto(p)),
  },
  'cash_entry.reverse': {
    dto: ReverseEntryDto,
    permission: 'cashier.manage',
    structuralKeys: ['id'],
    apply: (s, u, p) => s.cashier.reverseEntry(u, str(p.id), asDto(p)),
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
