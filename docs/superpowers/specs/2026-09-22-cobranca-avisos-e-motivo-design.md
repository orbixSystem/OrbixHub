# Cobrança: aviso antes, bloqueio com motivo, e o suporte à mão

Data: 2026-09-22 · Status: aprovado, em implementação

## O problema

A régua de assinatura já corta o acesso — vencido vira somente leitura, e três
dias depois fecha. Mas ela corta **em silêncio**: o cliente descobre no dia, sem
aviso prévio, sem saber por quê e sem ter a quem recorrer de dentro do sistema.
Do outro lado, quem bloqueia à mão pelo painel não deixa registro nenhum do
motivo, então a primeira coisa que acontece depois de um bloqueio é uma ligação
perguntando o que houve.

Três lacunas, então:

1. **Nenhum aviso antes.** O vencimento chega sem que ninguém tenha avisado.
2. **Bloqueio sem explicação.** A tela diz "bloqueado" e nada mais.
3. **Sem saída.** Bloqueado, a pessoa não tem como falar com a Orbix pelo app.

## Decisões

Tomadas com o dono do produto antes de desenhar:

| Pergunta | Decisão |
|---|---|
| Como o cliente fala com o suporte na tela de bloqueio? | Abre um chamado ali mesmo |
| Quem recebe os e-mails? | Só o dono (`owner`) |
| "Só envia uma vez" — uma vez em relação a quê? | Uma vez **por prazo** |
| Motivo no bloqueio manual | **Obrigatório** |

## Desenho

### Onde mora o motivo

Três colunas novas em `subscription` (migration `0060`, aditiva, refletida nos
três lugares: baseline canônico, `prisma/migrations/`, `schema.prisma`):

| coluna | para quê |
|---|---|
| `block_reason text` | o texto que o cliente lê — a MESMA frase na tela e no e-mail |
| `blocked_at timestamptz` | quando entrou no estado atual |
| `aviso_vencimento_para timestamptz` | para qual `current_period_end` o aviso de 15 dias já saiu |

A terceira coluna é o que faz "uma vez por prazo" funcionar sem tabela de
controle nem contador para alguém zerar na mão: guarda-se **a data que o aviso
anunciava**. Renovou para outra data? O valor diverge do `current_period_end`
atual, e o próximo vencimento volta a avisar. Um cliente que fica três anos na
base recebe três avisos — um por ciclo —, e nunca dois pelo mesmo.

Não há tabela de histórico de bloqueios: o `audit_log` já registra cada
`subscription_change` com o motivo no metadata. Tabela nova seria um segundo
lugar para a mesma verdade.

### Quem escreve o motivo

- **Job diário** (o `TrialExpiryJob`, que já existe):
  - venceu → `past_due` + *"Acesso vencido — pagamento não identificado."*
  - passada a carência → `canceled`, motivo atualizado
- **Painel**, no bloqueio manual → o motivo digitado, obrigatório

### Os e-mails

Três momentos, todos no `renderLayout` que o Hub já usa, todos para o `owner`,
todos fechando com a linha de suporte:

| quando | assunto |
|---|---|
| faltando ≤ 15 dias, uma vez por prazo | Seu acesso ao OrbixHub vence em X dias |
| no vencimento | Seu acesso venceu — o sistema está em modo consulta |
| no bloqueio total ou manual | Acesso bloqueado |

### O que o cliente vê

`/me.assinatura` ganha `motivo`. As telas de bloqueio trocam o texto genérico
pelo motivo real e ganham **"Falar com o suporte"**, que abre um campo ali mesmo
e cria um chamado de verdade.

Isso funciona porque o `SupportController` está deliberadamente **sem**
`@RequiresModule` e sem `@Permissions` — pedir ajuda não pode depender de estar
em dia. O chamado cai na caixa de entrada do Orbix Admin, com histórico.

### O painel

Escolher *Só leitura* ou *Bloqueado* abre um campo obrigatório, com o aviso
embaixo: **"Este texto aparece para o cliente e vai no e-mail que ele receber."**

## Risco registrado

Os e-mails saem por **SMTP do Gmail**. Para 13 clientes funciona; quando a base
crescer, o Gmail passa a limitar e a marcar como spam. Não é resolvido aqui — a
próxima peça a trocar é o transporte (Resend/SES), e o `MailerService` já é
abstrato justamente para essa troca não encostar em quem chama.

## Fora de escopo

- Tabela de histórico de bloqueios (o `audit_log` cobre)
- Reenvio manual de e-mail pelo painel
- Template de e-mail por cliente
- Cobrança automática de verdade (gateway) — segue manual, por PIX
