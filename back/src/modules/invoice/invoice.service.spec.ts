import { InvoiceService } from './invoice.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { InvoiceRepository } from './invoice.repository';
import type { OsService } from '../os/os.service';
import type { SalesService } from '../sales/sales.service';
import type { CustomersService } from '../customers/customers.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { BillingService } from '../billing/billing.service';
import type { FiscalGateway } from './fiscal/fiscal-gateway';
import type { Env } from '../../common/config/env.schema';
import type { TenancyService } from '../tenancy/tenancy.service';

describe('InvoiceService.getFiscalIdentity', () => {
  const buildService = (tenancy: { getCompanyView: jest.Mock }) => {
    const tenant = {} as TenantContext;
    const repo = {} as InvoiceRepository;
    const os = {} as OsService;
    const sales = {} as SalesService;
    const customers = {} as CustomersService;
    const audit = {} as AuditService;
    const billing = {} as BillingService;
    const gateway = {} as FiscalGateway;
    const env = {} as Env;

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
