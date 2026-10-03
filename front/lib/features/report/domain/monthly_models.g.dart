// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VisaoMensal _$VisaoMensalFromJson(Map<String, dynamic> json) => _VisaoMensal(
  periodo: json['periodo'] == null
      ? const PeriodoMensal()
      : PeriodoMensal.fromJson(json['periodo'] as Map<String, dynamic>),
  kpis:
      (json['kpis'] as List<dynamic>?)
          ?.map((e) => KpiMensal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <KpiMensal>[],
  sinais:
      (json['sinais'] as List<dynamic>?)
          ?.map((e) => SinalMensal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SinalMensal>[],
  graficos: json['graficos'] == null
      ? const GraficosDoMes()
      : GraficosDoMes.fromJson(json['graficos'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VisaoMensalToJson(_VisaoMensal instance) =>
    <String, dynamic>{
      'periodo': instance.periodo.toJson(),
      'kpis': instance.kpis.map((e) => e.toJson()).toList(),
      'sinais': instance.sinais.map((e) => e.toJson()).toList(),
      'graficos': instance.graficos.toJson(),
    };

_GraficosDoMes _$GraficosDoMesFromJson(Map<String, dynamic> json) =>
    _GraficosDoMes(
      serieDiaria:
          (json['serieDiaria'] as List<dynamic>?)
              ?.map((e) => PontoDiario.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PontoDiario>[],
      despesasPorCategoria:
          (json['despesasPorCategoria'] as List<dynamic>?)
              ?.map((e) => FatiaCategoria.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FatiaCategoria>[],
    );

Map<String, dynamic> _$GraficosDoMesToJson(_GraficosDoMes instance) =>
    <String, dynamic>{
      'serieDiaria': instance.serieDiaria.map((e) => e.toJson()).toList(),
      'despesasPorCategoria': instance.despesasPorCategoria
          .map((e) => e.toJson())
          .toList(),
    };

_PontoDiario _$PontoDiarioFromJson(Map<String, dynamic> json) => _PontoDiario(
  dia: json['dia'] as String? ?? '',
  valor: json['valor'] as num? ?? 0,
);

Map<String, dynamic> _$PontoDiarioToJson(_PontoDiario instance) =>
    <String, dynamic>{'dia': instance.dia, 'valor': instance.valor};

_FatiaCategoria _$FatiaCategoriaFromJson(Map<String, dynamic> json) =>
    _FatiaCategoria(
      categoria: json['categoria'] as String? ?? '',
      total: json['total'] as num? ?? 0,
    );

Map<String, dynamic> _$FatiaCategoriaToJson(_FatiaCategoria instance) =>
    <String, dynamic>{'categoria': instance.categoria, 'total': instance.total};

_PeriodoMensal _$PeriodoMensalFromJson(Map<String, dynamic> json) =>
    _PeriodoMensal(
      de: json['de'] as String? ?? '',
      ate: json['ate'] as String? ?? '',
      rotulo: json['rotulo'] as String? ?? '',
    );

Map<String, dynamic> _$PeriodoMensalToJson(_PeriodoMensal instance) =>
    <String, dynamic>{
      'de': instance.de,
      'ate': instance.ate,
      'rotulo': instance.rotulo,
    };

_VariacaoMensal _$VariacaoMensalFromJson(Map<String, dynamic> json) =>
    _VariacaoMensal(
      anterior: json['anterior'] as num? ?? 0,
      pct: json['pct'] as num? ?? 0,
    );

Map<String, dynamic> _$VariacaoMensalToJson(_VariacaoMensal instance) =>
    <String, dynamic>{'anterior': instance.anterior, 'pct': instance.pct};

_KpiMensal _$KpiMensalFromJson(Map<String, dynamic> json) => _KpiMensal(
  chave: json['chave'] as String? ?? '',
  rotulo: json['rotulo'] as String? ?? '',
  valor: json['valor'] as num? ?? 0,
  formato: json['formato'] as String? ?? 'numero',
  variacao: json['variacao'] == null
      ? null
      : VariacaoMensal.fromJson(json['variacao'] as Map<String, dynamic>),
  maiorEhMelhor: json['maiorEhMelhor'] as bool? ?? true,
);

Map<String, dynamic> _$KpiMensalToJson(_KpiMensal instance) =>
    <String, dynamic>{
      'chave': instance.chave,
      'rotulo': instance.rotulo,
      'valor': instance.valor,
      'formato': instance.formato,
      'variacao': instance.variacao?.toJson(),
      'maiorEhMelhor': instance.maiorEhMelhor,
    };

_SinalMensal _$SinalMensalFromJson(Map<String, dynamic> json) => _SinalMensal(
  chave: json['chave'] as String? ?? '',
  severidade: json['severidade'] as String? ?? 'info',
  titulo: json['titulo'] as String? ?? '',
  detalhe: json['detalhe'] as String? ?? '',
  numeros:
      (json['numeros'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as num),
      ) ??
      const <String, num>{},
);

Map<String, dynamic> _$SinalMensalToJson(_SinalMensal instance) =>
    <String, dynamic>{
      'chave': instance.chave,
      'severidade': instance.severidade,
      'titulo': instance.titulo,
      'detalhe': instance.detalhe,
      'numeros': instance.numeros,
    };

_NarrativaMensal _$NarrativaMensalFromJson(Map<String, dynamic> json) =>
    _NarrativaMensal(
      titulo: json['titulo'] as String? ?? '',
      leitura: json['leitura'] as String? ?? '',
      alertas:
          (json['alertas'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      recomendacoes:
          (json['recomendacoes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$NarrativaMensalToJson(_NarrativaMensal instance) =>
    <String, dynamic>{
      'titulo': instance.titulo,
      'leitura': instance.leitura,
      'alertas': instance.alertas,
      'recomendacoes': instance.recomendacoes,
    };

_ResumoMensal _$ResumoMensalFromJson(Map<String, dynamic> json) =>
    _ResumoMensal(
      period: json['period'] as String? ?? '',
      periodo: json['periodo'] == null
          ? const PeriodoMensal()
          : PeriodoMensal.fromJson(json['periodo'] as Map<String, dynamic>),
      kpis:
          (json['kpis'] as List<dynamic>?)
              ?.map((e) => KpiMensal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <KpiMensal>[],
      sinais:
          (json['sinais'] as List<dynamic>?)
              ?.map((e) => SinalMensal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SinalMensal>[],
      narrativa: json['narrativa'] == null
          ? const NarrativaMensal()
          : NarrativaMensal.fromJson(json['narrativa'] as Map<String, dynamic>),
      aiModel: json['aiModel'] as String? ?? '',
      aiStatus: json['aiStatus'] as String? ?? 'ok',
      generatedAt: json['generatedAt'] as String? ?? '',
    );

Map<String, dynamic> _$ResumoMensalToJson(_ResumoMensal instance) =>
    <String, dynamic>{
      'period': instance.period,
      'periodo': instance.periodo.toJson(),
      'kpis': instance.kpis.map((e) => e.toJson()).toList(),
      'sinais': instance.sinais.map((e) => e.toJson()).toList(),
      'narrativa': instance.narrativa.toJson(),
      'aiModel': instance.aiModel,
      'aiStatus': instance.aiStatus,
      'generatedAt': instance.generatedAt,
    };

_ResumoMensalPagina _$ResumoMensalPaginaFromJson(Map<String, dynamic> json) =>
    _ResumoMensalPagina(
      resumo: json['resumo'] == null
          ? null
          : ResumoMensal.fromJson(json['resumo'] as Map<String, dynamic>),
      periodos:
          (json['periodos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$ResumoMensalPaginaToJson(_ResumoMensalPagina instance) =>
    <String, dynamic>{
      'resumo': instance.resumo?.toJson(),
      'periodos': instance.periodos,
    };
