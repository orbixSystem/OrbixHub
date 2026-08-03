import { Global, Module } from '@nestjs/common';
import { CnpjGateway } from './cnpj.gateway';

/**
 * Gateway de consulta de CNPJ — global porque é infraestrutura sem domínio,
 * consumida por `auth` (pré-cadastro) e `customers` (cliente PJ). Global evita
 * que cada módulo tenha de importar um módulo de infra explicitamente, como já
 * é feito com Audit/Database.
 */
@Global()
@Module({
  providers: [CnpjGateway],
  exports: [CnpjGateway],
})
export class CnpjModule {}
