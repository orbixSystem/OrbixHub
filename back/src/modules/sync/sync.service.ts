import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate, ValidationError } from 'class-validator';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { clampChangedSinceLimit } from '../../common/database/changed-since';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import { OsService } from '../os/os.service';
import { MessagesService } from '../messages/messages.service';
import { CashierServiceImpl } from '../cashier/cashier.service.impl';
import { BillingService } from '../billing/billing.service';
import {
  PULL_ROUTES,
  SYNC_OPS,
  SyncOpDef,
  SyncPayload,
  SyncServices,
} from './sync.registry';
import { effectiveTsMs, lwwDiscards } from './sync.lww';
import { PushDto, PullChangesQueryDto, SyncMutationDto } from './dto/push.dto';
import {
  SyncMutationRow,
  SyncRepository,
  SyncStatus,
} from './sync.repository';

/** Item de resposta do push (contrato com o outbox do cliente). */
export interface PushResultItem {
  clientMutationId: string;
  status: SyncStatus;
  entityId?: string;
  message?: string;
}

type ValidateOutcome =
  | { ok: true; value: SyncPayload }
  | { ok: false; message: string };

/**
 * Módulo `sync` — pull incremental + push idempotente do offline-first. NUNCA
 * toca tabelas de outro módulo: compõe os services públicos ("aponta, não
 * invade"). Segurança S1–S10 aplicada aqui (autoria do lote, whitelist do
 * replay, LWW com clamp de relógio, idempotência por autor, limites anti-DoS).
 */
@Injectable()
export class SyncService {
  private readonly services: SyncServices;

  constructor(
    private readonly tenant: TenantContext,
    private readonly audit: AuditService,
    private readonly repo: SyncRepository,
    private readonly billing: BillingService,
    customers: CustomersService,
    inventory: InventoryService,
    os: OsService,
    cashier: CashierServiceImpl,
    messages: MessagesService,
  ) {
    this.services = { customers, inventory, os, cashier, messages };
  }

  // ===================== Pull (GET /sync/changes) =====================
  async getChanges(user: AuthUser, query: PullChangesQueryDto) {
    const route = PULL_ROUTES[query.entity];
    if (!route) {
      throw new BadRequestException(`Entidade desconhecida: ${query.entity}`);
    }
    // Permissão de LEITURA espelhando os GETs do módulo dono (mesma resolução
    // do push): sem ela, o pull vazaria ao cargo dados que o online lhe nega
    // (ex.: mechanic sem cashier.read puxando o extrato do caixa).
    const granted = await this.permissionsOf(user.role);
    if (!granted.has(route.permission)) {
      throw new ForbiddenException(
        'Sem permissão para sincronizar esta entidade.',
      );
    }
    // Gating comercial (I2): o `/sync` não tem `@RequiresModule` (uma rota, N
    // entidades), então aplicamos AQUI a mesma régua do `ModuleAccessGuard`, por
    // entidade. `past_due` libera LEITURA (o pull) e barra escrita (o push).
    const denied = await this.moduleDenial(user, route.module, false);
    if (denied) throw new ForbiddenException(denied);
    const cursor =
      query.sinceTs && query.sinceId
        ? { ts: query.sinceTs, id: query.sinceId }
        : null;
    // A4 já clampa internamente; reforçamos aqui (S10).
    const limit = clampChangedSinceLimit(query.limit ?? 500);
    const { rows, nextCursor, hasMore } = await this.services[
      route.service
    ].listChangedSince(query.entity, cursor, limit);
    // `nextCursor` volta em TODA página não vazia (o cliente sempre persiste o
    // cursor); `hasMore` diz se vale pedir a próxima página (I3).
    return { rows, nextCursor, hasMore, serverTime: new Date().toISOString() };
  }

  // ===================== Push (POST /sync/push) =====================
  async push(user: AuthUser, dto: PushDto) {
    // S1 — a autoria do lote precisa casar com o usuário autenticado.
    if (dto.authorUserId !== user.userId) {
      throw new ForbiddenException(
        'Autor do lote não corresponde ao usuário autenticado.',
      );
    }
    // Permissões efetivas do cargo, resolvidas UMA vez (mesma query do PermissionsGuard).
    const granted = await this.permissionsOf(user.role);
    // Acesso ao módulo resolvido 1× por módulo no lote (não 1× por mutação).
    const accessCache = new Map<string, string | null>();

    const results: PushResultItem[] = [];
    for (const m of dto.mutations) {
      // S8 — idempotência: se já processada (autor+clientMutationId), devolve o desfecho gravado.
      const prior = await this.repo.findMutation(user, m.clientMutationId);
      if (prior) {
        results.push(this.toResult(prior));
        continue;
      }

      const outcome = await this.applyMutation(user, m, granted, accessCache);
      // Corrida de lotes idênticos: se outro push gravou primeiro (unique
      // S8), devolvemos o desfecho do vencedor — nunca 500 no lote inteiro.
      const winner = await this.repo.recordMutation(user, m, outcome);
      results.push(
        winner
          ? this.toResult(winner)
          : { clientMutationId: m.clientMutationId, ...outcome },
      );
    }
    return { results, serverTime: new Date().toISOString() };
  }

  /**
   * Processa UMA mutação (sem gravar). Um erro de negócio vira item `error` e
   * NUNCA trava a fila (as demais mutações continuam).
   */
  private async applyMutation(
    user: AuthUser,
    m: SyncMutationDto,
    granted: Set<string>,
    accessCache: Map<string, string | null>,
  ): Promise<{ status: SyncStatus; entityId?: string; message?: string }> {
    const def: SyncOpDef | undefined = SYNC_OPS[`${m.entity}.${m.op}`];
    if (!def) return { status: 'error', message: 'Operação desconhecida.' }; // S7
    if (!granted.has(def.permission)) {
      return { status: 'error', message: 'Sem permissão para esta operação.' };
    }
    // Gating comercial (I2) — POR MUTAÇÃO: um módulo fora do plano (ou uma
    // assinatura vencida) vira item `error`, nunca um 403 que aniquila o lote
    // inteiro (as mutações dos outros módulos continuam sendo aplicadas).
    const denied = await this.moduleDenial(user, def.module, true, accessCache);
    if (denied) return { status: 'error', message: denied };

    // S7 — whitelist: valida o payload contra o DTO do módulo dono.
    const validated = await this.validatePayload(def, m.payload);
    if (!validated.ok) return { status: 'error', message: validated.message };
    const value = validated.value;

    // S2 — LWW com clamp de relógio: o cliente nunca vence com timestamp futuro.
    const clientMs = Date.parse(m.clientUpdatedAt);
    const nowMs = Date.now();
    let current: Date | null = null;
    if (def.lww) {
      try {
        current = await def.lww.getUpdatedAt(this.services, user, m.payload);
      } catch {
        // Linha não encontrada/leitura falhou → segue para o apply, que
        // reproduz o erro real (ex.: 404 → item `error`).
        current = null;
      }
    }
    if (lwwDiscards(current, clientMs, nowMs)) {
      return { status: 'discarded' }; // servidor mais novo vence
    }

    let entityId: string | undefined;
    try {
      const r = await def.apply(this.services, user, value);
      entityId = r?.id;
    } catch (e) {
      // Qualquer exceção do apply() (inclui id duplicado — S9) vira item `error`.
      return { status: 'error', message: this.messageOf(e) };
    }

    // S2 forense: overwrite auditado quando o LWW tinha um alvo pré-existente.
    // FORA do try do apply e best-effort: a mutação JÁ foi aplicada — uma falha
    // de auditoria não pode rebaixar um `applied` para `error` (registraria o
    // desfecho permanentemente errado no ledger de idempotência).
    if (current) {
      try {
        await this.audit.log(
          user.tenantId,
          user.userId,
          'sync_overwrite',
          entityId,
          {
            clientUpdatedAt: m.clientUpdatedAt,
            effectiveTs: new Date(effectiveTsMs(clientMs, nowMs)).toISOString(),
          },
        );
      } catch {
        // best-effort — nunca rebaixa o resultado aplicado
      }
    }
    return { status: 'applied', entityId };
  }

  /**
   * 2ª passada de validação: separa as chaves estruturais (id/itemId/…) e valida
   * o resto contra o DTO com a MESMA semântica do ValidationPipe global
   * (whitelist + forbidNonWhitelisted, sem conversão implícita).
   */
  private async validatePayload(
    def: SyncOpDef,
    payload: SyncPayload,
  ): Promise<ValidateOutcome> {
    const rest: SyncPayload = { ...payload };
    const structural: SyncPayload = {};
    for (const k of def.structuralKeys ?? []) {
      if (k in rest) {
        structural[k] = rest[k];
        delete rest[k];
      }
    }
    const instance = plainToInstance(def.dto, rest, {
      enableImplicitConversion: false,
    });
    const errors = await validate(instance as object, {
      whitelist: true,
      forbidNonWhitelisted: true,
      // `forbidUnknownValues` (default `true`) rejeita QUALQUER classe sem
      // metadado de validação — o que reprovava, sempre, todas as ops de
      // `EmptyPayloadDto` (archive/unarchive/delete, deleteItem, applyTemplate):
      // elas voltavam `error` → outbox `failed` → mutação PERDIDA. Desligar é
      // seguro: `whitelist` + `forbidNonWhitelisted` continuam recusando
      // qualquer campo não declarado (num DTO sem campos, TODO campo é extra).
      forbidUnknownValues: false,
    });
    if (errors.length) {
      return { ok: false, message: firstConstraint(errors) };
    }
    // As chaves ESTRUTURAIS vêm por ÚLTIMO: o roteamento sempre vence. O
    // `plainToInstance` materializa TODO campo declarado do DTO como propriedade
    // própria (`undefined` quando ausente) — espalhar a instância depois apagaria
    // uma chave estrutural homônima (ex.: `CreateItemDto.id` apagando o id da
    // OS-pai em `service_order.addItem` — todo item adicionado offline se perdia).
    // O registry também PROÍBE essa colisão (`structuralCollisions`).
    return {
      ok: true,
      value: { ...(instance as SyncPayload), ...structural },
    };
  }

  /**
   * Régua de acesso ao módulo dono da entidade — a MESMA do `ModuleAccessGuard`:
   * módulo não habilitado (e não `is_core`) → barrado; assinatura `canceled` (ou
   * qualquer status fora de trialing/active/past_due) → barrado; `past_due` →
   * leitura (pull) liberada, escrita (push) barrada. Devolve a MENSAGEM PT-BR da
   * recusa, ou `null` quando liberado.
   */
  private async moduleDenial(
    user: AuthUser,
    moduleKey: string,
    isWrite: boolean,
    cache?: Map<string, string | null>,
  ): Promise<string | null> {
    const cacheKey = `${moduleKey}:${isWrite ? 'w' : 'r'}`;
    if (cache?.has(cacheKey)) return cache.get(cacheKey) ?? null;
    const denial = await this.resolveModuleDenial(user, moduleKey, isWrite);
    cache?.set(cacheKey, denial);
    return denial;
  }

  private async resolveModuleDenial(
    user: AuthUser,
    moduleKey: string,
    isWrite: boolean,
  ): Promise<string | null> {
    const access = await this.billing.getModuleAccess(user.tenantId, moduleKey);
    if (!access.isCore && !access.enabled) {
      return `Módulo "${moduleKey}" não está habilitado no seu plano.`;
    }
    if (access.status === 'trialing' || access.status === 'active') return null;
    if (access.status === 'past_due' && !isWrite) return null;
    return `Assinatura com status "${access.status}" não permite esta operação.`;
  }

  /**
   * Permissões efetivas do cargo (role/role_permission/permission são globais,
   * sem RLS — mesma query do PermissionsGuard). Resolvido 1× por push.
   */
  private async permissionsOf(role: string): Promise<Set<string>> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ key: string }>>`
      SELECT p.key FROM role r
      JOIN role_permission rp ON rp.role_id = r.id
      JOIN permission p ON p.id = rp.permission_id
      WHERE r.key = ${role}
    `;
    return new Set(rows.map((r) => r.key));
  }

  private toResult(prior: SyncMutationRow): PushResultItem {
    return {
      clientMutationId: prior.client_mutation_id,
      status: prior.result as SyncStatus,
      entityId: prior.entity_id ?? undefined,
      message: prior.error_message ?? undefined,
    };
  }

  private messageOf(e: unknown): string {
    return e instanceof Error && e.message
      ? e.message
      : 'Erro ao aplicar a mutação.';
  }
}

/** Primeira mensagem de constraint (recursiva p/ nested), em fallback PT-BR. */
function firstConstraint(errors: ValidationError[]): string {
  for (const e of errors) {
    if (e.constraints) {
      const msgs = Object.values(e.constraints);
      if (msgs.length) return msgs[0];
    }
    if (e.children?.length) {
      const nested = firstConstraint(e.children);
      if (nested) return nested;
    }
  }
  return 'Payload inválido.';
}
