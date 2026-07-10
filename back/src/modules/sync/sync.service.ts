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
import { CashierServiceImpl } from '../cashier/cashier.service.impl';
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
    customers: CustomersService,
    inventory: InventoryService,
    os: OsService,
    cashier: CashierServiceImpl,
  ) {
    this.services = { customers, inventory, os, cashier };
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
    const cursor =
      query.sinceTs && query.sinceId
        ? { ts: query.sinceTs, id: query.sinceId }
        : null;
    // A4 já clampa internamente; reforçamos aqui (S10).
    const limit = clampChangedSinceLimit(query.limit ?? 500);
    const { rows, nextCursor } = await this.services[
      route.service
    ].listChangedSince(query.entity, cursor, limit);
    return { rows, nextCursor, serverTime: new Date().toISOString() };
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

    const results: PushResultItem[] = [];
    for (const m of dto.mutations) {
      // S8 — idempotência: se já processada (autor+clientMutationId), devolve o desfecho gravado.
      const prior = await this.repo.findMutation(user, m.clientMutationId);
      if (prior) {
        results.push(this.toResult(prior));
        continue;
      }

      const outcome = await this.applyMutation(user, m, granted);
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
  ): Promise<{ status: SyncStatus; entityId?: string; message?: string }> {
    const def: SyncOpDef | undefined = SYNC_OPS[`${m.entity}.${m.op}`];
    if (!def) return { status: 'error', message: 'Operação desconhecida.' }; // S7
    if (!granted.has(def.permission)) {
      return { status: 'error', message: 'Sem permissão para esta operação.' };
    }

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
    });
    if (errors.length) {
      return { ok: false, message: firstConstraint(errors) };
    }
    return {
      ok: true,
      value: { ...structural, ...(instance as SyncPayload) },
    };
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
