import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { CustomersRepository } from './customers.repository';
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
import { UpdateCustomersConfigDto } from './dto/config.dto';

const DEFAULT_PAGE_SIZE = 20;

function isUniqueViolation(e: unknown): boolean {
  return (e as { code?: string })?.code === 'P2002';
}

@Injectable()
export class CustomersService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: CustomersRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
    private readonly history: SubjectHistoryProvider,
  ) {}

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
      if (isUniqueViolation(e)) {
        throw new ConflictException('Já existe um cliente com este documento.');
      }
      throw e;
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
    return this.tenant.withTenantTx(async () => {
      const customer = await this.repo.findCustomerById(customerId);
      if (!customer) throw new BadRequestException('Cliente inválido.');
      return this.repo.createSubject(user.tenantId, customerId, {
        label: dto.label?.trim() || null,
        identifier,
        attributes: dto.attributes,
      });
    });
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
      return this.repo.updateSubject(id, data);
    });
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
}
