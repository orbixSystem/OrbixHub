# Plano — pagamento pelo Mercado Pago com liberação automática

Data: 2026-09-22 · Status: plano, **não implementado**
Público: o agente/dev que vai implementar. Leia inteiro antes de escrever código.

## O que existe hoje (leia isto antes de desenhar qualquer coisa)

Metade do trabalho já está pronta, e ignorar isso é o jeito mais rápido de
duplicar a régua de acesso:

| peça | onde | o que faz |
|---|---|---|
| `subscription` | `back/prisma/schema.prisma` | `status`, `current_period_end`, `block_reason`, `aviso_vencimento_para` |
| `subscriptionAllows(status, escrita, enforce)` | `back/src/modules/billing/subscription-access.ts` | a régua ÚNICA: `active`/`trialing` = tudo · `past_due` = só leitura · `canceled` = nada |
| `ModuleAccessGuard` | `back/src/modules/billing/module-access.guard.ts` | aplica a régua em toda rota com `@RequiresModule` |
| `BillingService.ajustarAssinatura` | `back/src/modules/billing/billing.service.ts` | **é aqui que se libera acesso**: move a data, ajusta status, dispara e-mail |
| `PaymentGateway` (abstrato) + `NoopPaymentGateway` | `back/src/modules/billing/payment/` | a interface que o Mercado Pago deve implementar |
| webhook de billing | `BillingController` | já existe, com assinatura HMAC + idempotência por `external_event_id` |
| `billing_webhook_event` | tabela global | guarda o id do evento já processado |
| `CobrancaMailService` | `back/src/modules/billing/cobranca-mail.service.ts` | os e-mails de cobrança, num lugar só |

**Não crie um segundo caminho de liberação.** Pagamento confirmado deve chamar
`ajustarAssinatura` — o mesmo método que o painel usa. Se o Mercado Pago
escrever direto na tabela, passam a existir duas verdades sobre o que libera um
cliente, e elas divergem na primeira regra nova.

## O que falta

### 1. O gateway (`MercadoPagoGateway implements PaymentGateway`)

Implemente a interface que já está em `payment/payment-gateway.ts`. Comece
lendo-a: se um método não couber no Mercado Pago, mude a interface junto com o
`Noop` — não contorne.

Precisa de:

- **Criar cobrança** para um tenant + valor + vencimento. Comece por
  **Checkout Pro** (link pronto, hospedado por eles): é uma chamada HTTP e
  devolve uma URL. PIX via API direta é mais bonito e mais trabalho — não é o
  primeiro passo.
- **Devolver a URL** do pagamento, para o e-mail e para o painel.
- **Guardar o id externo** (`preference_id` / `payment_id`) em
  `subscription.external_subscription_id` ou numa tabela nova de cobranças
  (ver §3).

Credenciais: `MERCADOPAGO_ACCESS_TOKEN` e `MERCADOPAGO_WEBHOOK_SECRET` em
`common/config/env.schema.ts`. **Chave fora do schema é descartada em silêncio
pelo Zod** — já custou uma investigação inteira neste repositório.

Escolha do gateway por env (`PAYMENT_GATEWAY=noop|mercadopago`), para o
ambiente de teste continuar sem tocar em dinheiro de verdade.

### 2. O webhook

O Mercado Pago chama de volta quando o pagamento muda de estado. Regras que já
valem para o webhook existente e continuam valendo:

- **Assinatura obrigatória.** O MP manda `x-signature` (formato `ts=...,v1=...`,
  HMAC-SHA256 sobre um manifest com `id`, `request-id` e `ts`). Sem validar,
  qualquer um libera qualquer cliente com um POST.
- **Idempotência**: grave o `payment_id` em `billing_webhook_event` antes de
  agir. O MP reenvia o mesmo evento — sem isso, um pagamento vira três meses.
- **Nunca chame o gateway dentro de transação de banco** (regra de ouro nº 6).
- O webhook do MP manda só o **id**; é preciso buscar o pagamento na API deles
  para saber o valor e o status. Não confie no corpo do POST.

Ao confirmar `status === 'approved'`:

```
ajustarAssinatura(tenantId, {
  accessEndsAt: <hoje + período pago>,
  status: 'active',
})
```

`ajustarAssinatura` já limpa `block_reason`, volta o status e manda o e-mail.
Nada mais precisa ser feito para "liberar o sistema".

**Cuidado com a data**: some o período ao vencimento ATUAL quando ele ainda
estiver no futuro (quem paga adiantado não pode perder os dias que sobraram), e
a partir de hoje quando já tiver vencido.

### 3. Tabela de cobranças (recomendado)

`subscription` guarda o estado atual, não a história. Para responder "ele pagou
o quê, quando?" crie `billing_charge` (migration **aditiva nos 3 lugares** —
regra de ouro nº 9): `tenant_id`, `external_id`, `valor_cents`, `status`,
`vence_em`, `pago_em`, `url`. Com RLS + FORCE, como toda tabela de tenant.

Sem ela dá para funcionar, mas a primeira pergunta do cliente ("paguei dia 3,
cadê?") não tem resposta no sistema.

### 4. O link no e-mail

`renderAvisoDeVencimento` e `renderAcessoBloqueado` já recebem `CobrancaMailInput`.
Acrescente `linkDePagamento?: string` e um botão. O `renderLayout` tem **um**
CTA: o de pagar deve virar o principal nesses dois e-mails, e o "Abrir o
OrbixHub" desce para linha de texto.

Atenção: o texto do link precisa aparecer na versão TEXTO também. O
`renderLayout` passa por `stripTags` — por isso a linha do WhatsApp usa a
própria URL como rótulo. Repita o padrão.

### 5. O painel

Mostre na ficha do cliente a última cobrança e o link, para quem atende poder
reenviar por WhatsApp. Não recrie o cálculo de acesso no painel: ele só
**mostra** o que o Hub decidiu.

## Ordem sugerida

1. `billing_charge` + migration (3 lugares)
2. `MercadoPagoGateway` gerando link (Checkout Pro), com `PAYMENT_GATEWAY=noop`
   ainda em prod
3. Webhook com assinatura + idempotência, **em sandbox**
4. Ligar `ajustarAssinatura` no webhook e testar o ciclo inteiro em sandbox:
   bloqueado → paga → liberado sozinho
5. Link nos e-mails
6. Painel mostra a cobrança
7. Só então `PAYMENT_GATEWAY=mercadopago` em produção

## Testes que não podem faltar

- webhook com assinatura inválida → **400 e nada muda**
- mesmo evento duas vezes → cobra uma vez só (idempotência)
- pagamento aprovado de tenant `canceled` → volta a `active`, `block_reason`
  limpo, e-mail enviado
- pagamento aprovado antes do vencimento → soma ao prazo existente, não o
  substitui
- isolamento: webhook do tenant A não altera o tenant B

## Armadilhas registradas

- **Ambiente de teste do MP usa credenciais separadas.** Testar com a chave de
  produção cobra de verdade.
- O MP tem dois formatos de webhook (`topic`/`type`). Trate os dois ou fixe um
  na configuração da conta.
- `BILLING_ENFORCE_SUBSCRIPTION=true` já está ligado em produção: liberar
  errado corta cliente na hora. Rode o ciclo inteiro em sandbox antes.
- SMTP hoje é Gmail e vai limitar quando a base crescer — não é problema desta
  tarefa, mas o e-mail de "pagamento confirmado" cai no mesmo canal.
