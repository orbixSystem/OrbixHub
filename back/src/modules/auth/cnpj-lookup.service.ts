import { BadRequestException, Injectable } from '@nestjs/common';
import { CnpjGateway } from '../../common/cnpj/cnpj.gateway';
import { AuthRepository } from './auth.repository';
import { isValidCnpj, normalizeCnpj, formatCnpj } from './cnpj';

/** Normalized company data returned to the registration UI. */
export interface CnpjLookupResult {
  cnpj: string; // formatado XX.XXX.XXX/XXXX-XX
  razaoSocial: string;
  nomeFantasia: string | null;
  situacao: string | null;
  municipio: string | null;
  uf: string | null;
  /** true quando já existe um tenant cadastrado com esse CNPJ. */
  alreadyRegistered: boolean;
}

@Injectable()
export class CnpjLookupService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly gateway: CnpjGateway,
  ) {}

  async lookup(rawCnpj: string): Promise<CnpjLookupResult> {
    const cnpj = normalizeCnpj(rawCnpj);
    if (!isValidCnpj(cnpj)) {
      throw new BadRequestException('CNPJ inválido.');
    }

    // A fonte externa fica no gateway (common/cnpj); aqui só se acrescenta o que
    // é do CADASTRO: se já existe tenant com este CNPJ.
    const empresa = await this.gateway.fetch(cnpj);
    const existing = await this.repo.findTenantByCnpj(cnpj);

    return {
      cnpj: formatCnpj(cnpj),
      razaoSocial: empresa.razaoSocial,
      nomeFantasia: empresa.nomeFantasia,
      situacao: empresa.situacao,
      municipio: empresa.municipio,
      uf: empresa.uf,
      alreadyRegistered: existing !== null,
    };
  }
}
