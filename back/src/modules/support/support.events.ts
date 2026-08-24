/**
 * Contrato do evento de domínio "chamado de suporte mudou" — ouvido pelo
 * `realtime` para empurrar a mudança às telas abertas dos DOIS lados: o app do
 * cliente e o painel da Orbix.
 *
 * Vive em arquivo próprio (e não em `support.service.ts`) para o `realtime`
 * importar só o CONTRATO: constante + interface não criam ciclo entre módulos.
 *
 * O payload é deliberadamente MÍNIMO — quem recebe recarrega pela API. Mandar a
 * mensagem inteira pelo socket criaria uma segunda fonte de verdade, que
 * divergiria da API na primeira regra nova (e aqui há regra: marcar como lido
 * muda o contador de quem está olhando).
 */
export const SUPPORT_CHANGED_EVENT = 'support.changed';

export type SupportChangeKind =
  /** Chamado novo, aberto pelo cliente. */
  | 'aberto'
  /** Mensagem nova (de qualquer lado). */
  | 'mensagem'
  /** Status mudou: fechado, reaberto, ou reabertura pedida pelo cliente. */
  | 'status';

export interface SupportChangedEvent {
  tenantId: string;
  ticketId: string;
  kind: SupportChangeKind;
  /** `true` quando quem mexeu foi a Orbix — a UI decide o que destacar. */
  daOrbix: boolean;
}
