import { SetMetadata } from '@nestjs/common';

export const REQUIRES_FEATURE = 'requires_feature';

/**
 * Exige uma CAPACIDADE ligada para o tenant, não só o módulo.
 *
 * Espelha `@RequiresModule`, um nível abaixo: o módulo `customers` pode estar
 * habilitado e ainda assim a consulta por identificador não existir para o
 * nicho daquele tenant. Esconder o botão no app não basta — o backend é a
 * verdade, e uma rota aberta continua aberta para quem chama a API direto.
 */
export const RequiresFeature = (key: string) => SetMetadata(REQUIRES_FEATURE, key);
