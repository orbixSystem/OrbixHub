import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { FREQUENCIES, MAX_PARCELAS, PAYMENT_METHODS } from '../expenses.config';

/**
 * Recorrência pedida na CRIAÇÃO de uma conta.
 *
 * Não existe em `UpdateExpenseDto` de propósito: alterar a regra a partir de uma
 * ocorrência já gerada reescreveria meses que a cliente talvez já tenha
 * conferido. Mexer na regra é operação própria (`PATCH /expenses/recurrences/:id`).
 */
export class RecurrenceInputDto {
  @IsOptional() @IsIn(FREQUENCIES as unknown as string[])
  frequency?: (typeof FREQUENCIES)[number];

  /** 1..31 — o dia PEDIDO. Mês curto encurta na hora de gerar, não aqui. */
  @IsOptional() @IsInt() @Min(1) @Max(31) dayOfMonth?: number;

  /** Só para `yearly` (IPVA, alvará). */
  @IsOptional() @IsInt() @Min(1) @Max(12) monthOfYear?: number;

  /** Sem fim previsto quando ausente. */
  @IsOptional() @IsISO8601() endsOn?: string;
}

/**
 * Nova conta a pagar.
 *
 * Só `description` e `dueDate` são obrigatórios — decisão de produto: sem os
 * dois não existe lembrete, e exigir mais faria a cliente desistir de cadastrar
 * a conta que ainda não chegou.
 *
 * `amount` aceita **0**: significa "valor a confirmar" (a conta de luz existe
 * antes da fatura). Diferente do lançamento no caixa, que exige valor real.
 */
export class CreateExpenseDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;

  @IsString() @MinLength(2) @MaxLength(120) description!: string;

  /** Data civil `YYYY-MM-DD`. */
  @IsISO8601() dueDate!: string;

  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsUUID() categoryId?: string;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => RecurrenceInputDto)
  recorrencia?: RecurrenceInputDto;

  /**
   * Parcelamento: quantas parcelas gerar. Ausente ou 1 = conta única.
   *
   * `amount` continua sendo o **TOTAL da dívida** — o servidor rateia. Pedir o
   * valor da parcela em vez do total obrigaria a cliente a fazer a divisão de
   * cabeça, e o resto em centavos se perderia.
   *
   * Excludente com `recorrencia`: parcela é fatia de um total conhecido,
   * recorrência repete a mesma conta sem fim. O CHECK do banco também barra.
   */
  @IsOptional() @IsInt() @Min(2) @Max(MAX_PARCELAS) parcelas?: number;

  /**
   * Uuids que as parcelas devem receber, na ordem — usado pelo **replay offline**.
   *
   * Sem isto, o cliente sem rede criaria 6 linhas locais com ids próprios e o
   * servidor, no replay, geraria 6 OUTROS ids: o pull seguinte traria 12 parcelas.
   * Quando ausente (caminho online), o banco gera os ids. Precisa ter exatamente
   * `parcelas` itens; o rateio do dinheiro é sempre do servidor.
   */
  @IsOptional() @IsArray() @ArrayMaxSize(MAX_PARCELAS) @IsUUID(undefined, { each: true })
  installmentIds?: string[];

  /** Idem: o grupo gerado no cliente, para o espelho local casar com o servidor. */
  @IsOptional() @IsUUID() installmentGroupId?: string;

  /** Razão social / nome de quem cobrou (snapshot, não FK). */
  @IsOptional() @IsString() @MaxLength(160) supplierName?: string;

  /**
   * CNPJ (14) ou CPF (11) do fornecedor, **só dígitos** — o service normaliza o
   * que vier com máscara antes de gravar.
   */
  @IsOptional() @IsString() @MaxLength(20) supplierDoc?: string;
}

/** Edição de UMA conta (não toca na regra que a gerou). */
export class UpdateExpenseDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(120) description?: string;
  @IsOptional() @IsISO8601() dueDate?: string;

  /**
   * Valor. **Numa conta PARCELADA é o TOTAL da compra**, não o valor desta
   * parcela — o serviço refaz o rateio entre as irmãs em aberto (as pagas ficam
   * como estão e são abatidas do total).
   *
   * O mesmo campo com dois significados é deliberado: para quem está editando,
   * "o valor" de uma compra em 5x é sempre a dívida inteira. Um segundo campo
   * `amountTotal` estaria sempre errado numa das duas situações e obrigaria a
   * tela a escolher qual mandar.
   */
  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsUUID() categoryId?: string;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;

  /**
   * Tirar a categoria exige dizer explicitamente: ausência significa "não mexe",
   * senão nunca haveria como voltar para "sem categoria".
   */
  @IsOptional() @IsBoolean() limparCategoria?: boolean;

  @IsOptional() @IsString() @MaxLength(160) supplierName?: string;
  @IsOptional() @IsString() @MaxLength(20) supplierDoc?: string;

  /** Mesma lógica de `limparCategoria`, para o fornecedor. */
  @IsOptional() @IsBoolean() limparFornecedor?: boolean;

  /**
   * Repare no que NÃO está aqui: `parcelas`. Reparcelar uma conta já lançada
   * significaria apagar as irmãs e recriar outras — operação destrutiva disfarçada
   * de edição. Quem errou o número de parcelas exclui o grupo e cadastra de novo.
   */
}

/**
 * Baixa (pagamento).
 *
 * Tudo opcional: o caminho comum é um toque só, e o servidor assume o valor
 * previsto, a forma padrão do caixa e "agora". Pedir formulário para o caso
 * comum é atrito.
 */
export class PayExpenseDto {
  /** Divergente do previsto quando houve juros/desconto. */
  @IsOptional() @IsNumber() @Min(0) amount?: number;

  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[])
  method?: (typeof PAYMENT_METHODS)[number];

  /** Pagamento lançado com data retroativa ("paguei ontem"). */
  @IsOptional() @IsISO8601() paidAt?: string;

  /** Ponto de caixa, quando o tenant tiver mais de um. */
  @IsOptional() @IsString() @MaxLength(64) deviceId?: string;

  /**
   * Uuid do lançamento do caixa gerado no cliente (replay offline). Repassado ao
   * caixa para que o replay não duplique o lançamento.
   */
  @IsOptional() @IsUUID() cashEntryId?: string;
}
