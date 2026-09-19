# Tela "A receber" — do fiado como aba ao controle de crédito

**Data:** 2026-09-18 · **Estado:** aprovado o rumo, pendente revisão desta spec

## O problema

O fiado hoje é uma aba dentro do Caixa. Ela funciona, mas tem três limites que
não se resolvem acrescentando botões:

1. **Filtra no cliente.** A tela baixa a carteira inteira e peneira em memória.
   O backend tem um teto de varredura e devolve `truncated: true` quando não leu
   tudo — ou seja, numa oficina com muito fiado **a tela mente por omissão**.
   Empilhar filtros sobre isso faria os filtros agirem sobre um conjunto já
   incompleto: mais chance de número errado, não menos.
2. **Não responde "quem cobro hoje".** Não há filtro de vencimento. Quem deve há
   três meses aparece igual a quem deve desde ontem.
3. **Parcelas ficam escondidas.** Só aparecem dentro do modal de títulos, dois
   cliques adiante de onde a decisão é tomada.

O nome também incomoda o dono: "fiado" soa pejorativo para o cliente final.

## O que a tela é

Controle de **quem está devendo** — vendas a prazo, em parcelas, e OS entregues
e não acertadas. Responde, nesta ordem:

1. Quanto tenho na rua, e quanto disso está **vencido**
2. **Quem** deve — ordenável por valor, atraso ou nome
3. **De quê** — títulos do devedor, com as parcelas de cada um

## Nome e navegação

- **"A receber"**. O nome já existe no produto: o módulo se chama `receivables`
  e a própria aba mostra "A receber" no topo — só nunca chegou ao menu.
- Item na sidebar **logo abaixo de Caixa**.
- Rota `/m/cashier/a-receber`. Escolhida porque o gate do router lê o segmento
  `/m/<módulo>`: ela herda a trava do módulo `cashier` sem código novo. Um
  `/a-receber` solto exigiria gate próprio e seria mais uma coisa para esquecer.
- Botão no Caixa levando para a tela.
- **A aba sai do Caixa.** Dois caminhos para a mesma coisa divergem com o tempo;
  foi assim que o fiado ficou com regra de agrupamento diferente da do detalhe
  e vazou título de um devedor para a aba de outro.

`gatedNavItems` já tem precedente para item que não é módulo (`Mensagens`,
`Agenda`): entra como `addAReceber()`, gated por `me.modules.contains('cashier')`
e `cashier.read` — as mesmas regras do controller.

## Filtros no servidor

`GET /receivables` passa a aceitar:

| parâmetro | valores | para quê |
|---|---|---|
| `q` | texto | nome do devedor (sem acento, sem caixa) |
| `vencimento` | `todos` · `vencidos` · `vence7` · `a_vencer` | a fila de cobrança |
| `origem` | `os` · `sale` · `todos` | separar serviço de balcão |
| `sort` | `valor` · `mais_antigo` · `nome` | ordenação |
| `page` | inteiro | paginação real |

Resposta ganha `total` (nº de devedores) e mantém `totalDue`. `truncated` deixa
de existir como conceito para o usuário: com paginação de verdade, não há
varredura parcial a confessar.

**Regra pura, testável sem banco.** O cruzamento devedor × vencimento vai para
`receivables.filtro.ts`, como `customers-ranking.ts` já faz no módulo report. É
onde mora a decisão de negócio ("o que conta como vencido"), e é o que erra em
silêncio. Ela também é a regra que o offline precisa repetir — ver abaixo.

**Vencimento de um devedor** = o vencimento mais próximo entre seus títulos.
Título com plano de parcelas usa a próxima parcela em aberto; sem plano, usa a
data do título. Um devedor é `vencido` se tem ao menos um título/parcela
vencido — não é preciso estar tudo vencido para ele entrar na fila.

## Offline — a parte que decide o desenho

O app é offline-first, e "filtro no servidor" contradiz isso se tratado de forma
ingênua. Duas coisas salvam o desenho:

**1. O offline não espelha a resposta do servidor — ele RECALCULA.**
`local_first_receivables_repository` deriva a carteira inteira das linhas locais
(OS, vendas, itens, lançamentos). Ou seja, sem rede já existe matéria-prima para
filtrar, ordenar e paginar. O contrato do repository não muda: a tela pede
`listDebtors(filtros)` e não sabe de onde veio.

**2. A regra de negócio é UMA, escrita duas vezes, verificada contra a mesma
tabela de casos.** Dart e TypeScript não compartilham código — então
`receivables.filtro.ts` e o equivalente Dart são implementações irmãs. Isso é
exatamente onde bug nasce: foi assim que o offline ficou devolvendo todos os
títulos sem cliente enquanto o servidor já filtrava por apelido, e assim que
`_isLowStock` do estoque divergiu do `listItems`.

A mitigação é concreta: **um único arquivo de casos** (`receivables-filtro.casos.json`)
com entrada e saída esperada, lido pelo teste do backend E pelo teste do front.
Divergência vira teste vermelho dos dois lados, não relatório errado em produção.

**Paginação offline** é sobre o que o aparelho tem. Não há teto de varredura sem
rede; o `truncated` deixa de existir nos dois caminhos.

**O modal de registro funciona offline sem nada novo.** `sale.create` e
`receivable_installment.create_plan` já são operações de sync (registradas em
`sync.registry.ts`, gated por `sale.write` e `cashier.write`). A venda nasce com
uuid gerado no cliente, e o plano de parcelas referencia esse uuid — as duas
mutações entram na fila em ordem e replicam juntas.

*Aresta conhecida:* se o `sale.create` falhar no replay (validação, por exemplo),
o `create_plan` que aponta para ela falha sozinho e vira item de erro na fila,
sem travar as demais. A tela de sync já mostra falha por linha (selo vermelho);
não invento tratamento novo, mas registro que esse par não é atômico.

## UI — o critério é ser fácil

- **Topo:** total na rua, quanto está vencido (em vermelho), quantos devedores.
- **Faixa de filtros:** busca + os chips de vencimento + origem + ordenação.
  Chips, não menus: a escolha fica visível sem abrir nada.
- **Linha do devedor:** nome, selo "sem cadastro" quando for apelido, telefone,
  nº de títulos, **próxima parcela e se está vencida**, e o valor à direita.
  O telefone na linha existe para cobrar sem sair da tela.
- **Abrir o devedor** mantém o que já funciona: títulos, parcelas, receber.
- **Sem rede**, a tela opera igual: o aviso de offline que já existe aparece no
  topo e o selo de "pendente de envio" marca o que ainda não subiu.

Reuso, não reescrita: os widgets de devedor, títulos e o `receive_title_dialog`
saem de `receivables_tab.dart` para arquivos próprios e são usados pela tela.
O arquivo tem 1123 linhas hoje — parte do trabalho é quebrá-lo.

## Modal "Registrar venda a prazo"

Para não mandar o cliente ao Caixa só para registrar um fiado.

**Parecido com o da venda, orientado a prazo.** Mesma estrutura (itens, valores),
com três diferenças que vêm do propósito:

1. **Cliente cadastrado em destaque.** Na venda de balcão o apelido basta; aqui
   o ponto é cobrar depois, e apelido não tem telefone. O campo de cliente
   cadastrado vem primeiro, com o apelido como saída explícita.
2. **Sem bloco de recebimento.** A venda nasce fiada (`fiado: true`); não há
   "quanto recebeu".
3. **Parcelamento opcional na mesma tela:** nº de parcelas, dia do vencimento,
   1ª data. É o `POST /cashier/installments` que já existe.

**Sem backend novo:** `POST /sales` com `fiado: true` e, se parcelado,
`POST /cashier/installments` em seguida. Se a segunda falhar, a venda permanece
(o dinheiro não mudou de mão) e a tela avisa que o parcelamento não foi gravado —
mesma regra do estoque não aplicado na venda.

**O modal do Caixa fica como está.** Já serve bem à venda de balcão.

## Fora de escopo

- Criar parcelamento dentro do fluxo de venda do Caixa (lá continua no
  recebimento).
- Régua de cobrança, WhatsApp, lembrete automático.
- Exportar CSV/PDF da carteira — cabe depois, não é o que trava hoje.

## Como se verifica

- **Regra pura** (`receivables.filtro.ts` + irmã em Dart): vencido/a vencer,
  devedor com um título vencido entre vários, título sem data, parcela como
  fonte de vencimento. Sem banco. **Os dois lados rodam a MESMA tabela de
  casos** — é o que impede a divergência online/offline.
- **Endpoint**: filtro + ordenação + paginação combinados, e que a soma das
  páginas bate com o total — foi a conferência que provou o bug do vazamento.
- **Tela**: chips filtram, a busca vai ao servidor com debounce, e o modal de
  registro cria venda fiada (com e sem parcelamento).
- **Não regredir**: os testes de isolamento de devedor (`abrir UM apelido não
  pode mostrar a venda do OUTRO`) continuam valendo e passam a cobrir a tela.

## Riscos

| risco | como trato |
|---|---|
| Filtro no servidor muda números que o dono já conhece | A soma das páginas tem de bater com o total; conferido contra a API antes de entregar |
| Quebrar `receivables_tab.dart` em vários arquivos regride comportamento | Os widgets saem inteiros, sem reescrita; a suíte atual é a rede |
| Modal novo duplicar regra da venda | Ele CHAMA a mesma API; não recalcula total nem desconto |
| Perder a aba deixa alguém sem caminho | Botão no Caixa + item no menu entram na mesma entrega |
| Filtro do offline divergir do servidor (já aconteceu duas vezes) | Tabela de casos única, lida pelos testes dos dois lados |
| Venda offline gravar e o parcelamento não | Não é atômico por natureza; a fila mostra falha por linha e a spec registra a aresta |
