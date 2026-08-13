import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/media_url.dart';
import '../../../core/ui/ui.dart';
import '../domain/customers_models.dart';
import 'plate_labels.dart';
import '../../../core/pdf/document_company.dart';
import 'vehicle_ficha_pdf.dart';

/// Ficha do veículo montada a partir da consulta por placa: mostra na tela
/// TUDO o que o serviço devolveu (identificação, características, registro,
/// bloco técnico completo e todas as correspondências FIPE) e oferece a
/// impressão em duas versões — resumida (1 página) ou completa.
///
/// Read-only: nenhuma ação aqui gasta consulta (os dados já vieram); imprimir
/// é local. Responsivo — no mobile o diálogo ocupa a largura e rola.
Future<void> showVehicleFichaDialog(
  BuildContext context, {
  required PlateInfo info,
  DocumentCompany? company,
  String? apelido,
  String? customerName,
  String? km,
  String? photoUrl,
}) {
  final ficha = VehicleFichaDialog(
    info: info,
    company: company,
    apelido: apelido,
    customerName: customerName,
    km: km,
    photoUrl: photoUrl,
  );
  return showNeuDialog<void>(context, dialog: ficha.build(context));
}

class VehicleFichaDialog {
  const VehicleFichaDialog({
    required this.info,
    this.company,
    this.apelido,
    this.customerName,
    this.km,
    this.photoUrl,
  });

  final PlateInfo info;
  final DocumentCompany? company;
  final String? apelido;
  final String? customerName;
  final String? km;

  /// Foto do veículo (cadastro). Vai impressa na ficha quando existir.
  final String? photoUrl;

  /// Baixa a foto do veículo para embutir no PDF. Best-effort: sem foto, foto
  /// fora do ar ou host inalcançável, a ficha sai sem imagem em vez de falhar.
  Future<pw.ImageProvider?> _fetchPhoto() async {
    final url = resolveMediaUrl(photoUrl);
    if (url == null) return null;
    try {
      return await networkImage(url);
    } on Object {
      return null;
    }
  }

  Future<void> _print(BuildContext context, {required bool completa}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final photo = await _fetchPhoto();
      await Printing.layoutPdf(
        onLayout: (format) => completa
            ? buildVehicleFichaCompletaPdf(
                info,
                format,
                company: company,
                apelido: apelido,
                customerName: customerName,
                km: km,
                photo: photo,
              )
            : buildVehicleFichaPdf(
                info,
                format,
                company: company,
                apelido: apelido,
                customerName: customerName,
                km: km,
                photo: photo,
              ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    }
  }

  /// Monta o diálogo. Recebe o contexto de quem abriu (o mesmo Navigator), o
  /// que basta para fechar e para os snackbars de erro de impressão.
  NeuDialog build(BuildContext context) {
    final neu = context.neu;
    final mobile = context.isMobile;

    final titulo = [info.marca, info.modelo]
        .where((p) => (p ?? '').isNotEmpty)
        .cast<String>()
        .join(' ');

    final identificacao = <(String, String?)>[
      ('Placa', info.placa),
      ('Placa anterior', info.placaAlternativa),
      ('Apelido', apelido),
      ('Cliente', customerName),
      ('Marca', info.marca),
      ('Modelo', info.modelo),
      ('Marca/modelo (registro)', info.marcaModelo),
      ('Versão', info.versao == info.modelo ? null : info.versao),
      ('Ano de fabricação', info.ano),
      ('Ano do modelo', info.anoModelo),
      ('Cor', info.cor),
      ('Chassi', info.chassi),
      ('KM atual', km),
    ];

    final caracteristicas = <(String, String?)>[
      ('Combustível', info.combustivel),
      ('Cilindradas', info.cilindradas),
      ('Tipo de veículo', info.tipoVeiculo),
      ('Espécie', info.especie),
      ('Passageiros', info.passageiros),
      ('Segmento', info.segmento),
    ];

    final registro = <(String, String?)>[
      ('Município', info.municipio),
      ('UF', info.uf),
      ('Situação', info.situacao),
      ('Origem', info.origem),
      ('Nacionalidade', info.nacionalidade),
      ('Equivalente FIPE', info.fipeMatch?.modelo?.value),
      ('Dados do registro em', info.consultadoEm),
    ];

    final tecnicos = plateTechnicalRows(info.extra);

    return NeuDialog(
      title: 'Ficha do veículo',
      maxWidth: 720,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Fechar',
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).maybePop(),
          ),
        ),
        NeuButton(
          label: mobile ? 'Resumida' : 'Ficha resumida',
          icon: Icons.article_outlined,
          kind: NeuButtonKind.secondary,
          onPressed: () => _print(context, completa: false),
        ),
        NeuButton(
          label: mobile ? 'Completa' : 'Ficha completa',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () => _print(context, completa: true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho: placa em destaque + modelo.
          Row(
            children: [
              NeuSurface(
                elevation: NeuElevation.flat,
                radius: NeuTokens.rChip,
                color: neu.accent.withValues(alpha: 0.14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  info.placa,
                  style: TextStyle(
                    color: neu.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo.isEmpty ? 'Veículo' : titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (info.cached) ...[
            const SizedBox(height: 10),
            Text(
              'Dados do cache da consulta anterior — não gastou consulta.',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          _Section(title: 'Identificação', pairs: identificacao),
          _Section(title: 'Características', pairs: caracteristicas),
          _Section(title: 'Registro', pairs: registro),
          if (tecnicos.isNotEmpty)
            _Section(
              title: 'Dados técnicos e restrições',
              pairs: [for (final (l, v) in tecnicos) (l, v)],
            ),
          if (info.fipeTodos.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Valores de referência FIPE',
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final f in info.fipeTodos) _FipeRow(fipe: f),
          ],
          const SizedBox(height: 14),
          Text(
            'Dados obtidos por consulta à base de veículos emplacados. Podem '
            'estar incompletos ou desatualizados — confira antes de usar.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Bloco de pares rótulo→valor; some inteiro quando não há nada preenchido.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.pairs});

  final String title;
  final List<(String, String?)> pairs;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final filled = [
      for (final (label, value) in pairs)
        if ((value ?? '').trim().isNotEmpty) (label, value!.trim()),
    ];
    if (filled.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            color: neu.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value) in filled)
              SizedBox(
                width: context.isMobile ? double.infinity : 210,
                child: NeuSurface(
                  elevation: NeuElevation.flat,
                  radius: NeuTokens.rField,
                  color: neu.base,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(color: neu.inkFaint, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        value,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Uma correspondência FIPE: modelo + referência à esquerda, valor à direita.
class _FipeRow extends StatelessWidget {
  const _FipeRow({required this.fipe});

  final PlateFipe fipe;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ref = [
      if ((fipe.codigoFipe ?? '').isNotEmpty) 'Cód. ${fipe.codigoFipe}',
      if ((fipe.anoModelo ?? '').isNotEmpty) fipe.anoModelo!,
      if ((fipe.combustivel ?? '').isNotEmpty) fipe.combustivel!,
      if ((fipe.mesReferencia ?? '').isNotEmpty) 'ref. ${fipe.mesReferencia}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuSurface(
        elevation: NeuElevation.flat,
        radius: NeuTokens.rField,
        color: neu.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fipe.modelo ?? '—',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ref.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ref,
                      style: TextStyle(color: neu.inkFaint, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if ((fipe.valor ?? '').isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                fipe.valor!,
                style: TextStyle(
                  color: neu.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
