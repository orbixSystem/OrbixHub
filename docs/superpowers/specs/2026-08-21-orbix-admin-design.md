# Orbix Admin — sistema de administração e suporte

> Design de 21/08/2026. Cobre DOIS repositórios: o novo (`orbix-admin`) e as
> mudanças necessárias no `OrbixHub`. O repositório novo ainda não existe;
> quando existir, esta spec é o contrato entre os dois.

## 1. O que já existe (levantado no banco e no código, não suposto)

Metade do escopo financeiro já está no OrbixHub. Ignorar isso levaria a duas
verdades sobre quem pode usar o quê.

| Já existe no OrbixHub | O quê |
|---|---|
| `tenant` | name, slug, cnpj, legal_name, trade_name, settings, vertical |
| `plan`, `plan_module` | catálogo de planos e o que cada um libera |
| `subscription` | status, trial_ends_at, current_period_*, canceled_at, `external_subscription_id` |
| `billing_webhook_event` | idempotência de webhook por `external_event_id` |
| `tenant_module`, `tenant_feature` | módulos e funcionalidades por cliente, com `source` |
| `audit_log` | ~6 mil eventos reais, com ator e timestamp |
| `PaymentGateway` | contrato abstrato + `verifySignature` (HMAC) — hoje `Noop` |
| `ModuleAccessGuard` | `past_due` libera leitura e barra escrita; `canceled` barra tudo |
| `trial-expiry.job.ts` | job diário de expiração de trial |
| `NotificationsService.notify()` | notificação no sino, chamável por qualquer módulo |
| `MailerService` | envio de e-mail com template |
| `billing.manage` | permissão owner-only, já aplicada no `BillingController` |
| `kBillingNoticesEnabled` | banner de cobrança no front — existe e está `false` |

**Não existe:** autenticação máquina-a-máquina, endpoint administrativo de
provisionamento, faturas/valores/pagamentos, métricas agregadas, aba de
assinatura no Hub.

**Precisa mudar:** `TRIAL_DAYS` de 14 para **60**; e o plano pago atual, que se
chama `pro` mas na verdade É o básico, vira `basico` / "Básico" / **9000**
(R$90). Renomear a chave é seguro: `'pro'` não está cravado em lugar nenhum do
backend, e as 51 assinaturas existentes apontam por `plan_id` (uuid), não pela
chave. O nome `pro` fica livre para o plano superior, quando existir.

## 2. A divisão: quem é dono de quê

> **Admin é dono do DINHEIRO. Hub é dono do DIREITO DE USO.**

- **Hub** — plano atual, `subscription.status`, módulos e funcionalidades
  ligados. Precisa ser local porque o `ModuleAccessGuard` lê a cada request;
  consultar o admin online acoplaria a disponibilidade dos dois sistemas.
- **Admin** — contrato comercial: ciclo, valor, desconto, forma de pagamento,
  faturas, pagamentos, vencimentos, política de bloqueio. Nada disso existe hoje
  no Hub, então não é duplicação: é a camada que falta.

`subscription.external_subscription_id` é o ponteiro entre os dois.

### 2.1 Um plano pago só, e os descontos NÃO viram planos

Hoje existe **um** plano pago: o **Básico**, a **R$90/mês** — é o conjunto de
módulos que já está no ar. O plano `pro` (superior) **ainda não existe**; o
nome fica reservado.

Pacotes: 3 meses −10%, 6 meses −15%, 12 meses −20%.

A tentação seria criar `pro_trimestral`, `pro_semestral`, `pro_anual`. **Não.**
No Hub, `plan` responde *"quais módulos este cliente pode usar"*; os quatro
dariam exatamente os mesmos módulos e difeririam só no preço — quatro linhas no
controle de acesso para representar uma decisão comercial. Seria o dinheiro
vazando para dentro do produto, que é o que esta divisão existe para evitar.

| | Hub | Admin |
|---|---|---|
| Plano | `basico` (único pago hoje) | `plan_key: 'basico'` |
| Ciclo | *não sabe* | mensal · trimestral · semestral · anual |
| Preço cheio | `price_cents` de referência (9000) | R$90/mês |
| Com desconto | *não sabe* | R$243 (3m) · R$459 (6m) · R$864 (12m) |

Quando o `pro` existir, ele entra como plano NOVO no Hub (com o `plan_module`
dele) — os ciclos e descontos continuam sendo do admin, sem duplicar nada.

Promoção nova ou ciclo novo **não tocam o Hub**.

## 3. A aba "Assinatura" (no Hub, dentro de Configurações)

É onde o cliente resolve a vida dele. **Só o dono do ambiente acessa** —
`@Permissions('billing.manage')`, que já é owner-only.

O que ela mostra e faz:

- **Quanto falta**: "seu acesso vai até 12/10/2026 (faltam 23 dias)".
- **Escolher o ciclo**: mensal, 3, 6 ou 12 meses, com o desconto visível.
- **Escolher o modo**: **recorrente** (cobra sozinho a cada ciclo) ou
  **pagamento único** (paga aquele período e acabou). Vale para todos os ciclos
  — inclusive o de 3 meses, que pode ser recorrente trimestral ou avulso.
- **Dia da cobrança** no recorrente: o cliente escolhe o dia do mês.
- **Gerenciar**: trocar cartão, trocar ciclo, cancelar a recorrência.
- **Histórico** de pagamentos daquele ambiente.

O cartão é preenchido no ambiente do Mercado Pago — **não passa pelo Hub nem
pelo admin**. Isso mantém os dois fora do escopo de PCI.

## 4. Trial de 60 dias e os avisos

Cadastro **sem cartão**, sem fricção. `TRIAL_DAYS = 60`.

**A partir de 15 dias antes de expirar**, todos os dias:

| Canal | O quê |
|---|---|
| E-mail | aviso ao dono, com link direto para a aba Assinatura |
| Notificação no app | uma por dia, no sino (`NotificationsService.notify`) |
| Alerta na tela | faixa dispensável: "sua assinatura vence em X dias, renove o pagamento" |

A faixa é **fechável**, e volta no dia seguinte — a dispensa vale por dia, não
para sempre. O mecanismo do banner já existe no front
(`kBillingNoticesEnabled`, hoje `false`); ele é religado e ganha o estado de
"vence em X dias" além do "past_due" que já tratava.

Quem dispara: o `trial-expiry.job.ts`, que já roda diariamente — ganha a faixa
dos 15 dias em vez de só agir no vencimento.

## 5. Pagamento: o admin É o gateway do Hub

```
CLIENTE no Hub (aba Assinatura)      ADMIN                 MERCADO PAGO
escolhe ciclo + modo
      |
      | Hub chama createCheckout() ----->  cria cobranca ----->
      |   (contrato que JA existe)                        devolve URL
      | <---------------- URL de pagamento <---------------
      |
   cliente paga (cartao fica no MP) ----------------------->
                                    <--- webhook do MP -----
                          registra fatura + pagamento
                          (verdade comercial mora aqui)
                                    |
                                    | webhook HMAC (JA existe no Hub)
                                    v
                    Hub: subscription.status = active
                         current_period_end = +ciclo
```

**Código novo de integração no Hub: nenhum.** A implementação `Noop` do
`PaymentGateway` vira `AdminGateway` — uma chamada HTTP. O webhook de entrada já
existe, já verifica assinatura e já é idempotente.

### 5.1 Mercado Pago: dois formatos, não um

No MP, recorrente e avulso são produtos diferentes, e o `contract` precisa dos
dois **desde a Fase D** — senão o pacote anual vira gambiarra depois.

| Modo | No Mercado Pago | Comportamento |
|---|---|---|
| Recorrente | `preapproval` (assinatura) | cobra sozinho a cada ciclo, no dia escolhido |
| Único | pagamento avulso (Checkout) | cobre N meses e termina; sem renovação automática |

Webhook do MP: tópicos `payment` e `preapproval`, com validação da assinatura
`x-signature` no formato deles. Idempotência por id do evento, espelhando o que
o Hub já faz em `billing_webhook_event`.

## 6. Inadimplência: o job acha, o humano decide

O job periódico vive no admin e **não bloqueia sozinho**: marca "vencido há N
dias" e joga numa fila de decisão. O admin escolhe *manter ativo*, *bloquear
escrita* (`past_due`) ou *bloquear tudo* (`canceled`).

**Política padrão por cliente** (ex.: "bloqueia escrita após 10 dias") com
override manual sempre por cima. Com poucos clientes decidir na mão funciona;
com dezenas vira plantão. Ambas auditadas com o nome de quem decidiu.

O efeito no Hub já está implementado. A env `BILLING_ENFORCE_SUBSCRIPTION`, hoje
`false` porque não havia caminho de regularização, **é religada quando a aba de
Assinatura existir** — aí passa a haver.

## 7. Autenticação

### 7.1 Humanos → Admin: Authentik (OIDC)

Self-hosted, com Postgres e Redis próprios, isolado da infra do Hub. O admin é
client OIDC — nunca guarda senha. Grupo `orbix-admins`; papéis (`suporte`,
`financeiro`, `owner`) modelados desde já, mesmo que hoje todos tenham acesso
total. MFA e SSO ficam disponíveis sem trabalho extra.

### 7.2 Máquina ↔ máquina: token de serviço, NÃO Authentik

Motivo: passar a chamada máquina-a-máquina pelo Authentik faz o provisionamento
e a cobrança pararem quando o Authentik parar. Authentik é para gente.

| Direção | Mecanismo | Segredo |
|---|---|---|
| Admin → Hub (API administrativa) | `Bearer <token>` + guard novo | `ADMIN_API_TOKEN` |
| Admin → Hub (status de cobrança) | webhook HMAC **que já existe** | `BILLING_WEBHOOK_SECRET` |
| Hub → Admin (checkout) | `Bearer <token>` | `HUB_API_TOKEN` |

Segredos só por env (validados por Zod), rotacionáveis, nunca no código.

## 8. Sessão de suporte (impersonação)

O admin pode **entrar no ambiente do cliente**, com leitura E escrita. Escrita
exige confirmação por ação e fica marcada como feita pelo suporte.

Regras não-negociáveis:

1. **Motivo obrigatório** antes de abrir a sessão.
2. **Prazo curto** — token expira em 30 min, sem renovação silenciosa.
3. **Banner visível para o cliente**: "Suporte Orbix conectado".
4. **Escrita aparece na timeline do CLIENTE**, não só no log interno:
   "alterado por: Suporte Orbix (Kaue)".
5. **Auditado dos dois lados** — no admin (quem, quando, por quê) e no Hub
   (`audit_log` com o ator de suporte).

Mecanismo: o admin pede ao Hub um token
(`POST /admin/tenants/:id/support-session`); o Hub emite um JWT de escopo
reduzido com `support_actor` no claim, e todo `AuditService.log` daquela sessão
carrega o ator de suporte.

## 9. Métricas de uso

**Eventos de domínio + login**, não chamadas de API. O `audit_log` já grava
`os_create`, `os_status_change`, `inventory_item_create`, `cashier_entry_create`
e `login` — a coleta já existe.

Contar requisição HTTP enganaria: o app nativo sincroniza a cada 60s, então um
cliente com o app aberto 8h gera ~480 chamadas sem ninguém usar nada — o ranking
viraria "quem deixa o app aberto".

O Hub expõe `GET /admin/metrics` com séries por tenant/módulo/dia; o admin
guarda snapshots para histórico e monta os gráficos.

### 9.1 Armadilha: não desenvolva métricas contra o banco local

O banco de desenvolvimento tem **4.347 tenants**, e praticamente todos são lixo
da suíte e2e — slug `t-xxxxxx`, e-mail `@ex.com`, criados a cada rodada e nunca
limpos. Qualquer ranking ou agregação calculada ali sai dominada por tenant de
teste e não significa nada.

Antes da Fase E, resolver uma das duas:
- marcar tenant de teste (coluna ou convenção de slug) e filtrar nas agregações; ou
- validar as métricas contra produção, nunca contra o local.

Vale para o desenvolvimento E para o teste automatizado das agregações.

## 10. O que muda no OrbixHub

**Módulo novo `admin`** (`back/src/modules/admin/`), atrás do guard de token:

| Rota | Para quê |
|---|---|
| `POST /admin/tenants` | provisiona ambiente + owner + credencial de 1º acesso |
| `GET/PATCH /admin/tenants/:id` | dados, nicho, suspensão |
| `GET/PATCH /admin/tenants/:id/modules` | módulos e funcionalidades (reusa a Fase 3 já feita) |
| `POST /admin/tenants/:id/support-session` | emite token de suporte |
| `GET /admin/metrics` | agregações de uso |

**Mais:**
- `TRIAL_DAYS` 14 → 60
- plano `pro` → `basico`, "Básico", 9000 (migration de dados, aditiva; a chave
  não é referenciada em código)
- `AdminGateway` no lugar do `NoopGateway`
- Aba **Assinatura** em Configurações (back + front) — §3
- `trial-expiry.job` ganha os avisos de 15 dias (e-mail + sino + faixa)
- `kBillingNoticesEnabled` religado, com o estado "vence em X dias"
- Ator de suporte no `AuditService`

**O webhook de cobrança não muda.**

## 11. Modelo de dados do admin (banco próprio)

```
admin_user        espelho do Authentik (sub, email, nome) — sem senha
customer          cliente comercial: razao social, cnpj, contatos, tenant_id do Hub
contract          plan_key, ciclo, modo (recorrente|unico), valor, desconto,
                  dia da cobranca, politica de bloqueio
invoice           competencia, valor, vencimento, status
payment           fatura, valor pago, data, meio, id do MP
refund            fatura, valor, data, motivo, quem registrou (manual)
block_decision    quem decidiu, quando, motivo, efeito aplicado
support_session   quem, qual tenant, motivo, inicio/fim
usage_snapshot    tenant, dia, metrica, valor
admin_audit       toda acao administrativa: ator, acao, alvo, antes/depois
```

`customer.tenant_id` é ponteiro para o Hub — o admin nunca lê o banco do Hub.

## 12. Nota fiscal

**Não haverá NF da mensalidade por enquanto** — a Orbix ainda não tem CNPJ. Se um
cliente pedir, é emitida à mão pelo CNPJ pessoal do dono, fora do sistema.

O admin gera **recibo**, não nota fiscal, e o texto na tela do cliente não pode
prometer NF. O módulo `invoice` do Hub é outra coisa: ele emite a NF *do cliente
para o cliente dele*, não a da Orbix.

## 12.1 Reembolso e troca de ciclo

**Por enquanto é conversa com o suporte** — sem fluxo automático, sem cálculo
proporcional, sem botão de cancelar-e-devolver. Quem decide é gente.

O que o sistema PRECISA ter mesmo assim: a capacidade de **registrar** o
reembolso que você fez à mão, com valor, data e motivo, marcando a fatura como
reembolsada. Sem isso o histórico mente — o admin mostraria "pago" para uma
competência cujo dinheiro voltou, e a soma do mês fica errada.

O estorno em si é feito no painel do Mercado Pago; o admin só registra que
aconteceu. Fluxo automático fica para quando o volume justificar.

## 13. Fases

**Fase A — Fundação do admin.** Repo, NestJS, Postgres próprio, Authentik em
container isolado, login OIDC, `admin_audit`.

**Fase B — API administrativa no Hub.** Módulo `admin` + guard de token +
provisionamento. Teste de que a rota não abre sem token.

**Fase C — Ciclo de vida do ambiente.** Criar/editar/suspender pelo admin,
credencial de primeiro acesso, e a tela de módulos/funcionalidades — que serve
ao admin E resolve a tela que hoje falta no Hub.

**Fase D — Assinatura e cobrança.** Aba Assinatura no Hub, `contract`/`invoice`/
`payment` no admin, adaptador do Mercado Pago (preapproval + avulso),
`AdminGateway`, webhook do MP, avisos de 15 dias, job de vencimento e fila de
decisão. **Só aqui `BILLING_ENFORCE_SUBSCRIPTION` volta a `true`.**

**Fase E — Métricas.** `GET /admin/metrics`, snapshots e dashboard.

**Fase F — Sessão de suporte.** Token de escopo, banner no Hub, ator de suporte
na auditoria e na timeline do cliente. Por último de propósito: é a de maior
risco e a que mais se beneficia de o resto estar estável.

## 14. Decisões tomadas (e o que foi descartado)

- **Admin como gateway do Hub** — em vez de duplicar assinatura ou de mover o
  financeiro para dentro do Hub. Reusa contrato e webhook existentes.
- **Ciclo e desconto só no admin** — descartado criar 4 planos no Hub.
- **Token de serviço no caminho máquina-a-máquina** — descartado OIDC
  client-credentials: derrubaria provisionamento e cobrança com o Authentik.
- **Métrica por evento de domínio** — descartada a contagem de chamadas de API,
  dominada pelo polling de sync de 60s.
- **Trial sem cartão** — descartado exigir cartão no cadastro (derruba cadastro)
  e o cartão opcional (dois fluxos de cobrança para manter desde o início).
- **Bloqueio com decisão humana + política padrão** — descartado o bloqueio
  automático puro e a decisão 100% manual.
- **Impersonação com escrita** — escolhida sobre "só leitura", com as cinco
  regras da §8 como contrapartida obrigatória.

## 15. Em aberto

- **Front do admin: React/Next** (decidido). Falta escolher biblioteca de
  gráfico e de tabela — decisão de implementação, não bloqueia nada.

**E-mail transacional: SMTP** (decidido) — o mesmo que o Hub já usa. Nada novo
a construir.
