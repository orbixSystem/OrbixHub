# OrbixHub — Design System v1.0

> **Documento vivo.** Atualize quando uma decisão visual for consolidada pelo time.
> Versão do código implementado: `front/lib/core/theme/app_colors.dart` + `app_theme.dart`.

---

## 1. Direção

**B2B profissional, orientado a gestão.**
A OrbixHub gerencia operações críticas de negócio — ordens de serviço, estoque,
caixa, equipes. O visual precisa transmitir **confiança e controle**, não
leveza ou entretenimento.

Inspirações de referência: Linear, Notion, Vercel, GitHub.

Três princípios:
1. **Clareza sobre decoração** — cada elemento tem função; o visual não distrai.
2. **Densidade com respiro** — dashboards com muita info precisam de hierarquia
   clara, não de espaços em branco excessivos.
3. **Preto/branco dominam; cor sinaliza** — a tela quase toda neutra; a cor
   aparece onde há ação ou significado.

---

## 2. Paleta de cores

### 2.1 Estrutura da paleta

```
┌─────────────────────────────────────────────────────────────────┐
│  ESTRUTURA (navy)   │  AÇÃO (Orbix Blue)  │  CANVAS (neutros)  │
│  sidebar, headers   │  CTAs, links, foco  │  fundo, bordas     │
└─────────────────────────────────────────────────────────────────┘
                                      +
┌─────────────────────────────────────────────────────────────────┐
│  SEMÂNTICO: Verde (OK) · Vermelho (erro) · Âmbar (atenção)     │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Brand — Azul Marinho (estrutura)

| Token           | Hex       | RGB              | Uso                                      |
|-----------------|-----------|------------------|------------------------------------------|
| `navy-base`     | `#0D2B52` | 13, 43, 82       | Sidebar, headers de seção, brand panel   |
| `navy-mid`      | `#193F7A` | 25, 63, 122      | Item ativo na sidebar, badges de status  |
| `navy-hi`       | `#1E5099` | 30, 80, 153      | Hover no item de sidebar, bordas de foco |
| `on-navy`       | `#F0F4FF` | 240, 244, 255    | Texto/ícone sobre fundo navy             |
| `on-navy-muted` | `#8DA4C8` | 141, 164, 200    | Texto secundário sobre navy              |
| `navy-line`     | `#243D66` | 36, 61, 102      | Divisores dentro da sidebar              |

> **Regra:** o navy quase-preto vai nos elementos de estrutura (sidebar, header
> da área de conteúdo, painéis informativos escuros). **Nunca** use navy escuro
> em botões de ação — leia a seção 2.3.

### 2.3 Interação — Orbix Blue (ação)

A distinção entre *estrutura* e *ação* é o que faz o sistema respirar.
O Orbix Blue é mais vibrante que o navy — salta no contexto neutro do canvas.

| Token              | Hex       | RGB              | Uso                                         |
|--------------------|-----------|------------------|---------------------------------------------|
| `orbix-blue`       | `#1E5FD8` | 30, 95, 216      | Botão primário, link, indicador de foco     |
| `orbix-blue-dark`  | `#1A4EBA` | 26, 78, 186      | Hover/pressed no botão primário             |
| `orbix-blue-light` | `#3D7AE8` | 61, 122, 232     | Estado disabled leve, bordas de foco suave  |
| `orbix-blue-tint`  | `#E8EFFE` | 232, 239, 254    | Fundo de campo focado, wash de seleção      |

> **Por que dois azuis?** Navy (`#0D2B52`) é escuro demais para botão — o texto
> branco sobre ele fica com baixo contraste perceptivo em tamanhos menores, e
> visualmente "pesa". O Orbix Blue (`#1E5FD8`) tem WCAG AA garantido e lê como
> "ação" de forma imediata.

### 2.4 Neutros — Escala de Cinza/Preto

| Token           | Hex       | Opacidade sobre branco | Uso                                          |
|-----------------|-----------|------------------------|----------------------------------------------|
| `ink`           | `#1A1A2E` | —                      | Títulos / headings (quase-preto, toque navy) |
| `ink-80`        | `#333344` | preto 80%              | Corpo de texto principal                     |
| `ink-muted`     | `#6B7280` | —                      | Labels secundários, texto de apoio           |
| `silver`        | `#C4C9D4` | —                      | Bordas, divisores, detalhes pequenos         |
| `silver-light`  | `#E2E5ED` | —                      | Bordas de input, separadores sutis           |
| `off-white`     | `#F5F7FA` | —                      | Canvas / fundo principal da aplicação        |
| `surface`       | `#FFFFFF` | —                      | Cards, modais, painéis elevados              |
| `surface-sunken`| `#ECEEF2` | —                      | Fundo de inputs, linhas alternadas de tabela |

> **Prata/cinza para detalhes pequenos:** use `silver` (`#C4C9D4`) para ícones
> decorativos, separadores e metadados de baixa hierarquia. Use `ink-muted`
> (`#6B7280`) para texto secundário legível. Nunca use cinza claro para texto.

### 2.5 Semântico — Significado universal

| Token           | Hex       | Uso                                                        |
|-----------------|-----------|------------------------------------------------------------|
| `green`         | `#16A34A` | Sucesso, confirmação, OS concluída, pagamento aprovado     |
| `green-tint`    | `#DCFCE7` | Fundo de banner de sucesso                                 |
| `red`           | `#DC2626` | Erro, cancelamento, alerta crítico, estoque zerado         |
| `red-tint`      | `#FEE2E2` | Fundo de banner de erro                                    |
| `amber`         | `#D97706` | Aviso, pendência, estoque baixo, trial expirando           |
| `amber-tint`    | `#FEF3C7` | Fundo de banner de aviso                                   |
| `sky`           | `#0EA5E9` | Informativo neutro, notificações não-críticas              |
| `sky-tint`      | `#E0F2FE` | Fundo de banner informativo                                |

### 2.6 Paleta completa — referência rápida

```
ESTRUTURA
  #0D2B52  navy-base        ████████  sidebar / brand panel
  #193F7A  navy-mid         ████████  ativo / badge
  #1E5099  navy-hi          ████████  hover sidebar / foco
  #F0F4FF  on-navy          ████████  texto sobre navy
  #8DA4C8  on-navy-muted    ████████  texto muted sobre navy
  #243D66  navy-line        ████████  divisor dentro da sidebar

AÇÃO
  #1E5FD8  orbix-blue       ████████  botão primário / link / foco
  #1A4EBA  orbix-blue-dark  ████████  hover/pressed
  #3D7AE8  orbix-blue-light ████████  disabled / borda suave
  #E8EFFE  orbix-blue-tint  ████████  fundo de seleção

NEUTROS
  #1A1A2E  ink              ████████  headings
  #333344  ink-80           ████████  corpo de texto
  #6B7280  ink-muted        ████████  texto secundário
  #C4C9D4  silver           ████████  bordas / ícone decorativo
  #E2E5ED  silver-light     ████████  borda de input
  #F5F7FA  off-white        ████████  canvas
  #FFFFFF  surface          ████████  card / modal
  #ECEEF2  surface-sunken   ████████  input / linha alternada

SEMÂNTICO
  #16A34A  green            ████████  sucesso
  #DC2626  red              ████████  erro / perigo
  #D97706  amber            ████████  aviso / atenção
  #0EA5E9  sky              ████████  informativo
```

---

## 3. Tipografia

Mantemos a dupla atual — geometria + humanismo, excelente contraste de personalidade.

| Família   | Papel                          | Pesos usados    |
|-----------|--------------------------------|-----------------|
| **Sora**  | Display, títulos, headings     | 600 · 700       |
| **Manrope** | Corpo, UI, labels, botões   | 400 · 600 · 700 |

### Escala tipográfica

| Token           | Família  | Tamanho | Peso | Uso                              |
|-----------------|----------|---------|------|----------------------------------|
| `display-sm`    | Sora     | 34px    | 700  | Título de página de marketing    |
| `headline-md`   | Sora     | 28px    | 700  | Título principal de tela         |
| `headline-sm`   | Sora     | 23px    | 700  | Título de seção grande           |
| `title-lg`      | Sora     | 19px    | 600  | Header de card / título de tabela|
| `title-md`      | Manrope  | 15px    | 700  | Label de grupo, nav item ativo   |
| `body`          | Manrope  | 14px    | 400  | Texto corrido, células de tabela |
| `body-strong`   | Manrope  | 14px    | 600  | Ênfase em texto corrido          |
| `label`         | Manrope  | 12.5px  | 600  | Chips, badges, cabeçalho de col. |
| `caption`       | Manrope  | 11px    | 400  | Metadados, timestamps, sublegenda|

### Pisos obrigatórios (padrão SysOne)

Auditoria de usabilidade e acessibilidade SysOne. Estes são **mínimos**, não
sugestões — valem para todo o produto, sem exceção:

| Categoria                                   | Mínimo |
|---------------------------------------------|--------|
| Título de página                            | 18px   |
| Texto padrão de componente (item de lista)  | 16px   |
| Texto operacional / descritivo              | 14px   |
| Legenda / informação de baixa relevância    | 12px   |
| **Qualquer texto**                          | **12px** |

Contraste mínimo: 4,5:1 para texto normal; 3:1 para texto grande (≥18pt, ou
≥16pt em negrito) e para componentes não textuais (botões, bordas de campo).

**Como o contraste é garantido (não confie no olho):**

- `front/test/acessibilidade_padrao_sysone_test.dart` calcula a razão WCAG de
  verdade sobre os tokens reais — as duas paletas hand-tuned, o tema
  monocromático e as 12 paletas derivadas de cor-semente. Quebrou o piso,
  quebrou o build.
- As paletas derivadas miram **luminância**, não lightness do HSL
  (`NeuTokens._hslLum`). Uma `l: 0.305` fixa rende luminância ~2x maior em
  amarelo do que em azul — era por isso que o mesmo token de texto passava num
  matiz e reprovava em outro.
- **Cor de superfície ≠ cor de texto.** `navy` é a ação primária (fundo);
  `accent` é o equivalente para texto. Idem no status da OS: `osStatusColor` é
  gráfico (fatia de rosca, tint, faixa) e `osStatusInk(status, brightness)` é a
  variante legível. Usar a gráfica como rótulo dá 2,3:1 no âmbar.

> A escala de tokens acima (`caption` 11px) é **anterior** a este padrão e está
> abaixo do piso. Ao tocar num componente que ainda use 11px, suba para 12px.

**Como classificar (§3 da auditoria):** o piso depende do PAPEL do texto, não do
lugar onde ele aparece.

| Papel | Exemplos no OrbixHub | Piso |
|---|---|---|
| Título de página / card / seção | título do `ChartCard`, "Análise por região", cabeçalho de diálogo | **18px** |
| Texto padrão de componente | item de lista, rótulo de botão, valor digitado num campo | **16px** |
| Operacional / descritivo | frase explicativa, helper e erro de campo, mensagem de estado, corpo de notificação, link de ação, cabeçalho de tabela | **14px** |
| Legenda / baixa relevância | rótulo de chip, eixo e legenda de gráfico, contador, carimbo de data | **12px** |

**O tema é parte da escala.** `titleMedium` é o estilo de todo título de
card/seção e vinha em 15px; `labelSmall` vinha em 11px, herdado do default do
Material. `acessibilidade_padrao_sysone_test.dart` afere o `TextTheme` inteiro —
varrer `fontSize:` no código não enxerga o que vem do tema.

### Gráficos (§5 da auditoria)

Dois princípios: **nenhuma informação depende só da cor** e **todo valor
relevante é legível no estado enabled, não só no hover**.

- O fl_chart pinta num `Canvas`: para leitor de tela o gráfico é um buraco, e o
  valor de cada ponto só existe no tooltip. Todo canvas passa por
  [`ChartSemantics`], que o tira da árvore de acessibilidade (equivale ao
  `aria-hidden="true"` da recomendação).
- Quando existe legenda em texto real ao lado (é o caso dos donuts, que listam
  categoria **e** valor), ela é a fonte oficial — o desenho fica só decorativo.
- Quando não existe, o `ChartSemantics` recebe um `resumo` textual
  (`resumoSerie`): período, extremos e valor final.
- Cor nunca é o único código: o chip de status leva ícone + rótulo, e a legenda
  do donut leva swatch + nome + valor.

**Regras de ouro:**
- Texto principal nunca abaixo de 14px.
- `ink` (`#1A1A2E`) para títulos; `ink-80` (`#333344`) para corpo; `ink-muted` para secundário.
- Nunca use `silver` ou tons mais claros que `#6B7280` para texto — falha WCAG.

---

## 4. Espaçamento e raio

Baseado em grid de 4px.

| Nível | Valor | Uso                                                  |
|-------|-------|------------------------------------------------------|
| `xs`  | 4px   | Gap interno de badge/chip                            |
| `sm`  | 8px   | Gap entre ícone e label, padding interno de tag      |
| `md`  | 12px  | Gap entre campos de formulário                       |
| `lg`  | 16px  | Padding de card pequeno, gap entre seções            |
| `xl`  | 20px  | Padding lateral da tela no mobile                    |
| `2xl` | 24px  | Gap entre cards                                      |
| `3xl` | 32px  | Padding horizontal de tela no desktop                |

**Raio de borda:**

| Componente              | Raio   |
|-------------------------|--------|
| Cards grandes / modais  | 18px   |
| Inputs / dropdowns      | 12px   |
| Botões primários        | 12px   |
| Chips / badges          | 8px    |
| Tooltips                | 6px    |
| Avatares                | 50%    |

---

## 5. Componentes

### Botão primário

- Fundo: `orbix-blue` (`#1E5FD8`)
- Texto: branco (`#FFFFFF`)
- Hover: `orbix-blue-dark` (`#1A4EBA`)
- Disabled: `silver-light` (`#E2E5ED`) com texto `ink-muted`
- Altura mínima: 48px (desktop) / 52px (mobile)
- Fonte: Manrope 700 15px

### Botão secundário / outlined

- Borda: `silver` (`#C4C9D4`)
- Texto: `ink-80` (`#333344`)
- Hover: fundo `off-white` mais escuro (`surface-sunken`)
- Nunca use borda de cor de ação para botão secundário — reservado para foco

### Input / campo de formulário

- Fundo: `surface-sunken` (`#ECEEF2`)
- Borda repouso: `silver-light` (`#E2E5ED`)
- Borda foco: `orbix-blue` (`#1E5FD8`) 1.6px
- Fundo foco: `orbix-blue-tint` (`#E8EFFE`)
- Label flutuante foco: `orbix-blue`
- Borda erro: `red` (`#DC2626`)

### Sidebar

- Fundo: `navy-base` (`#0D2B52`)
- Texto de nav: `on-navy` (`#F0F4FF`)
- Texto secundário / subtítulo: `on-navy-muted` (`#8DA4C8`)
- Divisor: `navy-line` (`#243D66`)
- Item ativo: fundo `navy-mid` (`#193F7A`) · texto branco · acento lateral `orbix-blue`
- Item hover: fundo `navy-hi` com alpha leve

### Cards

- Fundo: `surface` (`#FFFFFF`)
- Borda: `silver-light` (`#E2E5ED`)
- Elevação: sombra sutil (não material shadow — preferir borda + fundo)
- Raio: 18px

### Badges de status (OS / OS status)

| Status         | Fundo          | Texto       |
|----------------|----------------|-------------|
| Em aberto      | `#E8EFFE`      | `#1E5FD8`   |
| Em andamento   | `#FEF3C7`      | `#D97706`   |
| Aguardando     | `#ECEEF2`      | `#6B7280`   |
| Concluída      | `#DCFCE7`      | `#16A34A`   |
| Cancelada      | `#FEE2E2`      | `#DC2626`   |

---

## 6. Ícones

### Biblioteca e variante

- **Material Icons** — já incluída no Flutter, sem dependência extra.
- Dois estilos usados intencionalmente:

| Estilo | Quando usar | Exemplo Flutter |
|--------|-------------|-----------------|
| **Outlined** | Estado inativo, decorativo, informativo | `Icons.home_outlined` |
| **Filled / Rounded** | Estado **ativo/selecionado**, ação em destaque | `Icons.home_rounded` |

> **Regra de ouro:** o ícone "ganha peso" quando o item está selecionado.
> Nunca use filled como padrão — reservado para sinalizar seleção ou ação primária.

### Pares de ícones por destino de navegação

| Destino        | Inativo (outlined)              | Ativo (rounded/filled)          |
|----------------|---------------------------------|---------------------------------|
| Início         | `Icons.home_outlined`           | `Icons.home_rounded`            |
| Ordens de Serviço | `Icons.build_outlined`       | `Icons.build_rounded`           |
| Clientes       | `Icons.people_alt_outlined`     | `Icons.people_alt_rounded`      |
| Estoque        | `Icons.inventory_2_outlined`    | `Icons.inventory_2_rounded`     |
| Relatórios     | `Icons.bar_chart_outlined`      | `Icons.bar_chart_rounded`       |
| Mensagens      | `Icons.forum_outlined`          | `Icons.forum_rounded`           |
| Equipe         | `Icons.groups_outlined`         | `Icons.groups_rounded`          |
| Configurações  | `Icons.settings_outlined`       | `Icons.settings_rounded`        |
| Desconhecido   | `Icons.extension_outlined`      | `Icons.extension_rounded`       |

### Tamanho e cor

- **18px** — tabelas, listas densas
- **20px** — UI padrão (sidebar, botões, campos)
- **24px** — ações de destaque, empty states
- **Cor inativo:** `on-navy-muted` (`#8DA4C8`) sobre sidebar navy; `ink-muted` (`#6B7280`) sobre canvas claro
- **Cor ativo:** `on-navy` (`#F0F4FF`) sobre sidebar; `orbix-blue` (`#1E5FD8`) sobre canvas
- **Ícones de ação (botões):** sempre outlined, cor contextual
- **Semânticos (success/error):** sempre filled, cor do token semântico

---

## 7. Modo escuro

O sistema suporta dark mode via `ColorScheme.fromSeed`. As regras de inversão:

- Canvas → `#111318` (quase-preto, toque azul)
- Surface → `#1C1F26`
- Texto principal → `#E8EAF0`
- Texto muted → `#8B92A0`
- Sidebar navy → escurece ainda mais para `#080F1F`
- Orbix Blue no dark → `#5B8FEF` (mais claro para contraste)
- Semânticos no dark → tons mais saturados para vencer o fundo escuro

> Regra no código: **nunca use hex fixo para cores de tema** fora do sidebar e
> dos tokens semânticos. Use sempre `Theme.of(context).colorScheme.*` nos
> componentes para herdar claro/escuro automaticamente.

---

## 8. O que mudou vs. direção anterior

| Aspecto          | Antes (tangerina)             | Agora (navy)                        |
|------------------|-------------------------------|-------------------------------------|
| Acento principal | Tangerina `#EC5E12`           | Orbix Blue `#1E5FD8`                |
| Sidebar          | Grafite `#15171C`             | Navy `#0D2B52`                      |
| Canvas           | Warm off-white `#F6F5F2`      | Cool off-white `#F5F7FA`            |
| Personalidade    | Warm-industrial, artesanal    | Professional, enterprise, confiável |
| Verde semântico  | `#0E9F6E`                     | `#16A34A` (mais saturado)           |
| Vermelho sem.    | `#E5484D`                     | `#DC2626` (mais direto)             |

---

## 9. O que ainda falta definir (para próximas rodadas)

- [ ] Logotipo/wordmark atualizado com a nova paleta navy
- [ ] Ilustrações de estado vazio (empty states) — estilo flat ou outlined?
- [ ] Avatar padrão de usuário / placeholder de empresa
- [ ] Motion design — duração e curvas de animação padronizadas
- [ ] Versão impressa / PDF de relatórios — usa a paleta ou vai para P&B?
- [ ] Tema por tenant (o sistema já suporta; precisa de curadoria dos presets)

---

*Gerado em 2026-06-24. Revisar a cada mudança de direção visual relevante.*
