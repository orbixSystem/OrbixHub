# OrbixHub — Módulos v1

## O que é um "módulo"

No OrbixHub, um **módulo** é uma unidade funcional que pode ser habilitada ou desabilitada por tenant conforme o plano contratado. Módulos do tipo **núcleo** estão sempre ativos (não dependem de plano); módulos do tipo **contratável** são ligados por plano e aparecem para o tenant somente quando habilitados.

A lista de módulos ativos do tenant é exposta pelo endpoint `GET /me` no array `modules[]`. A UI utiliza essa lista para exibir (ou ocultar) seções de navegação, telas e configurações de cada módulo. O guard `ModuleAccessGuard` bloqueia acessos a rotas de módulos não habilitados.

## Tabela de módulos

| Módulo | Chave | Tipo | Descrição |
|---|---|---|---|
| Identidade & Acesso | _(núcleo)_ | núcleo | Autenticação, usuários, perfis e controle de acesso baseado em cargos (IAM/RBAC). Sempre ativo. |
| Equipe | _(núcleo)_ | núcleo | Gestão de funcionários e cargos da oficina. Sempre ativo; possui área própria "Equipe" separada das configurações. |
| Configurações | _(núcleo)_ | núcleo | Host incremental de configurações da empresa e de módulos. Sempre ativo; cada módulo contratado registra a própria seção. |
| Assinatura / Billing | _(núcleo)_ | núcleo | Gestão de planos, ciclo de vida da assinatura (trial, ativo, vencido) e webhooks de pagamento. Sempre ativo. |
| Ordens de Serviço | `os` | contratável | Abertura, acompanhamento e encerramento de ordens de serviço de veículos. |
| Clientes | `customers` | contratável | Cadastro e histórico de clientes e veículos. |
| Estoque | `inventory` | contratável | Controle de peças e insumos, entradas, saídas e alertas de estoque mínimo. |
| Acompanhamento | `tracking` | contratável _(planejado)_ | Página pública de acompanhamento do status da OS pelo cliente final. |
| Caixa | `cashier` | contratável _(planejado)_ | Controle de caixa, recebimentos e pagamentos do dia. |
| Nota / Fiscal | `invoice` | contratável _(planejado)_ | Emissão e gestão de notas fiscais de serviço e produto. |
| Financeiro | `finance` | contratável _(planejado)_ | Fluxo de caixa, contas a pagar/receber e relatórios financeiros. |
| Relatórios | `report` | contratável _(planejado)_ | Relatórios gerenciais e operacionais por período, módulo e técnico. |

> **Nota — "planejado":** módulos marcados como _planejado_ ainda não possuem implementação de backend. Suas chaves já estão presentes no catálogo de permissões (seeds), mas nenhum `BillingModule` / guard de rota está ativo para eles nesta versão.
