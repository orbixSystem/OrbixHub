/**
 * Régua de acesso pelo STATUS da assinatura — fonte única.
 *
 * Vivia duplicada no `ModuleAccessGuard` (rotas HTTP) e no `SyncService`
 * (push/pull offline). Duas cópias da mesma decisão é como uma passa a divergir
 * da outra; aqui elas compartilham a decisão e cada lado mantém só a própria
 * mensagem de recusa.
 *
 * `enforce` vem de `BILLING_ENFORCE_SUBSCRIPTION`. Enquanto não existir o módulo
 * de assinatura (cobrança de verdade, aviso de vencimento, autoatendimento para
 * regularizar), barrar escrita por status só produz cliente travado sem caminho
 * de saída — o trial de 14 dias expirava e o app inteiro virava somente-leitura,
 * sem explicação na tela. Com `enforce=false` o status vira dado informativo e
 * não bloqueia nada; a régua continua aqui, testada, pronta para ser ligada.
 *
 * NÃO cobre habilitação de módulo (`enabled`/`is_core`): isso é modularidade
 * comercial, não cobrança, e continua valendo em qualquer cenário.
 */
export function subscriptionAllows(
  status: string,
  isWrite: boolean,
  enforce: boolean,
): boolean {
  if (!enforce) return true;
  if (status === 'trialing' || status === 'active') return true;
  // past_due = inadimplente: continua consultando o que é dele, não escreve mais.
  // Qualquer outro status (canceled, ou algo que não conhecemos) barra tudo.
  return status === 'past_due' && !isWrite;
}
