import 'package:freezed_annotation/freezed_annotation.dart';

part 'monthly_models.freezed.dart';
part 'monthly_models.g.dart';

/// A leitura do mês: `GET /report/overview` (calculado na hora) e a parte
/// `metrics`/`signals` do resumo gravado.
///
/// Os mesmos números alimentam a tela e o texto do resumo — é por isso que o
/// servidor devolve as duas coisas da mesma função. Recalcular no cliente faria
/// a tela e o texto divergirem no primeiro ajuste.
@freezed
abstract class VisaoMensal with _$VisaoMensal {
  const factory VisaoMensal({
    @Default(PeriodoMensal()) PeriodoMensal periodo,
    @Default(<KpiMensal>[]) List<KpiMensal> kpis,
    @Default(<SinalMensal>[]) List<SinalMensal> sinais,
    @Default(GraficosDoMes()) GraficosDoMes graficos,
  }) = _VisaoMensal;

  factory VisaoMensal.fromJson(Map<String, dynamic> json) =>
      _$VisaoMensalFromJson(json);
}

/// Os dados dos gráficos do mês. Vêm do mesmo endpoint dos KPIs: um gráfico
/// que busca sozinho acabaria mostrando um período diferente do número ao lado.
@freezed
abstract class GraficosDoMes with _$GraficosDoMes {
  const factory GraficosDoMes({
    @Default(<PontoDiario>[]) List<PontoDiario> serieDiaria,
    @Default(<FatiaCategoria>[]) List<FatiaCategoria> despesasPorCategoria,
    @Default(<MovimentoDiario>[]) List<MovimentoDiario> movimentoPorDia,
    @Default(<FatiaStatus>[]) List<FatiaStatus> osPorStatus,
    @Default(<FatiaForma>[]) List<FatiaForma> formasDePagamento,
  }) = _GraficosDoMes;

  factory GraficosDoMes.fromJson(Map<String, dynamic> json) =>
      _$GraficosDoMesFromJson(json);
}

@freezed
abstract class PontoDiario with _$PontoDiario {
  const factory PontoDiario({
    /// "2026-09-17".
    @Default('') String dia,
    @Default(0) num valor,
  }) = _PontoDiario;

  factory PontoDiario.fromJson(Map<String, dynamic> json) =>
      _$PontoDiarioFromJson(json);
}

@freezed
abstract class FatiaCategoria with _$FatiaCategoria {
  const factory FatiaCategoria({
    @Default('') String categoria,
    @Default(0) num total,
  }) = _FatiaCategoria;

  factory FatiaCategoria.fromJson(Map<String, dynamic> json) =>
      _$FatiaCategoriaFromJson(json);
}

/// Entrou e saiu do caixa no mesmo dia — duas séries, um eixo.
@freezed
abstract class MovimentoDiario with _$MovimentoDiario {
  const factory MovimentoDiario({
    /// "2026-09-17".
    @Default('') String dia,
    @Default(0) num entrou,
    @Default(0) num saiu,
  }) = _MovimentoDiario;

  factory MovimentoDiario.fromJson(Map<String, dynamic> json) =>
      _$MovimentoDiarioFromJson(json);
}

/// Quantas ordens pararam em cada status.
@freezed
abstract class FatiaStatus with _$FatiaStatus {
  const factory FatiaStatus({
    @Default('') String status,
    @Default(0) int total,
  }) = _FatiaStatus;

  factory FatiaStatus.fromJson(Map<String, dynamic> json) =>
      _$FatiaStatusFromJson(json);
}

/// Quanto entrou por forma de pagamento.
@freezed
abstract class FatiaForma with _$FatiaForma {
  const factory FatiaForma({
    @Default('') String forma,
    @Default(0) num total,
  }) = _FatiaForma;

  factory FatiaForma.fromJson(Map<String, dynamic> json) =>
      _$FatiaFormaFromJson(json);
}

@freezed
abstract class PeriodoMensal with _$PeriodoMensal {
  const factory PeriodoMensal({
    @Default('') String de,
    @Default('') String ate,
    /// "Setembro/2026".
    @Default('') String rotulo,
  }) = _PeriodoMensal;

  factory PeriodoMensal.fromJson(Map<String, dynamic> json) =>
      _$PeriodoMensalFromJson(json);
}

@freezed
abstract class VariacaoMensal with _$VariacaoMensal {
  const factory VariacaoMensal({
    @Default(0) num anterior,
    @Default(0) num pct,
  }) = _VariacaoMensal;

  factory VariacaoMensal.fromJson(Map<String, dynamic> json) =>
      _$VariacaoMensalFromJson(json);
}

@freezed
abstract class KpiMensal with _$KpiMensal {
  const KpiMensal._();

  const factory KpiMensal({
    @Default('') String chave,
    @Default('') String rotulo,
    @Default(0) num valor,
    /// 'dinheiro' | 'numero'.
    @Default('numero') String formato,
    /// `null` quando não há com o que comparar — o servidor nunca manda um
    /// percentual inventado, e a tela não deve desenhar seta nesse caso.
    VariacaoMensal? variacao,
    @JsonKey(name: 'maiorEhMelhor') @Default(true) bool maiorEhMelhor,
  }) = _KpiMensal;

  factory KpiMensal.fromJson(Map<String, dynamic> json) =>
      _$KpiMensalFromJson(json);

  bool get ehDinheiro => formato == 'dinheiro';

  /// A variação é BOA para o negócio?
  ///
  /// Não é "subiu": despesa subindo e fiado subindo são ruins. Sem esta
  /// pergunta a tela pintaria de verde justamente o que o dono precisa cortar.
  bool? get variacaoEhBoa {
    final v = variacao;
    if (v == null || v.pct == 0) return null;
    return v.pct > 0 ? maiorEhMelhor : !maiorEhMelhor;
  }
}

@freezed
abstract class SinalMensal with _$SinalMensal {
  const SinalMensal._();

  const factory SinalMensal({
    @Default('') String chave,
    /// 'critico' | 'alerta' | 'info'.
    @Default('info') String severidade,
    @Default('') String titulo,
    @Default('') String detalhe,
    @Default(<String, num>{}) Map<String, num> numeros,
  }) = _SinalMensal;

  factory SinalMensal.fromJson(Map<String, dynamic> json) =>
      _$SinalMensalFromJson(json);

  bool get ehCritico => severidade == 'critico';
  bool get ehAlerta => severidade == 'alerta';
}

/// O texto do mês. Em blocos porque a tela e o e-mail montam cada um de um
/// jeito — e porque bloco vazio é detectável, enquanto um texto corrido que
/// "esqueceu" as recomendações passa despercebido.
@freezed
abstract class NarrativaMensal with _$NarrativaMensal {
  const factory NarrativaMensal({
    @Default('') String titulo,
    @Default('') String leitura,
    /// Os números que o texto escolheu comentar. `kpi` é o RÓTULO de um KPI
    /// desta mesma página — o valor vem de lá, nunca do texto.
    @Default(<DestaqueMensal>[]) List<DestaqueMensal> destaques,
    @Default(<String>[]) List<String> oQueFoiBem,
    @Default(<String>[]) List<String> oQuePreocupa,
    @Default(<String>[]) List<String> alertas,
    @Default(<String>[]) List<String> recomendacoes,
    @Default('') String fechamento,
  }) = _NarrativaMensal;

  factory NarrativaMensal.fromJson(Map<String, dynamic> json) =>
      _$NarrativaMensalFromJson(json);
}

/// Um número que o texto comentou.
///
/// Guarda só o RÓTULO do KPI; a cifra é buscada na lista de KPIs da própria
/// página. Assim o texto nunca é a fonte de um número — nem quando foi escrito
/// por um modelo.
@freezed
abstract class DestaqueMensal with _$DestaqueMensal {
  const factory DestaqueMensal({
    @Default('') String kpi,
    @Default('') String comentario,
  }) = _DestaqueMensal;

  factory DestaqueMensal.fromJson(Map<String, dynamic> json) =>
      _$DestaqueMensalFromJson(json);
}

/// O resumo gravado de um mês fechado — `GET /report/monthly`.
@freezed
abstract class ResumoMensal with _$ResumoMensal {
  const ResumoMensal._();

  const factory ResumoMensal({
    /// Primeiro dia do mês analisado, "2026-09-01".
    @Default('') String period,
    @Default(PeriodoMensal()) PeriodoMensal periodo,
    @Default(<KpiMensal>[]) List<KpiMensal> kpis,
    @Default(<SinalMensal>[]) List<SinalMensal> sinais,
    @Default(NarrativaMensal()) NarrativaMensal narrativa,
    @JsonKey(name: 'aiModel') @Default('') String aiModel,
    /// 'ok' = escrito pelo modelo; 'fallback' = montado pelo sistema.
    @JsonKey(name: 'aiStatus') @Default('ok') String aiStatus,
    @JsonKey(name: 'generatedAt') @Default('') String generatedAt,
  }) = _ResumoMensal;

  factory ResumoMensal.fromJson(Map<String, dynamic> json) =>
      _$ResumoMensalFromJson(json);

  /// O texto veio de IA? A tela diz qual foi — creditar à IA um texto que ela
  /// não escreveu é mentir sobre o produto.
  bool get escritoPorIa => aiStatus == 'ok';
}

/// Resposta de `GET /report/monthly`: o resumo (quando existe) e os meses que
/// o seletor pode oferecer.
@freezed
abstract class ResumoMensalPagina with _$ResumoMensalPagina {
  const factory ResumoMensalPagina({
    ResumoMensal? resumo,
    @Default(<String>[]) List<String> periodos,
  }) = _ResumoMensalPagina;

  factory ResumoMensalPagina.fromJson(Map<String, dynamic> json) =>
      _$ResumoMensalPaginaFromJson(json);
}
