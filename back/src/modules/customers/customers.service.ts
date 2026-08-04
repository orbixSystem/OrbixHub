import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import {
  STORAGE_PROVIDER,
  StorageProvider,
} from '../../common/storage/storage.provider';
import { BillingService } from '../billing/billing.service';
import { CustomersRepository, CustomersSyncEntity } from './customers.repository';
import {
  clampChangedSinceLimit,
  type ChangedSincePage,
} from '../../common/database/changed-since';
import { SubjectHistoryProvider } from './subject-history.provider';
import type { SubjectHistoryEntry } from './subject-history.provider';
import {
  CUSTOMERS_CONFIG_KEY,
  CUSTOMERS_MODULE_KEY,
  CustomersConfig,
  mergeCustomersConfig,
} from './customers.config';
import {
  CreateCustomerDto,
  ListCustomersQueryDto,
  UpdateCustomerDto,
} from './dto/customer.dto';
import {
  CreateSubjectDto,
  ListSubjectsQueryDto,
  UpdateSubjectDto,
} from './dto/subject.dto';
import {
  CnpjGateway,
  type CnpjEmpresa,
} from '../../common/cnpj/cnpj.gateway';
import { formatCnpj, isValidCnpj, normalizeCnpj } from '../auth/cnpj';
import { UpdateCustomersConfigDto } from './dto/config.dto';
import {
  isIdUniqueViolation,
  isUniqueViolation,
} from '../../common/database/prisma-errors';

const DEFAULT_PAGE_SIZE = 20;

@Injectable()
export class CustomersService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: CustomersRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
    private readonly history: SubjectHistoryProvider,
    @Inject(STORAGE_PROVIDER) private readonly storage: StorageProvider,
    private readonly cnpj: CnpjGateway,
  ) {}

  /** Limite de tamanho do upload da foto do veículo (~8 MB). */
  static readonly MAX_PHOTO_BYTES = 8 * 1024 * 1024;

  /**
   * Consulta a empresa pelo CNPJ para PRÉ-PREENCHER um cliente PJ. Não grava
   * nada — quem decide salvar é o formulário.
   *
   * `email` costuma vir vazio (a base pública da Receita raramente o traz): isso
   * é normal, não erro, e a UI apenas deixa o campo em branco.
   */
  async lookupCnpj(rawCnpj: string): Promise<CnpjEmpresa & { cnpj: string }> {
    const cnpj = normalizeCnpj(rawCnpj);
    if (!isValidCnpj(cnpj)) throw new BadRequestException('CNPJ inválido.');
    // Chamada externa FORA de qualquer transação (regra do projeto).
    const empresa = await this.cnpj.fetch(cnpj);
    return { ...empresa, cnpj: formatCnpj(cnpj) };
  }

  // ===================== Config =====================

  /** Config efetiva (defaults ∪ o que estiver salvo em tenant_module.settings). */
  async getConfig(tenantId: string): Promise<CustomersConfig> {
    const settings = await this.billing.getModuleSettings(
      tenantId,
      CUSTOMERS_MODULE_KEY,
    );
    const saved = settings[CUSTOMERS_CONFIG_KEY] as
      | Partial<CustomersConfig>
      | undefined;
    return mergeCustomersConfig(saved);
  }

  async updateConfig(
    user: AuthUser,
    dto: UpdateCustomersConfigDto,
  ): Promise<CustomersConfig> {
    const settings = await this.billing.getModuleSettings(
      user.tenantId,
      CUSTOMERS_MODULE_KEY,
    );
    const current = settings[CUSTOMERS_CONFIG_KEY] as
      | Partial<CustomersConfig>
      | undefined;
    const merged = mergeCustomersConfig(current, dto);
    await this.billing.setModuleSettings(user.tenantId, CUSTOMERS_MODULE_KEY, {
      ...settings,
      [CUSTOMERS_CONFIG_KEY]: merged,
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'settings_change',
      'customers.config',
    );
    return merged;
  }

  // ===================== Customer =====================

  async createCustomer(user: AuthUser, dto: CreateCustomerDto) {
    const config = await this.getConfig(user.tenantId);
    if (config.documentRequired && !dto.document?.trim()) {
      throw new BadRequestException('Documento é obrigatório.');
    }
    try {
      return await this.tenant.withTenantTx(() =>
        this.repo.createCustomer(user.tenantId, {
          id: dto.id,
          name: dto.name.trim(),
          type: dto.type ?? 'PF',
          document: dto.document?.trim() || null,
          phone: dto.phone?.trim() || null,
          email: dto.email?.trim() || null,
          address: dto.address?.trim() || null,
          notes: dto.notes?.trim() || null,
        }),
      );
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      // PK duplicada (replay offline com id) ≠ documento duplicado. Sob RLS o
      // Postgres suprime o meta.target (vem null) — quando o detalhe não diz
      // que foi a PK, confirmamos com uma LEITURA por id em nova tx: se o
      // registro com aquele id existe no tenant, o conflito é de id.
      if (dto.id) {
        const idTaken =
          isIdUniqueViolation(e) ||
          (await this.tenant.withTenantTx(() =>
            this.repo.findCustomerById(dto.id as string),
          )) != null;
        if (idTaken) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
      }
      throw new ConflictException('Já existe um cliente com este documento.');
    }
  }

  async listCustomers(user: AuthUser, query: ListCustomersQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listCustomers({
        q: query.q?.trim() || undefined,
        status: query.status ?? 'active',
        sort: query.sort,
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getCustomer(user: AuthUser, id: string) {
    const customer = await this.tenant.withTenantTx(() =>
      this.repo.findCustomerById(id),
    );
    if (!customer) throw new NotFoundException('Cliente não encontrado.');
    return customer;
  }

  async updateCustomer(user: AuthUser, id: string, dto: UpdateCustomerDto) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findCustomerById(id);
      if (!existing) throw new NotFoundException('Cliente não encontrado.');
      const data: Record<string, unknown> = {};
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.type !== undefined) data.type = dto.type;
      if (dto.document !== undefined) data.document = dto.document.trim() || null;
      if (dto.phone !== undefined) data.phone = dto.phone.trim() || null;
      if (dto.email !== undefined) data.email = dto.email.trim() || null;
      if (dto.address !== undefined) data.address = dto.address.trim() || null;
      if (dto.notes !== undefined) data.notes = dto.notes.trim() || null;
      try {
        return await this.repo.updateCustomer(id, data);
      } catch (e) {
        if (isUniqueViolation(e)) {
          throw new ConflictException(
            'Já existe um cliente com este documento.',
          );
        }
        throw e;
      }
    });
  }

  archiveCustomer(user: AuthUser, id: string) {
    return this.setCustomerStatus(id, 'archived');
  }

  unarchiveCustomer(user: AuthUser, id: string) {
    return this.setCustomerStatus(id, 'active');
  }

  private setCustomerStatus(id: string, status: 'active' | 'archived') {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findCustomerById(id);
      if (!existing) throw new NotFoundException('Cliente não encontrado.');
      return this.repo.setCustomerStatus(id, status);
    });
  }

  /**
   * Exclui o cliente — SOFT delete (status 'deleted'), nunca hard delete (regra
   * de ouro #6). Some das listas (inclusive 'all'); a linha permanece para
   * histórico/auditoria. Mutação sensível: auditada.
   */
  async deleteCustomer(user: AuthUser, id: string) {
    const result = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findCustomerById(id);
      if (!existing) throw new NotFoundException('Cliente não encontrado.');
      return this.repo.setCustomerStatus(id, 'deleted');
    });
    await this.audit.log(user.tenantId, user.userId, 'customer_delete', id);
    return result;
  }

  // ===================== Subject =====================

  private async assertSubjectsEnabled(tenantId: string): Promise<CustomersConfig> {
    const config = await this.getConfig(tenantId);
    if (!config.usaSubjects) {
      throw new ForbiddenException(
        'Cadastro de objetos desabilitado para este tenant.',
      );
    }
    return config;
  }

  /** Valida campos obrigatórios definidos na config (placa = identifier). */
  private assertRequiredSubjectFields(
    config: CustomersConfig,
    identifier: string | null,
    attributes: Record<string, unknown> | undefined,
  ) {
    for (const field of config.subjectFields) {
      if (!field.obrigatorio) continue;
      const value =
        field.chave === 'identifier' ? identifier : attributes?.[field.chave];
      const empty =
        value === undefined ||
        value === null ||
        (typeof value === 'string' && value.trim() === '');
      if (empty) {
        throw new BadRequestException(`Campo obrigatório: ${field.rotulo}.`);
      }
    }
  }

  async createSubject(user: AuthUser, customerId: string, dto: CreateSubjectDto) {
    const config = await this.assertSubjectsEnabled(user.tenantId);
    const identifier = dto.identifier?.trim() || null;
    this.assertRequiredSubjectFields(config, identifier, dto.attributes);
    try {
      return await this.tenant.withTenantTx(async () => {
        const customer = await this.repo.findCustomerById(customerId);
        if (!customer) throw new BadRequestException('Cliente inválido.');
        return this.repo.createSubject(user.tenantId, customerId, {
          id: dto.id,
          label: dto.label?.trim() || null,
          identifier,
          attributes: dto.attributes,
          plateData: dto.plateData,
        });
      });
    } catch (e) {
      // `subject` não tem unique além da PK: P2002 com id do cliente presente
      // SÓ pode ser o id duplicado (replay offline repetido).
      if (dto.id && isUniqueViolation(e)) {
        throw new ConflictException('Registro já existe (id duplicado).');
      }
      throw e;
    }
  }

  async listSubjects(user: AuthUser, query: ListSubjectsQueryDto) {
    await this.assertSubjectsEnabled(user.tenantId);
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listSubjects({
        q: query.q?.trim() || undefined,
        customerId: query.customerId,
        status: query.status ?? 'active',
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getSubject(user: AuthUser, id: string) {
    await this.assertSubjectsEnabled(user.tenantId);
    const subject = await this.tenant.withTenantTx(() =>
      this.repo.findSubjectById(id),
    );
    if (!subject) throw new NotFoundException('Objeto não encontrado.');
    return subject;
  }

  async updateSubject(user: AuthUser, id: string, dto: UpdateSubjectDto) {
    await this.assertSubjectsEnabled(user.tenantId);
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findSubjectById(id);
      if (!existing) throw new NotFoundException('Objeto não encontrado.');
      const data: Record<string, unknown> = {};
      if (dto.label !== undefined) data.label = dto.label.trim() || null;
      if (dto.identifier !== undefined) {
        data.identifier = dto.identifier.trim() || null;
      }
      if (dto.attributes !== undefined) data.attributes = dto.attributes;
      if (dto.plateData !== undefined) data.plateData = dto.plateData;
      return this.repo.updateSubject(id, data);
    });
  }

  /**
   * Define a foto do subject (veículo). Espelha o upload de fotos da OS: valida
   * o arquivo, faz o upload do binário FORA de transação (regra de ouro) e só
   * então persiste a url + a chave. Substitui a foto anterior (remove o binário
   * antigo, best-effort).
   */
  async setSubjectPhoto(
    user: AuthUser,
    id: string,
    file: { buffer: Buffer; mimetype: string; size: number } | undefined,
  ) {
    if (!file?.buffer) {
      throw new BadRequestException('Arquivo de imagem é obrigatório.');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('O arquivo deve ser uma imagem.');
    }
    if (file.size > CustomersService.MAX_PHOTO_BYTES) {
      throw new BadRequestException('Imagem muito grande (máx. 8 MB).');
    }
    await this.assertSubjectsEnabled(user.tenantId);
    const existing = await this.tenant.withTenantTx(() =>
      this.repo.findSubjectById(id),
    );
    if (!existing) throw new NotFoundException('Objeto não encontrado.');

    const ext = (file.mimetype.split('/')[1] || 'bin').replace(
      /[^a-z0-9]/gi,
      '',
    );
    const key = `subject/${id}/${randomUUID()}.${ext}`;

    await this.storage.put(key, file.buffer, file.mimetype); // fora de tx
    const url = this.storage.url(key);

    const updated = await this.tenant.withTenantTx(() =>
      this.repo.updateSubjectPhoto(id, { url, storageKey: key }),
    );
    // Remove o binário antigo, se havia (best-effort, fora de tx).
    const oldKey = existing.photo_storage_key;
    if (oldKey && oldKey !== key) {
      try {
        await this.storage.remove(oldKey);
      } catch {
        // arquivo órfão é aceitável — não falha a operação
      }
    }
    return updated;
  }

  /** Remove a foto do subject (limpa a url e apaga o binário, best-effort). */
  async removeSubjectPhoto(user: AuthUser, id: string) {
    await this.assertSubjectsEnabled(user.tenantId);
    const existing = await this.tenant.withTenantTx(() =>
      this.repo.findSubjectById(id),
    );
    if (!existing) throw new NotFoundException('Objeto não encontrado.');
    if (existing.photo_storage_key) {
      try {
        await this.storage.remove(existing.photo_storage_key);
      } catch {
        // best-effort
      }
    }
    return this.tenant.withTenantTx(() =>
      this.repo.updateSubjectPhoto(id, { url: null, storageKey: null }),
    );
  }

  archiveSubject(user: AuthUser, id: string) {
    return this.setSubjectStatus(user.tenantId, id, 'archived');
  }

  unarchiveSubject(user: AuthUser, id: string) {
    return this.setSubjectStatus(user.tenantId, id, 'active');
  }

  private async setSubjectStatus(
    tenantId: string,
    id: string,
    status: 'active' | 'archived',
  ) {
    await this.assertSubjectsEnabled(tenantId);
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findSubjectById(id);
      if (!existing) throw new NotFoundException('Objeto não encontrado.');
      return this.repo.setSubjectStatus(id, status);
    });
  }

  /**
   * Exclui o subject — SOFT delete (status 'deleted'), nunca hard delete. Some
   * das listas (inclusive 'all'); a linha permanece para histórico. Auditada.
   */
  async deleteSubject(user: AuthUser, id: string) {
    await this.assertSubjectsEnabled(user.tenantId);
    const result = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findSubjectById(id);
      if (!existing) throw new NotFoundException('Objeto não encontrado.');
      return this.repo.setSubjectStatus(id, 'deleted');
    });
    await this.audit.log(user.tenantId, user.userId, 'subject_delete', id);
    return result;
  }

  /**
   * Histórico do subject (ex.: OS daquele objeto). "Aponta, não invade": quando
   * o módulo de OS existir, o provider chama o service público da OS — este
   * módulo nunca consulta as tabelas da OS. Sem tabela de histórico nova; hoje
   * retorna vazio.
   */
  async getSubjectHistory(
    user: AuthUser,
    id: string,
  ): Promise<SubjectHistoryEntry[]> {
    await this.assertSubjectsEnabled(user.tenantId);
    const subject = await this.tenant.withTenantTx(() =>
      this.repo.findSubjectById(id),
    );
    if (!subject) throw new NotFoundException('Objeto não encontrado.');
    return this.history.listBySubject(id);
  }

  /**
   * Timeline do cliente: histórico agregado de todos os seus subjects, com filtro
   * opcional por subject (carro). Mesma lei "aponta, não invade" — vem do provider
   * (service público da OS quando existir; hoje vazio). Sem tabela nova.
   */
  async getCustomerHistory(
    user: AuthUser,
    customerId: string,
    subjectId?: string,
  ): Promise<SubjectHistoryEntry[]> {
    await this.tenant.withTenantTx(async () => {
      const customer = await this.repo.findCustomerById(customerId);
      if (!customer) throw new NotFoundException('Cliente não encontrado.');
      if (subjectId) {
        const subject = await this.repo.findSubjectById(subjectId);
        if (!subject || subject.customer_id !== customerId) {
          throw new NotFoundException('Objeto não encontrado.');
        }
      }
    });
    return subjectId
      ? this.history.listBySubject(subjectId)
      : this.history.listByCustomer(customerId);
  }

  // ===================== Sync pull (offline) =====================

  private static readonly SYNC_ENTITIES = new Set<CustomersSyncEntity>([
    'customer',
    'subject',
  ]);

  /**
   * Página de mudanças de `customer`/`subject` para o pull de sync offline
   * (`GET /sync/changes`, módulo `sync` — "aponta, não invade": ele nunca lê
   * estas tabelas direto, só chama este service público). Mesma shape JSON dos
   * endpoints de leitura (linhas cruas do Prisma).
   */
  async listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    if (!CustomersService.SYNC_ENTITIES.has(entity as CustomersSyncEntity)) {
      throw new BadRequestException(
        `Entidade não pertence ao módulo customers: ${entity}`,
      );
    }
    const clamped = clampChangedSinceLimit(limit);
    return this.tenant.withTenantTx(() =>
      this.repo.listChangedSince(entity as CustomersSyncEntity, cursor, clamped),
    );
  }
}
