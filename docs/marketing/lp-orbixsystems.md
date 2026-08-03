# Landing Page — OrbixSystems / OrbixHub

> **O que é este documento:** o briefing completo para produzir a landing page
> institucional-comercial da **OrbixSystems** tendo o **OrbixHub** como produto
> principal. Traz posicionamento, público, estrutura seção a seção **com copy pronta
> em PT-BR**, catálogo completo de funcionalidades, diferenciais técnicos vendáveis,
> planos, FAQ, identidade visual (tokens reais do app), SEO e checklist de produção.
>
> **Fonte de verdade das funcionalidades:** o código (`back/src/modules`,
> `front/lib/features`, `back/sql/auth-multitenant-schema.sql`) + `docs/modulos-v1.md`
> + `docs/assessment.md`. Tudo que está marcado ✅ **existe e roda hoje**; tudo que
> está marcado 🚧 é roadmap e **não pode ser vendido como pronto**.
>
> **Data-base:** 2026-08-03 · Branch: `branch-do-inacio`

---

## Índice

1. [Objetivo e metas da página](#1-objetivo-e-metas-da-página)
2. [A empresa e o produto](#2-a-empresa-e-o-produto)
3. [Público-alvo, personas e dores](#3-público-alvo-personas-e-dores)
4. [Posicionamento e mensagem central](#4-posicionamento-e-mensagem-central)
5. [Estrutura da página (seção a seção, com copy)](#5-estrutura-da-página-seção-a-seção-com-copy)
6. [Catálogo completo de funcionalidades](#6-catálogo-completo-de-funcionalidades)
7. [Diferenciais técnicos que viram argumento de venda](#7-diferenciais-técnicos-que-viram-argumento-de-venda)
8. [Planos, preço e oferta](#8-planos-preço-e-oferta)
9. [Objeções e FAQ](#9-objeções-e-faq)
10. [O que NÃO prometer](#10-o-que-não-prometer)
11. [Identidade visual e design da página](#11-identidade-visual-e-design-da-página)
12. [Assets necessários (screenshots, vídeos, ícones)](#12-assets-necessários)
13. [SEO, metadados e performance](#13-seo-metadados-e-performance)
14. [Conversão: CTAs, formulários e analytics](#14-conversão-ctas-formulários-e-analytics)
15. [Requisitos técnicos de implementação](#15-requisitos-técnicos-de-implementação)
16. [Checklist de produção](#16-checklist-de-produção)

---

## 1. Objetivo e metas da página

**Objetivo primário:** gerar **cadastros no trial gratuito de 14 dias** do OrbixHub
(sem cartão de crédito).

**Objetivo secundário:** capturar leads que ainda não querem se cadastrar
(demonstração agendada / WhatsApp) e posicionar a **OrbixSystems** como fábrica de
software séria, não como "sistema de oficina genérico".

| Meta | Indicador | Alvo inicial |
|---|---|---|
| Conversão visitante → trial | `signup_started / sessions` | 3–5% |
| Conversão trial → ativação | criou 1ª OS em 48h | 40% |
| Lead secundário | cliques em "Falar com especialista" | 2% |
| Engajamento | scroll ≥ 75% da página | 35% |
| Performance | LCP mobile | < 2,0s |

**Uma frase para o time:** *a página inteira existe para transformar "eu anoto tudo
no caderno / planilha / WhatsApp" em "eu abri minha conta e criei minha primeira OS".*

---

## 2. A empresa e o produto

### OrbixSystems (a marca-mãe)

Empresa de software que constrói **plataformas de gestão modulares para pequenos e
médios negócios de serviço**. Não vende consultoria por hora nem sistema sob medida
descartável: constrói **produto**, com arquitetura multiempresa desde o primeiro dia.

Tom institucional: **engenharia séria, linguagem simples**. Nada de "revolucionar o
mercado com IA disruptiva".

### OrbixHub (o produto)

**SaaS de gestão multiempresa e modular.** Cada empresa (tenant) tem seu espaço
isolado, seus usuários com cargos, e liga só os **módulos** de que precisa. O
primeiro vertical atendido é **oficina mecânica**, mas o núcleo é genérico por
design — a mesma base serve petshop, assistência técnica, clínica, salão (troca-se
o rótulo do "subject": Veículo → Pet → Equipamento).

Três pilares (usar isso na página, com essas palavras):

1. **Cada empresa no seu mundo.** Isolamento real dos dados no banco, não só filtro
   de tela.
2. **Você liga só o que usa.** Módulos por plano, sem pagar por tela que não abre.
3. **Do orçamento ao dinheiro no caixa.** A OS, o estoque, a venda, o recebimento e
   o relatório são o mesmo fluxo — não quatro sistemas.

### Onde o produto roda hoje ✅

- **Web** (navegador — nada para instalar)
- **Windows** (instalador próprio, assinado no CI)
- **Android** (APK com atualização automática dentro do app)

---

## 3. Público-alvo, personas e dores

### ICP (perfil ideal)

Oficina mecânica **de 1 a 15 funcionários**, faturamento mensal de R$ 20k a R$ 300k,
que hoje controla serviço em **caderno, WhatsApp e planilha** — ou paga caro por um
sistema pesado que ninguém usa direito.

### Personas

| Persona | Quem é | Dor principal | O que a página precisa provar |
|---|---|---|---|
| **Dono/gestor (decisor)** | Toca a oficina e o financeiro | "Não sei quanto entrou hoje nem quem me deve" | Caixa + fiado + relatórios em 1 tela; preço previsível |
| **Balconista / caixa** | Atende, cobra, vende peça no balcão | Fecha o dia sem saber se bateu | Abrir/fechar caixa com conferência ao vivo; venda avulsa em 1 passo |
| **Mecânico** | Executa o serviço | Retrabalho, "o que era pra fazer mesmo?" | OS no celular com fotos, itens e checklist; funciona sem internet |
| **Cliente final (do cliente)** | Deixou o carro | "Já ficou pronto? Quanto vai dar?" | Link público de acompanhamento + chat |

### Dores → como falar delas (linguagem do cliente, não do sistema)

- "Perdi a folha do orçamento." → **tudo fica registrado, com foto e histórico**
- "Não sei quem me deve." → **controle de fiado por cliente**
- "O caixa nunca bate." → **conferência de fechamento ao vivo**
- "A peça sumiu do estoque." → **cada baixa vira um lançamento no diário**
- "A internet da oficina cai." → **continua trabalhando offline e sincroniza depois**
- "Meu cliente liga o dia todo perguntando." → **link de acompanhamento**

---

## 4. Posicionamento e mensagem central

### Headline principal (recomendada)

> **Sua oficina inteira em um só lugar — da ordem de serviço ao dinheiro no caixa.**

**Subheadline:**
> OrbixHub organiza OS, clientes, estoque, caixa, fiado, notas e relatórios em um
> sistema só. Funciona no computador, no celular e **até quando a internet cai**.
> Teste 14 dias grátis, sem cartão.

### Alternativas para teste A/B

| Variante | Headline | Ângulo |
|---|---|---|
| A (padrão) | Sua oficina inteira em um só lugar — da OS ao dinheiro no caixa | Fluxo completo |
| B (dor) | Chega de caderno, planilha e "deixa que eu anoto no WhatsApp" | Dor/substituição |
| C (offline) | O único sistema de oficina que não para quando a internet cai | Diferencial técnico |
| D (dinheiro) | Saiba, todo dia às 18h, exatamente quanto entrou e quem te deve | Financeiro |

### Prova em 4 números (barra logo abaixo do hero)

- **10 módulos** prontos para ligar
- **3 plataformas** — web, Windows e Android
- **14 dias grátis**, sem cartão
- **R$ 99/mês** no plano completo

---

## 5. Estrutura da página (seção a seção, com copy)

Ordem pensada para leitura em scroll único, mobile-first. Cada seção tem: objetivo,
copy pronta e nota de arte.

---

### § 1 — Header / navegação

- Logo OrbixSystems (à esquerda) · Links: **Produto · Módulos · Planos · Empresa ·
  Contato** · Botões: **Entrar** (secundário) + **Testar grátis** (primário).
- Sticky no scroll, encolhendo a altura. Em mobile, menu hambúrguer + botão
  "Testar grátis" sempre visível.

---

### § 2 — Hero

**Objetivo:** entender em 5 segundos o que é e clicar.

```
[H1] Sua oficina inteira em um só lugar —
     da ordem de serviço ao dinheiro no caixa.

[P]  OrbixHub organiza OS, clientes, estoque, caixa, fiado, notas e relatórios
     em um sistema só. No computador, no celular e até quando a internet cai.

[CTA primário]   Testar 14 dias grátis
[CTA secundário] Ver como funciona (2 min)

[microcopy] Sem cartão de crédito. Sem instalação obrigatória. Cancela quando quiser.
```

**Arte:** mockup do app real (dashboard + tela de OS no celular ao lado), fundo
grafite com o degradê da marca. **Usar screenshot real, nunca mockup fake.**

---

### § 3 — Barra de prova social / números

Os 4 números do §4. Se ainda não houver clientes para citar, **não invente logos** —
use os números do produto e a frase: *"Construído por engenheiros brasileiros, em
produção e evoluindo toda semana."*

---

### § 4 — O problema (empatia)

```
[H2] Hoje sua oficina roda em cinco lugares diferentes

O orçamento está no caderno. A peça, na cabeça do balconista. O combinado com o
cliente, no WhatsApp. O quanto entrou, na maquininha. E o quanto falta receber…
ninguém sabe direito.

No fim do mês você não fecha a conta — você adivinha.
```

**Arte:** ilustração/colagem leve: caderno, planilha, WhatsApp, maquininha → seta →
uma tela só.

---

### § 5 — A solução em 3 passos (como funciona)

```
[H2] Um fluxo só, do começo ao fim

1. ABRA A OS
   Cliente, veículo, serviços e peças em um formulário guiado. Busca a placa,
   puxa os dados e já calcula o total.

2. EXECUTE E MOSTRE
   O mecânico atualiza o status, anexa fotos e conversa pelo chat. O cliente
   acompanha por um link público — sem instalar nada, sem ligar pra você.

3. RECEBA E CONFIRA
   Recebimento cai no Caixa (dinheiro, Pix, cartão, parcial ou fiado), o estoque
   baixa sozinho e o relatório do dia se monta sem você digitar nada.
```

**Arte:** três cards com screenshot real de cada etapa.

---

### § 6 — Módulos (o coração da página)

**Objetivo:** mostrar amplitude sem virar lista chata. Grid de cards, cada um com
ícone, título, 1 linha de promessa e 3–4 bullets do que realmente faz. Conteúdo
completo na [§6 deste documento](#6-catálogo-completo-de-funcionalidades) —
usar exatamente aqueles bullets.

```
[H2] Ligue só os módulos que a sua operação usa

[P] Cada plano habilita um conjunto de módulos. O que você não contratou nem
    aparece no menu — e o que você contratou aparece sozinho, sem chamar suporte.
```

Ordem recomendada dos cards (do mais vendedor ao mais técnico):

`Ordens de Serviço` · `Caixa & Fiado` · `Vendas de balcão` · `Clientes & Veículos` ·
`Estoque` · `Agenda` · `Relatórios` · `Nota Fiscal` · `Chat & Acompanhamento` ·
`Equipe & Permissões`

---

### § 7 — Destaque: funciona offline

Seção com peso visual próprio (fundo escuro, "modo espaço" do app).

```
[H2] A internet caiu? A oficina continua.

O OrbixHub no Windows e no Android guarda seus dados num banco local
criptografado. Você abre OS, lança item, tira foto e registra recebimento sem
sinal nenhum. Quando a conexão volta, tudo sobe sozinho, na ordem certa e sem
duplicar.

• Banco local criptografado no aparelho
• Fila de envio à prova de falha — nada se perde no meio do caminho
• Fotos entram na fila e sobem depois
• Aviso claro na tela quando você está offline
```

**Arte:** animação/GIF do indicador de conexão mudando de "offline" para
"sincronizado".

---

### § 8 — Destaque: seus dados isolados de verdade

```
[H2] Cada empresa no seu mundo — garantido pelo banco de dados

Em muitos sistemas, o que separa a sua empresa da do vizinho é um filtro na tela.
No OrbixHub, o isolamento é aplicado pelo próprio banco de dados (Row-Level
Security do PostgreSQL): mesmo que uma consulta tente sair da sua empresa, o banco
recusa.

• Isolamento no banco, não só na aplicação
• Cargos e permissões por empresa (dono, gerente, caixa, mecânico)
• Trilha de auditoria nas operações sensíveis
• Sessão com token curto e renovação automática — e acesso revogado na hora quando
  você desliga um funcionário
```

Selo lateral: *"Arquitetura auditada internamente — relatório em `docs/assessment.md`."*
(Uso interno; na página, virar só "arquitetura auditada".)

---

### § 9 — Multiplataforma

```
[H2] Use no computador da recepção, no notebook do escritório e no celular do box

• Web — abre no navegador, nada para instalar
• Windows — instalador próprio, com atualização automática
• Android — app instalado, com atualização automática dentro do app
• A mesma conta, os mesmos dados, em todos
```

**Arte:** os três dispositivos com a mesma OS aberta.

---

### § 10 — Para quem é (verticais)

```
[H2] Nasceu na oficina. Serve a qualquer negócio de serviço.

O OrbixHub trabalha com dois cadastros genéricos: o CLIENTE (quem paga) e o
ITEM ATENDIDO (o que recebe o serviço). Na oficina, o item atendido é o veículo.
No petshop, é o pet. Na assistência técnica, é o equipamento. Você escolhe o nome
e os campos — o sistema se adapta.

[chips] Oficina mecânica · Funilaria · Auto elétrica · Assistência técnica ·
        Petshop · Estética automotiva
```

> ⚠️ Vender oficina como caso principal. Os outros verticais entram como
> "a mesma base serve", não como "temos versão pronta para petshop".

---

### § 11 — Planos e preços

Ver [§8](#8-planos-preço-e-oferta) para a tabela completa. Dois cards:
**Trial (grátis, 14 dias)** e **Pro (R$ 99/mês)**, com a lista de módulos de cada um
e o CTA "Começar agora".

Microcopy embaixo: *"Sem fidelidade. Sem taxa de implantação. Seus dados são seus —
exporta em CSV e PDF quando quiser."*

---

### § 12 — Segurança e conformidade

Bloco compacto, 4 selos com 1 linha cada:

- **Isolamento no banco (RLS)** — dados de cada empresa separados na origem
- **Senhas com hash forte** — nunca armazenadas em texto
- **Criptografia no dispositivo** — banco local do modo offline é criptografado
- **LGPD** — soft delete e histórico preservado; você controla quem vê o quê

---

### § 13 — Sobre a OrbixSystems

```
[H2] Software feito por quem senta do lado de quem usa

A OrbixSystems desenvolve plataformas de gestão para pequenos e médios negócios de
serviço. O OrbixHub é nosso produto principal: multiempresa, modular e evoluindo
toda semana com o que os clientes pedem no dia a dia.

Não vendemos "sistema pronto para sempre" — vendemos um produto que anda junto com
a sua operação.
```

---

### § 14 — FAQ

Acordeão com as perguntas da [§9](#9-objeções-e-faq).

---

### § 15 — CTA final

```
[H2] Comece hoje. Sua primeira OS leva menos de 2 minutos.

[CTA] Criar minha conta grátis
[secundário] Falar com um especialista no WhatsApp

[microcopy] 14 dias grátis · sem cartão · cancela quando quiser
```

---

### § 16 — Rodapé

Logo · Produto (módulos, planos, novidades) · Empresa (sobre, contato) · Legal
(termos, privacidade) · Contato (e-mail, WhatsApp) · © OrbixSystems.

---

## 6. Catálogo completo de funcionalidades

> Esta é a matéria-prima dos cards da §6 da página e de uma eventual página
> `/funcionalidades`. **Todos os itens ✅ existem no produto hoje.**

### 6.1 Ordens de Serviço (`os`) ✅ — o centro da operação

O módulo mais completo do sistema. É por onde a oficina vive.

- **Abertura guiada (wizard):** cliente novo ou existente, veículo, serviços e peças
  em um fluxo passo a passo — telefone obrigatório para não perder contato.
- **Busca de placa:** consulta a placa e traz os dados do veículo (cota mensal de
  consultas controlada pelo próprio sistema).
- **Itens da OS:** produtos do estoque e serviços do catálogo, com quantidade, preço,
  desconto e total calculado.
- **Status e timeline:** cada mudança (orçamento → aprovada → em execução → concluída
  → entregue) fica registrada com data, hora e responsável.
- **Aprovação controlada:** só quem tem permissão aprova ou reabre uma OS.
- **Fotos com comentários:** anexe fotos do serviço; cada foto aceita comentários —
  prova visual do antes e depois.
- **Anotações internas:** recado da equipe que o cliente não vê.
- **Modelos de OS (templates):** monte a "revisão dos 10 mil km" uma vez e aplique
  com um clique nas próximas.
- **Baixa automática de estoque:** ao entrar em execução, os produtos saem do estoque;
  ao cancelar ou reduzir, voltam. Cada movimento vira um lançamento no diário.
- **Status de pagamento na listagem:** Paga / Parcial / A receber, calculado a partir
  do Caixa.
- **PDF da OS:** exporta com o cabeçalho e o logo da sua empresa.
- **Métricas do módulo:** quantas abertas, em execução, concluídas no período.

### 6.2 Caixa (`cashier`) ✅ — o dinheiro sob controle

- **Abrir e fechar o caixa do dia**, com **valor de abertura sugerido** a partir do
  fechamento anterior.
- **Conferência de fechamento ao vivo:** você digita o que contou e o sistema mostra,
  na hora, o esperado × o contado × a diferença.
- **Só dinheiro ou tudo:** configure se a conferência considera apenas espécie.
- **Lançamentos com categoria:** recebimento de OS, venda avulsa, suprimento, despesa
  e sangria — a direção (entrada/saída) é derivada da categoria, sem risco de errar
  o sinal.
- **Recebimento parcial e múltiplas formas de pagamento** (dinheiro, Pix, débito,
  crédito — as formas são configuráveis por empresa).
- **Estorno lógico auditado:** nada é apagado; o lançamento estornado sai dos totais
  mas continua na trilha.
- **Extrato com filtros** e **totais por forma de pagamento, categoria e origem**.
- **Exigir caixa aberto:** opcional — bloqueia lançamento fora de sessão.

### 6.3 Fiado / Contas a receber (`receivables`) ✅

- **Quem te deve e quanto**, consolidado por cliente.
- **Aba de fiado dentro do Caixa** — não é outro sistema, é a mesma tela.
- **Vendas sem cliente cadastrado** aparecem separadas, para não sumir do radar.
- **Receber é um lançamento no caixa** — inclusive parcial — e o saldo do cliente
  atualiza sozinho.

### 6.4 Vendas de balcão (`sale`) ✅

- **Venda rápida sem abrir OS**, direto pelo Caixa, em um único passo.
- **Cliente opcional** — balcão não exige cadastro.
- **Itens do estoque** com baixa automática registrada no diário.
- **Escolha na hora:** receber agora (cai no caixa) ou deixar a receber (vira fiado).
- **Opção de emitir nota** no mesmo fluxo.
- **Cancelamento com devolução de estoque** (estorno lógico, sem apagar histórico).
- **Detalhe da venda com "cancelar e refazer"** — corrigir errado sem gambiarra.

### 6.5 Clientes & Veículos (`customers`) ✅

- **Cliente** (quem paga) e **item atendido** (veículo, pet, equipamento — rótulo
  configurável) como cadastros separados.
- **CNPJ e CEP preenchidos automaticamente** por consulta pública.
- **Tabela FIPE** para dados de veículo.
- **Histórico do veículo:** todas as OS daquele item atendido, em ordem.
- **Campos personalizados por vertical** — você escolhe o que aparece na ficha.
- **Documento único por empresa**, arquivamento e exclusão sem perder histórico
  (soft delete).
- **Ficha e PDF do veículo** em grid profissional.

### 6.6 Estoque & Serviços (`inventory`) ✅

- **Um catálogo só:** produtos (com estoque) e serviços (com preço e duração).
- **Busca por código:** SKU, código do fabricante ou **código de barras** — se não
  achar internamente, consulta catálogos externos e guarda em cache.
- **SKU sugerido automaticamente** (ex.: `CAFE0001`), único por empresa.
- **Estoque mínimo** com filtro "abaixo do mínimo" e **alerta automático**.
- **Preço sugerido** por custo + margem.
- **Diário de movimentações:** toda baixa e todo estorno ficam registrados, com
  origem (qual OS, qual venda).
- **Arquivar em vez de excluir** — o histórico continua íntegro.

### 6.7 Agenda (`schedule`) ✅

- **Horário de funcionamento** por dia da semana.
- **Agendamento de serviços da OS** em horários — clique no card e vá direto para a OS.
- **Visão de agenda** por período.

### 6.8 Relatórios (`report`) ✅

Sete lentes, todas com filtro de período:

| Relatório | Responde |
|---|---|
| **Operacional (OS)** | Quantas OS, em que status, em quanto tempo |
| **Faturamento** | Quanto entrou, com série por dia |
| **Vendas** | Histórico unificado de OS + venda de balcão, com status de pagamento |
| **Equipe** | Rendimento por responsável |
| **Top itens** | Produtos e serviços que mais saem |
| **Estoque** | Posição atual |
| **Clientes** | Novos e ativos no período |

- **Exportação em CSV e PDF**, com cabeçalho e logo da empresa.
- **Dashboard com gráficos** (visão operacional e visão de gestão).

### 6.9 Nota Fiscal (`invoice`) ✅ backend / 🚧 provedor real

- **Emissão a partir da OS e da venda**, com separação entre produto e serviço.
- **Linhas da nota como retrato** do que foi vendido no momento da emissão.
- **Cancelamento** sem apagar nada (status `cancelada`).
- **Retorno assíncrono do provedor por webhook**, com proteção contra evento repetido.
- **Configuração fiscal isolada:** certificado, ambiente, série e CSC ficam no módulo,
  separados dos dados cadastrais da empresa.

> 🚧 **Estado real:** a fundação está pronta e roda com um provedor de homologação.
> A integração com o emissor oficial (NFS-e Nacional gov.br) está em desenvolvimento.
> **Na LP:** listar como *"Nota Fiscal — em liberação"* ou omitir do plano até
> ligar o provedor real. **Não anunciar como disponível.**

### 6.10 Chat e acompanhamento do cliente ✅

- **Link público de acompanhamento:** o cliente vê o status da OS sem login e sem
  instalar nada.
- **Chat cliente ↔ oficina** dentro do acompanhamento.
- **Tempo real:** mensagem e mudança de status aparecem na hora, dos dois lados
  (WebSocket).
- **Caixa de entrada de conversas** para a equipe.
- **Sino de notificações** (nova mensagem, estoque baixo) com aviso sonoro.

### 6.11 Equipe, cargos e permissões (`iam`) ✅ — sempre incluso

- **Cargos prontos:** dono, gerente, caixa e mecânico.
- **Permissões por área** (OS, estoque, clientes, caixa, nota, relatórios,
  configurações) — o mecânico não vê o financeiro.
- **Convite por e-mail** com aceite.
- **Ativar/desativar funcionário** — o acesso cai na hora, mesmo com sessão aberta.
- **Confirmação de senha** em operações sensíveis.
- **Trilha de auditoria** das mudanças.

### 6.12 Configurações (`settings`) ✅ — sempre incluso

- **Identidade da empresa:** nome, razão social, CNPJ, telefone, e-mail, site, **logo**
  (usado nos PDFs).
- **Dados fiscais e endereço** (CEP → cidade/UF automático).
- **Aparência:** presets de tema e cor primária — o sistema fica com a cara da sua
  empresa.
- **Configuração por módulo:** cada módulo contratado publica a própria seção
  (formas de pagamento do caixa, campos do cadastro, etc.).

### 6.13 Assinatura e módulos (`billing`) ✅ — sempre incluso

- **Trial automático de 14 dias** na criação da conta.
- **Planos com módulos** — trocar de plano recalcula o que fica visível, na hora.
- **Menu dinâmico:** o que você não contratou não aparece.
- **Degradação suave:** pagamento atrasado libera leitura e bloqueia escrita, em vez
  de derrubar o acesso.

### 6.14 Plataforma (transversal) ✅

- **Offline-first** no Windows e Android — banco local criptografado, fila de envio
  e sincronização automática (ver §7).
- **Multiempresa na mesma conta:** um usuário pode pertencer a várias empresas e
  trocar sem deslogar.
- **Atualização automática** do app instalado (Windows e Android).
- **Responsivo de verdade** — desktop, tablet e celular.
- **Interface em português**, com estados de erro tratados.

---

## 7. Diferenciais técnicos que viram argumento de venda

> Para cada diferencial: **como o time fala** (interno) × **como a página fala**
> (cliente). Usar sempre a coluna da direita na LP.

| # | Interno (técnico) | Na página (cliente) |
|---|---|---|
| 1 | Multi-tenant com Postgres RLS + FORCE, `tenant_id` sempre do JWT | **Seus dados isolados pelo próprio banco** — não é filtro de tela |
| 2 | Offline-first com Drift + SQLCipher, outbox idempotente, push → fotos → pull | **A oficina não para quando a internet cai** |
| 3 | Entitlements por módulo (`plan_module` → `tenant_module` → `/me`) | **Você liga só o que usa** — o resto nem aparece |
| 4 | Monolito modular "aponta, não invade" | **Cada área evolui sem quebrar a outra** |
| 5 | WebSocket com salas por conversa/tenant | **Tempo real** — mensagem e status na hora |
| 6 | Sem hard delete (soft delete + estorno lógico) | **Nada é apagado** — o histórico sempre conta a verdade |
| 7 | Auditoria + reautenticação em operações sensíveis | **Você sabe quem fez o quê** |
| 8 | Flutter multiplataforma (web/Windows/Android) com auto-update | **Mesma conta em todos os aparelhos, sempre atualizada** |
| 9 | Refresh token rotativo, access só em memória | **Sessão segura** sem incomodar o usuário |
| 10 | Rota pública resolvida por função `SECURITY DEFINER` | **Cliente acompanha sem login** — e sem risco de vazar outra empresa |

**Regra de ouro da copy:** nunca escrever "RLS", "Drift", "NestJS" na página. O
benefício vai no texto; a stack pode entrar num bloco discreto "construído com" no
rodapé, se quiser credibilidade técnica.

---

## 8. Planos, preço e oferta

### Tabela para a página

| | **Trial** | **Pro** |
|---|---|---|
| **Preço** | Grátis por 14 dias | **R$ 99/mês** |
| Cartão de crédito | Não pede | Na contratação |
| Ordens de Serviço | ✅ | ✅ |
| Clientes & Veículos | ✅ | ✅ |
| Estoque & Serviços | ✅ | ✅ |
| Caixa & Fiado | ✅ | ✅ |
| Vendas de balcão | ✅ | ✅ |
| Agenda | ✅ | ✅ |
| Relatórios + exportação | ✅ | ✅ |
| Chat e acompanhamento | ✅ | ✅ |
| Equipe e permissões | ✅ | ✅ |
| Offline (Windows/Android) | ✅ | ✅ |
| Nota Fiscal | em liberação | em liberação |
| Usuários | Ilimitados | Ilimitados |
| Suporte | E-mail | E-mail e WhatsApp |

> **Fonte:** seed de planos (`trial` = R$ 0 · `pro` = R$ 99,00/mês) e
> `TRIAL_DAYS=14`. Se o preço mudar no seed, **atualizar a página junto**.

**Frases de oferta:**
- "14 dias grátis. Sem cartão, sem pegadinha."
- "Um preço só. Usuários ilimitados — a oficina inteira usa."
- "Cancela quando quiser e leva seus dados (CSV e PDF)."

**Nota de honestidade:** hoje o produto tem **um plano pago**. Não desenhar uma
tabela de 4 colunas fictícia (Básico/Pro/Enterprise) — inventar plano que não existe
gera atrito na hora do cadastro.

---

## 9. Objeções e FAQ

| Pergunta | Resposta para a página |
|---|---|
| **Preciso instalar alguma coisa?** | Não. Abre no navegador. Se preferir, tem app para Windows e Android — e é neles que o modo offline funciona. |
| **E se a internet da oficina cair?** | No Windows e no Android você continua trabalhando normalmente: os dados ficam salvos e criptografados no aparelho e sobem sozinhos quando a conexão volta. |
| **Meus dados ficam misturados com os de outras oficinas?** | Não. O isolamento é feito pelo próprio banco de dados: cada empresa só enxerga o que é dela, mesmo em caso de falha na aplicação. |
| **Quantos usuários posso ter?** | Ilimitados. O preço é por empresa, não por usuário. |
| **Consigo controlar o que cada funcionário vê?** | Sim. Cargos prontos (dono, gerente, caixa, mecânico) e permissões por área. O mecânico não vê o financeiro. |
| **Dá para usar em outro tipo de negócio?** | Sim. Os cadastros são genéricos: você renomeia "Veículo" para "Pet", "Equipamento" ou o que fizer sentido, e escolhe os campos. |
| **Emite nota fiscal?** | O módulo fiscal está em liberação. Avisamos você assim que estiver disponível na sua conta. |
| **Consigo exportar meus dados?** | Sim, relatórios em CSV e PDF a qualquer momento. Seus dados são seus. |
| **Tem fidelidade?** | Não. Mensal, cancela quando quiser. |
| **Preciso migrar meus cadastros na mão?** | Você pode começar cadastrando conforme atende. Importação em massa está no roadmap. |
| **Funciona no celular?** | Sim, tem app Android e a versão web é responsiva. |
| **Como funciona o teste grátis?** | Cria a conta, usa 14 dias com todos os módulos e decide depois. Não pedimos cartão. |

---

## 10. O que NÃO prometer

> **Regra:** o time de marketing não pode listar como pronto nada fora desta lista.
> Prometer o que não existe queima o trial no primeiro dia de uso.

🚫 **Não anunciar como disponível:**

| Item | Estado real |
|---|---|
| Emissão fiscal oficial (NFS-e gov.br) | Fundação pronta; provedor real em desenvolvimento — chamar de "em liberação" |
| Módulo Financeiro (contas a pagar, fluxo de caixa completo) | Planejado, sem implementação |
| Envio do link da OS por WhatsApp/e-mail automático | Hoje só "copiar link" |
| Importação de cadastros em massa (CSV) | Roadmap |
| Curva ABC, valorização de estoque, fornecedores, kits | Roadmap |
| App para iPhone/iOS | Não há build iOS hoje |
| Modo offline na versão web | O offline é do Windows e do Android; a web é online |
| Integração com maquininha / TEF | Não existe |
| Múltiplos depósitos / filiais com estoque separado | Não existe |
| Certificações formais (ISO, SOC 2) | Não existem — falar de práticas, não de selo |

✅ **Pode dizer com segurança:** tudo que está marcado ✅ na [§6](#6-catálogo-completo-de-funcionalidades).

---

## 11. Identidade visual e design da página

### Direção

**"Engenharia calma."** Interface real do produto como protagonista, muito espaço em
branco, tipografia forte, zero stock photo de "mecânico sorrindo com tablet".

### Paleta (tokens reais do app — usar estes hex)

| Papel | Hex | Uso na LP |
|---|---|---|
| Marca | `#767CC0` | Botões primários, links, destaques |
| Marca clara | `#9BA2E8` | Hover, gradientes |
| Marca escura | `#575DA8` | Botão pressionado, texto sobre claro |
| Tinta da marca | `#DFE1F0` | Fundos de destaque suave |
| Grafite | `#2B2F44` | Seções escuras, header, texto principal |
| Grafite alto | `#383D5B` | Cards sobre grafite |
| Canvas | `#E6E7EE` | Fundo geral claro |
| Superfície | `#EDEEF5` | Cards |
| Texto | `#2B2F44` / mudo `#7B8094` | Corpo |
| Sucesso | `#0E9F6E` | Selos "incluído" |
| Alerta | `#CC8F02` | Badges "em liberação" |
| Erro | `#E5484D` | Somente onde necessário |
| **Modo espaço** (seção offline) | fundo `#080B16` / `#0C1122`, superfície `#121A30`, ciano `#38D6F0` | Seção de destaque técnico |

### Tipografia

- **Títulos:** Sora (600/700) — mesma do produto.
- **Corpo:** Manrope (400/500) — mesma do produto.
- Escala sugerida: H1 56/64px desktop e 34/40 mobile · H2 36/44 · H3 24/32 ·
  corpo 17/28 · microcopy 14/20.

### Componentes visuais

- **Cards com relevo suave** (o produto usa neumorfismo leve — sombra clara em cima,
  escura embaixo, raio 16–20px). Não exagerar na LP: relevo discreto.
- **Botão primário:** fundo `#767CC0`, texto branco, raio 12px, altura 52px.
- **Botão secundário:** contorno grafite, fundo transparente.
- **Screenshots:** dentro de moldura de dispositivo, com sombra ampla e suave.
- **Ícones:** conjunto de linha, traço 1,5px, na cor grafite ou marca.

### Movimento

Discreto: fade + subida de 12px na entrada de seção, 250–300ms, respeitando
`prefers-reduced-motion`. Nada de parallax pesado.

---

## 12. Assets necessários

**Screenshots (capturar do app real, tema claro, dados de demonstração plausíveis
— nunca "Cliente Teste 1"):**

1. Dashboard com gráficos (hero)
2. Lista de OS com as tags de pagamento
3. Detalhe da OS: itens, timeline e fotos
4. Wizard de abertura de OS (celular)
5. Caixa do dia — abertura/extrato/totais
6. Diálogo de fechamento com conferência ao vivo
7. Aba de fiado (quem deve quanto)
8. Venda avulsa (fluxo único)
9. Estoque com filtro "abaixo do mínimo"
10. Relatório de faturamento + gráfico
11. Acompanhamento público (visão do cliente, no celular)
12. Chat da OS
13. Equipe e permissões
14. Indicador offline → sincronizado (GIF curto)

**Vídeo:** 90–120s, sem narração de locutor caro — tela + legendas + música leve.
Roteiro: dor (10s) → abrir OS (25s) → executar e mostrar ao cliente (25s) → receber
no caixa (25s) → relatório do dia (15s) → CTA (10s).

**Marca:** logo OrbixSystems (SVG claro/escuro), logo OrbixHub, favicon,
og-image 1200×630.

**Checklist de higiene dos assets:** nenhum dado real de cliente, nenhum CPF/CNPJ
verdadeiro, nenhuma placa real legível, nenhum e-mail real.

---

## 13. SEO, metadados e performance

### Metadados

```html
<title>OrbixHub — Sistema de gestão para oficina mecânica | OrbixSystems</title>
<meta name="description" content="Ordem de serviço, clientes, estoque, caixa, fiado e
relatórios em um sistema só. Funciona offline no Windows e Android. Teste 14 dias
grátis, sem cartão.">
```

- `og:title`, `og:description`, `og:image` (1200×630), `og:type=website`,
  `twitter:card=summary_large_image`
- `lang="pt-BR"`, canonical, `robots: index,follow`

### Palavras-chave

**Primárias:** sistema para oficina mecânica · software de ordem de serviço · gestão
de oficina · programa para oficina mecânica
**Cauda longa:** sistema de OS para oficina que funciona offline · controle de fiado
para oficina · sistema de caixa para oficina mecânica · software de oficina com
estoque e ordem de serviço · sistema para oficina barato
**Institucional:** OrbixSystems · OrbixHub

### Dados estruturados (JSON-LD)

`SoftwareApplication` (nome, categoria `BusinessApplication`, `offers` com preço
99.00 BRL, `operatingSystem: Web, Windows, Android`) + `Organization` +
`FAQPage` (reaproveitar a §9).

### Performance (metas)

- LCP < 2,0s mobile · CLS < 0,1 · INP < 200ms
- Imagens em WebP/AVIF com `width`/`height` declarados e `loading="lazy"` abaixo da
  dobra
- Fontes com `font-display: swap` e `preconnect`
- Sem biblioteca pesada de animação; CSS puro onde der
- Acessibilidade: contraste AA, foco visível, navegação por teclado, `alt` em todas
  as imagens

---

## 14. Conversão: CTAs, formulários e analytics

### Hierarquia de CTAs

- **Primário (repetido 4×: header, hero, após módulos, final):** "Testar 14 dias
  grátis" → `/register` do app
- **Secundário:** "Ver como funciona" (abre o vídeo) e "Falar no WhatsApp"
- **Terciário no rodapé:** "Já tenho conta — entrar"

### Formulário (se houver captura na própria LP)

Mínimo absoluto: **nome, e-mail, WhatsApp, nome da oficina**. Cada campo extra
derruba conversão. Consentimento LGPD com checkbox explícito e link para a política.
Ideal: **mandar direto para o cadastro do app** e não duplicar formulário.

### Eventos para instrumentar

| Evento | Quando |
|---|---|
| `cta_click` | Qualquer CTA (com `location`: hero/header/modules/final) |
| `video_play` / `video_complete` | Vídeo demo |
| `module_card_expand` | Abriu detalhe de um módulo |
| `pricing_view` | Seção de planos entrou na viewport |
| `faq_open` | Abriu uma pergunta (com o texto) |
| `scroll_depth` | 25/50/75/100% |
| `signup_started` | Chegou no cadastro do app |
| `lead_submit` | Enviou o formulário |

Ferramentas: GA4 + Meta Pixel (se houver mídia paga) + mapa de calor (Clarity é
grátis). Cookie banner obrigatório para não-essenciais.

---

## 15. Requisitos técnicos de implementação

- **Stack sugerida:** site estático (Astro ou Next em modo estático) hospedado em
  CDN. Não precisa de backend — o CTA aponta para o app.
- **Domínio:** `orbixsystems.com.br` (institucional) com o produto em destaque; o app
  fica em subdomínio (ex.: `app.orbixsystems.com.br`).
- **Responsividade:** breakpoints 480 / 768 / 1024 / 1280 / 1536. Mobile-first —
  a maior parte do tráfego de oficina vem de celular.
- **Sem dependência externa bloqueante:** fontes autoendereçadas ou com preconnect;
  vídeo em player leve (não embutir YouTube acima da dobra).
- **Legal:** páginas de **Termos de Uso** e **Política de Privacidade** publicadas
  antes de rodar mídia paga; encarregado de dados (LGPD) informado no rodapé.
- **Manutenção:** a LP referencia preço, módulos e prazos do trial. Sempre que
  `plan`/`plan_module`/`TRIAL_DAYS` mudarem no backend, **abrir tarefa de atualização
  da página** — divergência entre página e cadastro é motivo #1 de reclamação.

---

## 16. Checklist de produção

**Conteúdo**
- [ ] Copy revisada em PT-BR, sem jargão técnico na superfície
- [ ] Toda funcionalidade citada conferida contra a [§6](#6-catálogo-completo-de-funcionalidades)
- [ ] Nenhum item da [§10](#10-o-que-não-prometer) anunciado como pronto
- [ ] Preço e dias de trial batendo com o seed do backend
- [ ] FAQ com no mínimo 10 perguntas

**Design**
- [ ] Paleta e tipografia iguais às do produto
- [ ] Screenshots reais, sem dado sensível
- [ ] Contraste AA verificado
- [ ] Testado em 360px, 768px, 1440px

**Técnico**
- [ ] LCP < 2s no mobile (medido no PageSpeed)
- [ ] Metadados, OG e JSON-LD publicados
- [ ] Eventos de analytics disparando (validados no DebugView)
- [ ] Termos e Privacidade no ar
- [ ] Cookie banner funcionando
- [ ] Todos os CTAs levando ao cadastro certo (testado ponta a ponta)

**Pós-publicação**
- [ ] Submeter sitemap ao Search Console
- [ ] Baseline das métricas da [§1](#1-objetivo-e-metas-da-página) registrada
- [ ] Teste A/B da headline programado (variantes da [§4](#4-posicionamento-e-mensagem-central))

---

## Anexo — Banco de frases prontas

**Headlines de seção**
- "Um fluxo só, do orçamento ao recebimento."
- "O caixa fecha certo — e você vê a diferença na hora."
- "Seu cliente acompanha sozinho. Seu telefone descansa."
- "A internet caiu? A oficina continua."
- "Cada empresa no seu mundo — garantido pelo banco de dados."
- "Ligue só os módulos que a sua operação usa."

**Bullets de benefício (reutilizáveis)**
- "Abra uma OS em menos de 2 minutos, com foto e histórico."
- "Saiba quem te deve, quanto e desde quando."
- "A peça sai do estoque sozinha quando entra na OS."
- "Relatório do dia pronto sem digitar nada."
- "O mecânico não vê o financeiro — você decide quem vê o quê."
- "Nada é apagado: estorno é estorno, e fica registrado."

**Microcopy de CTA**
- "Sem cartão de crédito."
- "Leva 2 minutos para começar."
- "Cancela quando quiser."
- "Seus dados saem em CSV e PDF quando você quiser."
