# Caixa — Redesign UX + Parcelamento de Fiado
**Data:** 2026-08-10  
**Status:** implementado  
**Branch:** orbix_melhorias

---

## Problema

A tela de caixa atual tem três problemas centrais:

1. **Ações confusas**: "Receber OS" e "Venda avulsa" aparecem como botões separados, mas Sangria e Suprimento ficam escondidos dentro do diálogo de "Receber OS" num dropdown de "Tipo". O usuário não sabe onde está o quê.

2. **Fiado num tab lateral**: "A receber" é uma das informações mais importantes para o dono de uma oficina, mas virou a terceira aba de uma navegação por segmentos — invisível para quem não sabe que ela existe.

3. **Sem parcelamento / provisionado**: Não há como registrar "1000 em 10x de 100 com vencimento todo dia 10". O sistema aceita recebimento parcial, mas não cria um plano de parcelas com datas.

---

## Solução

### Nova estrutura da tela

**Remove** o `NeuSegmented` de 3 abas. **Substitui** por:

- **Caixa (padrão)**: dia de hoje — banner de fiado no topo (sempre visível), grid de 4 ações claras, lista de movimentos.
- **Histórico**: aba separada acessível por botão no header (só gestão).
- **Fiado**: acessado via banner clicável, não tab.

### As 4 ações do caixa (clareza máxima)

| Botão | Quem vê | O que faz |
|---|---|---|
| **Receber** | `cashier.write` | OS ou Venda — picker, saldo, parcelas |
| **Venda avulsa** | `sale.write` | fluxo de venda (existente) |
| **Sangria** | `cashier.manage` | bottom sheet rápido: valor + descrição |
| **Suprimento** | `cashier.manage` | bottom sheet rápido: valor + descrição |

### Fluxo de recebimento com parcelamento

```
1. Usuário toca "Receber"
2. Escolhe: OS ou Venda
3. Picker busca (existente)
4. Mostra saldo: Total · Pago · A receber
5. Digita valor a receber agora
6. Escolhe forma de pagamento
7. SE valor < saldo E há saldo remanescente:
   → pergunta "Parcelar o restante?"
   → Se sim: define nº de parcelas + dia do vencimento
   → Cria N parcelas no backend
8. Confirma → grava cash_entry + parcelas
```

### Sistema de parcelamento (`receivable_installment`)

Nova tabela para rastrear parcelas de fiado:

```sql
CREATE TABLE receivable_installment (
  id          uuid PRIMARY KEY,
  tenant_id   uuid NOT NULL,   -- RLS
  sale_kind   text NOT NULL,   -- 'os' | 'sale'
  sale_id     uuid NOT NULL,
  amount      numeric(14,2),   -- valor da parcela
  due_date    date NOT NULL,   -- vencimento
  paid_at     timestamptz,     -- quando foi paga (null = pendente)
  entry_id    uuid,            -- cash_entry que quitou (null = pendente)
  notes       text,
  created_at  timestamptz,
  updated_at  timestamptz
);
```

Status derivado: `paid_at IS NULL AND due_date < today` → vencida; `paid_at IS NULL` → pendente; `paid_at IS NOT NULL` → paga.

### Exibição no fiado

Na tela de fiado (acessada via banner), cada título exibe:
- Se tem parcelas: lista as parcelas com vencimento + status (badge colorido)
- Vencida → vermelho, vence hoje → âmbar, próxima → cinza, paga → verde riscado
- Botão "Receber parcela" em cada parcela pendente

---

## Arquivos alterados

### Backend
- `back/prisma/migrations/0045_receivable_installments/migration.sql` — nova tabela
- `back/sql/auth-multitenant-schema.sql` — schema canônico atualizado
- `back/prisma/schema.prisma` — model `receivable_installment`
- `back/src/modules/cashier/dto/installment.dto.ts` — DTOs novos
- `back/src/modules/cashier/cashier.controller.ts` — endpoints de parcela
- `back/src/modules/cashier/cashier.service.impl.ts` — lógica de parcelas

### Frontend
- `front/lib/features/cashier/domain/cashier_models.dart` — modelo `Installment`
- `front/lib/features/cashier/domain/cashier_repository.dart` — métodos de parcela
- `front/lib/features/cashier/data/cashier_repository_impl.dart` — impl HTTP
- `front/lib/features/cashier/presentation/cashier_screen.dart` — redesign
- `front/lib/features/cashier/presentation/sangria_sheet.dart` — bottom sheet sangria
- `front/lib/features/cashier/presentation/suprimento_sheet.dart` — bottom sheet suprimento
- `front/lib/features/cashier/presentation/receber_sheet.dart` — novo fluxo de recebimento

---

## Regras invioláveis mantidas

- RLS + FORCE na nova tabela; `withTenantTx` em todo acesso.
- `receivable_installment` aponta para `sale_id` por ID — nunca toca a tabela de OS/venda.
- Migration aditiva nos 3 lugares.
- Frontend: UI só via repository (interface no domain).
