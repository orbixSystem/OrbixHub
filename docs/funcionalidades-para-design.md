# OrbixHub — Mapa de funcionalidades (briefing para design)

> Levantamento feito a partir do código em 06/08/2026 (branch `main` sincronizada).
> Objetivo: dar ao designer a visão completa do que o produto FAZ hoje, o que está
> pronto mas escondido, e o que vem a seguir — para trabalhar telas, fluxos e
> identidade em cima disso.
>
> Referência visual atual: `docs/design-system.md` (há versão .html e .pdf na
> mesma pasta). Direção "warm-industrial": canvas claro, sidebar grafite, acento
> tangerina, tipografia Sora (títulos) + Manrope (corpo). A auditoria de UI/UX é
> a fase FINAL do roadmap — o design pode propor evolução.

## O conceito do produto (contexto essencial)

- **SaaS de gestão para oficinas mecânicas** (arquitetura genérica para outros
  verticais no futuro: petshop, salão…).
- **Multiempresa**: cada oficina (tenant) tem espaço 100% isolado; um usuário
  pode pertencer a várias e trocar de empresa dentro do app.
- **Modular por plano**: a oficina assina um plano (hoje Trial e Pro) e o menu /
  telas aparecem conforme os módulos habilitados — a UI é montada em runtime.
- **Papéis**: dono (owner), gerente, mecânico e caixa. Cada papel vê um menu e
  ações diferentes (ex.: mecânico não vê relatórios nem valores gerenciais).
- **Plataformas**: Web, Windows (desktop) e Android — responsividade é requisito
  (sidebar fixa ≥1000px ↔ drawer no mobile; tabelas viram cards).

## 1. Acesso & conta

- Login / criar conta (o cadastro cria a oficina + dono; **busca automática dos
  dados da empresa pelo CNPJ**), verificação de e-mail, esqueci/redefinir senha.
- Convite por e-mail para funcionários (tela de aceitar convite).
- Seletor de empresa (quem pertence a mais de uma oficina escolhe/troca).
- **Login offline** no desktop/mobile (credencial local segura) — dá para abrir o
  app e trabalhar sem internet.

## 2. Casca do app (shell) e Início

- Sidebar/drawer com menu **dinâmico** (papel + módulos do plano), sino de
  notificações, indicador **online/offline/sincronizando** em tempo real.
- **Início (dashboard)** com seletor de período e widgets por módulo/papel:
  KPIs, donut de status das OS, visão operacional (mecânico) e de gestão
  (dono/gerente), cards de clientes e de estoque.
- Banner de **atualização de versão** do app (ver §12).

## 3. Ordens de Serviço (módulo `os`)

- Lista com busca/filtros + **tag de status de pagamento** (Paga / Parcial / A
  receber — derivado do Caixa).
- Detalhe da OS: **stepper de workflow** (próximo passo sugerido), diagnóstico,
  itens (produtos/serviços do estoque, com baixa automática de estoque conforme
  o status), totais, **fotos** (upload/galeria), **linha do tempo** de eventos,
  notas públicas/internas, prévia do chat da OS.
- **Templates de OS** (modelos prontos para abrir OS rápido).
- **PDF da OS** (impressão/compartilhamento).
- **Emitir Nota Fiscal** direto da OS (gated por permissão; ver §9).
- **Agenda** (para quem tem OS): tela de agenda da oficina, horário de
  funcionamento configurável e atribuição de serviço/mecânico com horário.

## 4. Link público de acompanhamento + chat com o cliente (diferencial)

- Cada OS tem um **link público** (`/t/:token`) que a oficina compartilha; o
  cliente final acompanha **sem login e em tempo real** (WebSocket): status,
  linha do tempo e fotos liberadas.
- **Chat cliente ↔ oficina estilo WhatsApp** na página pública: responder com
  citação, aviso sonoro de mensagem nova, nome do cliente identificado.
- Envio do link: **copiar**, **WhatsApp** (wa.me) e **e-mail enviado pelo
  servidor** (dialog que confirma o endereço do cliente antes) — este último é o
  trabalho em andamento nesta máquina.

## 5. Clientes & veículos (módulo `customers`)

- CRUD de clientes (contato/pagador) e **veículos** (entidade genérica "subject"
  — o rótulo vem da configuração da vertical).
- **Consulta por placa** com dados técnicos do veículo persistidos (aba de
  informações adicionais).
- Histórico de OS por veículo, com impressão. Busca, arquivar, excluir (soft).

## 6. Estoque & serviços (módulo `inventory`)

- Catálogo único de **produtos e serviços** (serviço = sem estoque, com preço e
  duração).
- Produtos: SKU **sugerido automaticamente**, código de fabricante, **código de
  barras com leitor via câmera** (scanner no app) e **catálogo EAN externo**
  (preenche o cadastro a partir do código), preços custo/margem/venda,
  estoque mínimo + filtro "abaixo do mínimo", categorias, descrição.
- **Diário de movimentações** (`stock_movement`): cada baixa/estorno registrado
  (consumo por OS, venda de balcão, ajustes).

## 7. Caixa (módulo `cashier`) + Venda avulsa (`sale`) + Contas a receber

- **Caixa do dia**: abrir/fechar sessão (opcional — configurável), contagem de
  gaveta com diferença esperado × contado, extrato em timeline, totais por forma
  de pagamento/categoria.
- Lançamentos: **receber OS** (parcial e múltiplas formas de pagamento),
  suprimento, despesa/sangria, **estorno lógico** auditado, edição de lançamento.
- **Venda avulsa (balcão)** — ação rápida dentro do Caixa, num fluxo único:
  escolher produtos (com scanner), cliente opcional, **desconto**, receber agora
  ou deixar "a receber", opção de emitir nota — e o estoque baixa sozinho.
  Cancelar venda devolve o estoque.
- **Contas a receber**: aba com títulos em aberto por cliente (e sem cadastro),
  com dialog de recebimento.

## 8. Despesas (módulo `expenses`)

- Contas a pagar da oficina: **o que pagar, quando, quanto, se repete, se pagou**.
- **Categorias personalizáveis** com ícone + cor; categorias podem rastrear
  **fornecedor** (ex.: peças) ou não (aluguel, imposto).
- **Despesas fixas/recorrentes** (mensal/anual, dia do vencimento, valor variável
  tipo conta de luz) — as contas de cada mês são geradas automaticamente.
- Parcelamento, vínculo com o Caixa (pagar gera saída no caixa), PDF, e lente
  própria no Relatório (com CSV).

## 9. Notas Fiscais (módulo `invoice`)

- Backend pronto: emissão de NFS-e a partir da OS **e** da venda de balcão, via
  gateway fiscal abstrato (integração real com a API NFS-e Nacional gov.br é a
  próxima etapa), cancelamento, status assíncrono por webhook.
- **Front existe mas está atrás de feature flag (desligado)** — as telas de
  Notas Fiscais e o item de menu já estão preparados. Falta a configuração
  sensível (certificado A1, série, CSC) e a ativação. **Área quente para design.**

## 10. Relatórios (módulo `report`)

- Lentes: **OS** (operacional), **Faturamento** (com série por dia),
  **Vendas** (histórico unificado OS + balcão), **Equipe** (rendimento por
  responsável), **Top itens**, **Estoque** (posição), **Clientes**, **Despesas**.
- Exportação **CSV e PDF**; visível só para quem tem permissão (dono/gerente).

## 11. Chat interno, notificações e tempo real

- **Mensagens**: inbox de conversas + thread, ligadas às OS; é o outro lado do
  chat público do cliente. Tempo real via WebSocket.
- **Notificações**: sino no topo; qualquer módulo pode notificar (mensagem nova,
  eventos de OS…).

## 12. Offline-first + sincronização (desktop/mobile)

- Banco **SQLite local**: clientes, OS, caixa e estoque funcionam **sem
  internet**; as mudanças entram numa fila (outbox) e sincronizam sozinhas ao
  reconectar (pull/push com o servidor).
- Indicador claro de estado: **online / offline / sincronizando** + avisos
  "dados dessincronizados".
- Ações que **exigem** rede ficam bloqueadas com aviso elegante: enviar link ao
  cliente, chat em tempo real, emitir nota. (Web é online-only.)

## 13. Atualização automática do app

- App instalado (Android/Windows) se atualiza sozinho: banner discreto de nova
  versão ("Depois" adiável) ou **tela bloqueante** quando a atualização é
  obrigatória; download com verificação de integridade (sha256).

## 14. Equipe (IAM)

- Tela de Equipe: membros, convites, troca de cargo, desativação.
- Ações sensíveis pedem **reautenticação** (senha atual).
- Papéis semeados: dono, gerente, mecânico, caixa — permissões por papel.

## 15. Planos & assinatura (billing)

- Tela de planos **dinâmica** (vem do servidor): Trial (grátis) e Pro; trial com
  expiração automática; status da assinatura (ativa, vencida = só leitura,
  cancelada = bloqueada). A rota existe mas está **escondida do menu** hoje —
  outra área que merece design (upgrade/paywall).

## 16. Configurações (host incremental)

- **Empresa & identidade visual**: razão social, CNPJ (com busca automática),
  contato, endereço (CEP → UF), campos fiscais, **upload de logo**.
- **Aparência**: 7 presets de tema + cor primária/secundária da marca.
- Cada módulo contratado registra sua própria seção (ex.: Caixa: formas de
  pagamento, exigir sessão, contagem só dinheiro; rótulos da vertical — como
  chamar o "Veículo").

## O que NÃO existe ainda (backlog relevante para design)

- **Fiscal no front** (telas de NF + config de certificado) — backend pronto.
- **Freemium intra-módulo** (features Pro dentro de um módulo; ex.: estoque
  avançado: valorização, curva ABC, fornecedores, kits/combos, import CSV,
  sugestão de preço com IA).
- Acompanhamento público como módulo comercial vendável à parte.
- Alerta proativo de estoque mínimo no dashboard.
- Módulo financeiro completo (fluxo de caixa consolidado) — hoje o conjunto
  Caixa + Despesas + Contas a receber + Relatórios cobre o essencial.

## Observações úteis para o designer

- Strings do produto são **PT-BR**.
- O menu NUNCA é fixo: tudo que aparece depende de papel + plano — o design
  precisa funcionar com 3 e com 10 itens na navegação.
- Estados importantes de desenhar: vazio (primeiro uso), offline/sincronizando,
  assinatura vencida (somente leitura), sem permissão (403 elegante), trial
  expirando.
- Fluxos de maior valor de negócio: abrir OS rápido → compartilhar link →
  cliente acompanha/chat → receber no caixa → (futuro) emitir nota.
