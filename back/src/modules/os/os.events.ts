/**
 * Contrato do evento de domínio "a OS mudou" — ouvido pelo `realtime` para
 * empurrar a mudança às telas abertas.
 *
 * Vive em arquivo próprio (e não em `os.service.ts`) para o `realtime` importar
 * só o CONTRATO, sem depender do service da OS: constante + interface não criam
 * ciclo entre os módulos.
 *
 * O payload é deliberadamente MÍNIMO — id e o que mudou. Quem recebe recarrega
 * pela API; mandar a OS inteira pelo socket criaria uma segunda fonte de verdade,
 * que divergiria da API na primeira regra de negócio nova.
 */
export const OS_CHANGED_EVENT = 'os.changed';

/** O que mudou na OS (a UI usa para decidir o que recarregar). */
export type OsChangeKind =
  | 'status'
  | 'items'
  | 'note'
  | 'photos'
  | 'fields';

export interface OsChangedEvent {
  tenantId: string;
  orderId: string;
  kind: OsChangeKind;
}
