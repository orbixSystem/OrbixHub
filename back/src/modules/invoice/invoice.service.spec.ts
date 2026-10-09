import { InvoiceService } from './invoice.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { InvoiceRepository } from './invoice.repository';
import type { OsService } from '../os/os.service';
import type { SaleService } from '../sale/sale.service';
import type { CustomersService } from '../customers/customers.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { BillingService } from '../billing/billing.service';
import type { FiscalGateway } from './fiscal/fiscal-gateway';
import type { Env } from '../../common/config/env.schema';
import type { TenancyService } from '../tenancy/tenancy.service';
import type { NuvemFiscalClient } from './fiscal/nuvemfiscal-client';
import type { InvoiceCertificateService } from './invoice-certificate.service';
import { DEFAULT_INVOICE_CONFIG, InvoiceConfig } from './invoice.config';
import { FiscalIdentity, nfsePendencias } from './invoice.service';

describe('InvoiceService.getFiscalIdentity', () => {
  const buildService = (tenancy: { getCompanyView: jest.Mock }) => {
    const tenant = {} as TenantContext;
    const repo = {} as InvoiceRepository;
    const os = {} as OsService;
    const sales = {} as SaleService;
    const customers = {} as CustomersService;
    const audit = {} as AuditService;
    const billing = {} as BillingService;
    const gateway = {} as FiscalGateway;
    const env = {} as Env;
    const nuvem = {} as NuvemFiscalClient;

    return new InvoiceService(
      tenant,
      repo,
      os,
      sales,
      customers,
      audit,
      billing,
      gateway,
      env,
      tenancy as unknown as TenancyService,
      nuvem,
      {} as InvoiceCertificateService,
    );
  };

  it('getFiscalIdentity normaliza a company view do núcleo', async () => {
    const tenancy = {
      getCompanyView: jest.fn().mockResolvedValue({
        taxId: '12345678000199', legalName: 'Oficina LTDA',
        inscricaoMunicipal: '123', regimeTributario: 'simples',
        cep: '01001000', logradouro: 'Rua A', numero: '10',
        bairro: 'Centro', municipio: 'São Paulo', uf: 'SP',
      }),
    };
    const service = buildService(tenancy);

    const id = await service.getFiscalIdentity('t1');

    expect(tenancy.getCompanyView).toHaveBeenCalledWith('t1');
    expect(id.cnpj).toBe('12345678000199');
    expect(id.razaoSocial).toBe('Oficina LTDA');
    expect(id.inscricaoEstadual).toBeNull();
    expect(id.inscricaoMunicipal).toBe('123');
    expect(id.regimeTributario).toBe('simples');
    expect(id.cnae).toBeNull();
    expect(id.email).toBeNull();
    expect(id.endereco.cep).toBe('01001000');
    expect(id.endereco.logradouro).toBe('Rua A');
    expect(id.endereco.numero).toBe('10');
    expect(id.endereco.complemento).toBeNull();
    expect(id.endereco.bairro).toBe('Centro');
    expect(id.endereco.municipio).toBe('São Paulo');
    expect(id.endereco.uf).toBe('SP');
  });

  it('usa companyName como fallback de razaoSocial quando legalName ausente', async () => {
    const tenancy = {
      getCompanyView: jest.fn().mockResolvedValue({
        companyName: 'Nome Fantasia',
      }),
    };
    const service = buildService(tenancy);

    const id = await service.getFiscalIdentity('t2');

    expect(id.razaoSocial).toBe('Nome Fantasia');
    expect(id.cnpj).toBeNull();
  });
});

const identityOk = (over: Partial<FiscalIdentity> = {}): FiscalIdentity => ({
  cnpj: '12.345.678/0001-99',
  razaoSocial: 'Oficina LTDA',
  inscricaoEstadual: null,
  inscricaoMunicipal: null,
  regimeTributario: 'simples',
  cnae: null,
  email: 'a@b.com',
  fone: '11999990000',
  endereco: {
    cep: '01001000', logradouro: 'Rua A', numero: '1', complemento: null,
    bairro: 'Centro', municipio: 'São Paulo', uf: 'SP', codigoIbge: '3550308',
  },
  ...over,
});
const configOk = (over: Partial<InvoiceConfig> = {}): InvoiceConfig => ({
  ...DEFAULT_INVOICE_CONFIG,
  codigoServicoNacional: '140101',
  codigoNbs: '120012200',
  ...over,
});
const future = new Date(Date.now() + 86400_000).toISOString();

describe('nfsePendencias', () => {
  it('tudo preenchido → pronto', () => {
    expect(nfsePendencias(identityOk(), configOk(), future)).toEqual([]);
  });

  it('lista cada pendência em linguagem de usuário, apontando onde corrigir', () => {
    const p = nfsePendencias(
      identityOk({ cnpj: null, regimeTributario: null, endereco: { ...identityOk().endereco, codigoIbge: null } }),
      configOk({ codigoServicoNacional: '', codigoNbs: '123', serieNfse: 'A1' }),
      null,
    );
    expect(p).toEqual([
      'CNPJ da empresa (Configurações › Empresa)',
      'regime tributário (Configurações › Empresa)',
      'código IBGE do município — busque o CEP em Configurações › Empresa',
      'código de tributação nacional do serviço',
      'código NBS do serviço',
      'série da NFS-e (até 5 dígitos)',
      'certificado digital A1 da empresa',
    ]);
  });

  it('certificado vencido é pendência própria', () => {
    expect(nfsePendencias(identityOk(), configOk(), '2020-01-01T00:00:00Z')).toEqual([
      'certificado digital renovado (o atual venceu)',
    ]);
  });
});

describe('InvoiceService.issue', () => {
  const user = { tenantId: 't1', userId: 'u1' } as never;
  const order = {
    order: { id: 'o1', status: 'concluida', number: '123', customer_id: null, customer_name: 'Fulano' },
    items: [
      { kind: 'service', name: 'Troca de óleo', quantity: 1, unit_price: 80, total: 80 },
      { kind: 'product', name: 'Filtro', quantity: 1, unit_price: 40, total: 40 },
    ],
  };

  const build = (provider: 'noop' | 'govbr', opts: { items?: unknown[]; cert?: string | null; identity?: FiscalIdentity } = {}) => {
    const created: Record<string, unknown>[] = [];
    const repo = {
      countAuthorizedByOrder: jest.fn().mockResolvedValue(0),
      nextDpsNumber: jest.fn().mockResolvedValue(7),
      createWithLines: jest.fn().mockImplementation((data: Record<string, unknown>, lines: unknown[]) => {
        created.push({ ...data, lines });
        return { id: 'inv1', ...data };
      }),
      createEvent: jest.fn(),
      updateInvoice: jest.fn(),
      findByIdWithLines: jest.fn().mockResolvedValue({ id: 'inv1', nfse_xml: '<x/>', status: 'authorized' }),
    };
    const gateway = {
      issue: jest.fn().mockResolvedValue({
        externalId: 'chave', status: 'authorized', number: '1', series: '1', accessKey: 'chave',
        pdfUrl: null, xmlUrl: null, rejectionReason: null, documentXml: '<NFSe/>',
      }),
    };
    const svc = new InvoiceService(
      { withTenantTx: (fn: () => unknown) => fn() } as unknown as TenantContext,
      repo as unknown as InvoiceRepository,
      { getOrderWithItems: jest.fn().mockResolvedValue({ ...order, items: opts.items ?? order.items }) } as unknown as OsService,
      {} as SaleService,
      {} as CustomersService,
      { log: jest.fn() } as unknown as AuditService,
      { getModuleSettings: jest.fn().mockResolvedValue({ invoice: configOk() }) } as unknown as BillingService,
      gateway as unknown as FiscalGateway,
      { FISCAL_PROVIDER: provider, FISCAL_ENVIRONMENT: 'homologacao' } as Env,
      { getCompanyView: jest.fn() } as unknown as TenancyService,
      {} as NuvemFiscalClient,
      { info: jest.fn().mockResolvedValue(opts.cert === null ? null : { validUntil: opts.cert ?? future }) } as unknown as InvoiceCertificateService,
    );
    jest.spyOn(svc, 'getFiscalIdentity').mockResolvedValue(opts.identity ?? identityOk());
    return { svc, repo, gateway, created };
  };

  it('NFS-e leva só os serviços; reserva número de DPS e manda o emitente ao gateway', async () => {
    const { svc, repo, gateway, created } = build('govbr');
    const inv = await svc.issue(user, { orderId: 'o1' } as never);

    expect(repo.nextDpsNumber).toHaveBeenCalledWith('t1', 'homologacao', '1');
    expect(created[0]).toMatchObject({ dps_series: '1', dps_number: 7, service_amount: 80, product_amount: 0, total_amount: 80 });
    expect((created[0].lines as unknown[]).length).toBe(1);
    const params = gateway.issue.mock.calls[0][0];
    expect(params.issuer).toMatchObject({
      cnpj: '12345678000199',
      codigoMunicipio: '3550308',
      dps: { serie: '1', numero: 7 },
      servico: { codigoNacional: '140101', codigoNbs: '120012200' },
      reference: 'OS 123',
    });
    expect(repo.updateInvoice).toHaveBeenCalledWith('inv1', expect.objectContaining({ nfse_xml: '<NFSe/>' }));
    expect(inv).not.toHaveProperty('nfse_xml');
  });

  it('OS só com peças → recusa NFS-e (produto é outro documento)', async () => {
    const { svc, gateway } = build('noop', { items: [order.items[1]] });
    await expect(svc.issue(user, { orderId: 'o1' } as never)).rejects.toThrow(/Não há serviços para a NFS-e/);
    expect(gateway.issue).not.toHaveBeenCalled();
  });

  it('govbr com pendência não reserva número nem chama o fisco', async () => {
    const { svc, repo, gateway } = build('govbr', { cert: null });
    await expect(svc.issue(user, { orderId: 'o1' } as never)).rejects.toThrow(/certificado digital A1/);
    expect(repo.nextDpsNumber).not.toHaveBeenCalled();
    expect(gateway.issue).not.toHaveBeenCalled();
  });

  it('noop não exige certificado nem códigos', async () => {
    const { svc, gateway } = build('noop', { cert: null, identity: identityOk({ cnpj: null }) });
    await svc.issue(user, { orderId: 'o1' } as never);
    expect(gateway.issue).toHaveBeenCalled();
  });
});
