# OrbixHub — Redesign Neumórfico do Front + Paginação Completa

> Spec aprovado pelo dono em 2026-07-04. Fonte das decisões do "remap completo" do app
> Flutter. Executar junto com as skills `orbixhub-frontend-flutter` e `orbixhub-arquitetura`.

## Decisões do dono (fechadas)

1. **Estética: neumorphism (soft-UI)** conforme imagem de referência — fundo lavanda
   claro, cartões extrudados com sombra dupla, painéis navy de contraste, ícones glyph
   coloridos, raios grandes, botões circulares/pill.
2. **Paleta fixa do produto** — os 7 presets de tema e a cor por tenant SAEM. Identidade
   única (lavanda + navy). Acento custom por tenant pode voltar no futuro, controlado.
3. **Claro + escuro completos** com toggle (persistência já existe — `ThemeController`).
4. **Paginação**: desktop = controles numerados (‹ 1 2 3 › + total); mobile = infinite
   scroll + pull-to-refresh. Toda lista de dados de servidor DEVE ser paginada.
5. **Usabilidade é o princípio nº 1** — usuário-alvo: dono/mecânico pouco digital.
   UI GUIADA: 1 ação principal óbvia por tela, botões grandes com rótulo+ícone, fluxos
   passo-a-passo, linguagem simples, estados vazios que ensinam, alvos ≥48px,
   confirmações claras em ações destrutivas.
6. **Layouts otimizados por dispositivo** (desktop ≠ mobile de verdade), 3 faixas.
7. **Execução**: design system primeiro, depois migração tela-por-tela (cada tela sai
   redesenhada + paginada + responsiva). Implementação contínua, sem pressa.

## Tokens (core/ui/neu_tokens.dart)

**Claro:** base `#E6E7EE` · surface `#EDEEF5` · sombra clara `#FFFFFF` (cima-esq) ·
sombra escura `#B8BCCC`~40% (baixo-dir) · ink `#2B2F44` · inkMuted `#7B8094` ·
navy (painel/ação primária) `#2B2F44` → `#383D5B` hover · acento roxo suave `#8B90B8`.
**Escuro:** base `#2B2F44` · surface `#31364E` · sombra clara `#3A3F5C` · sombra escura
`#1E2133` · ink `#ECEDF5` · painel claro invertido.
**Semânticas** (mantidas, tint ajustado): success `#0E9F6E`, danger `#E5484D`,
warning `#E8A302`, info `#2E90FA`. **Glyphs coloridos** (ícones de módulo): paleta da
imagem (amarelo, laranja, azul, verde, roxo, rosa) com tint de fundo.
**Elevações (sombra dupla):** `flat` (sem sombra) · `raised` (extrudado padrão) ·
`raisedHigh` (dialogs/FAB) · `pressed` (afundado — feedback de toque) · `inset`
(campos de entrada). Raios: 12 (chips) / 16 (inputs) / 20 (cards) / 28 (painéis) /
pill. Tipografia: Sora (display) + Manrope (corpo) — mantidas.
**Contraste (usabilidade):** ação primária SEMPRE navy sólido com texto claro (nunca
"botão fantasma neumórfico"); focus ring visível; textos ≥ 4.5:1 sobre a base.

## Componentes (core/ui/)

`NeuCard` · `NeuPanel` (navy) · `NeuButton` (primary navy / secondary raised / danger)
· `NeuIconButton` (circular) · `NeuIconChip` (glyph colorido + tint) · `NeuTextField` +
`NeuSearchBar` (inset, pill) · `NeuListTile` · `NeuBadge` · `NeuDialog` ·
`NeuSegmented` · `NeuPageControls` (desktop ‹ 1 2 3 › + "N registros") ·
`NeuListFooter` (mobile: spinner/fim/total) · `NeuEmptyState` (ícone grande + título +
texto + CTA) · `NeuChart` (tema fl_chart: cores, grid, tooltip) · `NeuStatusChip`
(status de OS/assinatura). Micro-animações padrão: pressed afunda (120ms), hover eleva,
transição de rota fade-through 200ms (`NeuPageTransition`). Showcase dev em
`/dev/ui` (gated `kDevTools`) exibindo todos os componentes nos 2 temas.

## Responsividade (core/ui/adaptive.dart)

- `Breakpoints`: mobile `<600`, tablet `600–1100`, desktop `≥1100`.
- `AdaptiveScaffold` (shell): desktop = sidebar navy fixa 272px; tablet = rail
  compacto; mobile = **bottom navigation** (Início · OS · Clientes · Mais) + FAB da
  ação principal da tela. "Mais" abre sheet com o resto do menu gated.
- `AdaptiveListPage`: molde de tela de lista — busca + filtros + lista; desktop usa
  linhas densas + `NeuPageControls`; mobile usa cards grandes + infinite scroll +
  `RefreshIndicator`. Telas declaram `desktopBody`/`mobileBody` só quando divergem.

## Paginação — trabalho de backend por fase

| Fase da tela | Backend |
|---|---|
| Mensagens | Thread com cursor `?before=` + `take` (staff **e** rota pública `/public/track/:token/messages` — polling 15s hoje ilimitado) |
| Equipe | `GET /employees`, `/iam/members`, `/invites` → `{items,total,page,pageSize}` (Max 100) |
| Notificações | Cursor (`?before=`) além do cap 50 |
| OS detalhe | timeline/eventos e fotos com `take` + "ver mais"; histórico cliente/veículo com `take` |
| OS lista | adicionar `@Max(100)` no pageSize |
| NF (quando tiver tela) | `pageSize` no `ListInvoicesQueryDto` |
| Templates | `take` + paginação simples |

Regras: migrations aditivas nos 3 lugares (se precisar de índice novo); DTOs com
`@Max`; resposta padrão `{items,total,page,pageSize}` (ou cursor p/ chat/notifications).

## Fases (cada uma termina verificada: analyze 0 + testes verdes + 3 faixas checadas)

1. **Fundação** — tokens, componentes, adaptive, showcase `/dev/ui`. Só arquivos novos
   (zero quebra).
2. **Shell + Dashboard** — troca o tema global para a paleta fixa (o seed/branding
   deixa de ser aplicado), sidebar navy nova, bottom-nav mobile, dashboard em grid
   adaptativo com `NeuCard`/`NeuChart`.
3. **OS** — lista (molde adaptativo), detalhe (timeline/fotos paginadas), wizard "Nova
   OS" em 3 passos (cliente → veículo → itens).
4. **Clientes** — lista + detalhe + histórico paginado.
5. **Estoque** — lista + form + low-stock.
6. **Mensagens** — inbox + thread paginada (incl. pública) + composer.
7. **Equipe + Notificações** — telas + paginação back correspondente.
8. **Configurações + Billing** — remove presets/custom de cor (UI + `branding.dart` +
   testes `theme_presets_test`/`appearance_section_test`); mantém claro/escuro/sistema.
9. **Auth + tracking público** — telas de auth neumórficas; tracking público com a
   nova identidade (é a vitrine para o cliente final).
10. **Relatórios** — tabelas adaptativas + gráficos `NeuChart`.
11. **Polimento** — varredura de contraste/acessibilidade, animações, revisão final.

## Testes

- Testes de lógica (gating, parsing, controllers) continuam valendo.
- Testes de widget quebrados por fase são ATUALIZADOS na própria fase (novos finders).
- Cada molde novo (`AdaptiveListPage`, `NeuPageControls`) ganha teste próprio.

## Fora de escopo deste redesign

Offline/sync (fase própria no roadmap), feature de NF no front (entra depois usando o
design system), WhatsApp/e-mail do link público.
