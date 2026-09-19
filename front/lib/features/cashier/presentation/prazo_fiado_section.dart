import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';

/// Como a dívida foi combinada para ser paga.
///
/// Prazo NÃO é sinônimo de parcelamento: a maior parte do fiado de balcão é
/// "me paga dia 30" — uma data só. Antes, para registrar isso era preciso
/// ligar "Parcelar" e deixar em 1, o que ninguém adivinha; e quem não ligava
/// ficava sem vencimento nenhum, aparecendo como vencido no dia seguinte.
enum ModoPrazo {
  /// Fiado sem data combinada. Continua na carteira (e envelhecendo), mas não
  /// é atraso — ninguém combinou nada para ser descumprido.
  semPrazo,

  /// Uma data combinada. Gravada como plano de UMA parcela: o modelo de
  /// parcelas já existe, então não há caminho paralelo para manter em dia.
  dataUnica,

  /// Duas ou mais parcelas mensais.
  parcelado,
}

/// O prazo escolhido — valor imutável que o diálogo guarda no estado.
class PrazoFiado {
  const PrazoFiado({
    this.modo = ModoPrazo.semPrazo,
    this.dataUnica,
    this.parcelas = 2,
    this.diaVencimento = 10,
    this.primeiraParcela,
  });

  final ModoPrazo modo;
  final DateTime? dataUnica;
  final int parcelas;
  final int diaVencimento;
  final DateTime? primeiraParcela;

  PrazoFiado copyWith({
    ModoPrazo? modo,
    DateTime? dataUnica,
    int? parcelas,
    int? diaVencimento,
    DateTime? primeiraParcela,
  }) =>
      PrazoFiado(
        modo: modo ?? this.modo,
        dataUnica: dataUnica ?? this.dataUnica,
        parcelas: parcelas ?? this.parcelas,
        diaVencimento: diaVencimento ?? this.diaVencimento,
        primeiraParcela: primeiraParcela ?? this.primeiraParcela,
      );

  /// Há algo a gravar? `semPrazo` não gera plano nenhum.
  bool get temPlano => modo != ModoPrazo.semPrazo;

  /// O plano a enviar, ou `null` quando não há prazo combinado.
  ///
  /// Converter aqui — e não em cada diálogo — é o que garante que a venda a
  /// prazo, a venda comum fiada e o recebimento parcial gravem a MESMA coisa.
  InstallmentPlanDraft? planoPara({
    required String saleKind,
    required String saleId,
    required double valor,
  }) {
    switch (modo) {
      case ModoPrazo.semPrazo:
        return null;
      case ModoPrazo.dataUnica:
        final data = dataUnica ?? _padraoDataUnica();
        return InstallmentPlanDraft(
          saleKind: saleKind,
          saleId: saleId,
          installmentCount: 1,
          // Com uma parcela só, o servidor usa `firstDueDate` como a data
          // dela; `dueDayOfMonth` só serviria para as seguintes. Mesmo assim é
          // obrigatório no contrato (1–28), então vai o dia da própria data.
          dueDayOfMonth: data.day.clamp(1, 28),
          totalAmount: valor,
          firstDueDate: _iso(data),
        );
      case ModoPrazo.parcelado:
        return InstallmentPlanDraft(
          saleKind: saleKind,
          saleId: saleId,
          installmentCount: parcelas,
          dueDayOfMonth: diaVencimento,
          totalAmount: valor,
          firstDueDate:
              primeiraParcela == null ? null : _iso(primeiraParcela!),
        );
    }
  }

  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);
}

DateTime _padraoDataUnica() => DateTime.now().add(const Duration(days: 30));

String dataCurtaBr(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// "Prazo de pagamento": sem prazo, data única ou parcelado.
///
/// Um único widget para os três lugares onde se fia (venda a prazo, venda
/// comum que virou fiado e recebimento parcial de um título) — sem
/// exclusividade: o que dá para combinar num, dá nos outros.
class PrazoFiadoSection extends StatelessWidget {
  const PrazoFiadoSection({
    super.key,
    required this.valor,
    required this.total,
    required this.onChanged,
    this.titulo = 'Prazo de pagamento',
  });

  /// O prazo escolhido.
  final PrazoFiado valor;

  /// Quanto fica a receber — é o que será dividido/cobrado.
  final double total;

  final ValueChanged<PrazoFiado> onChanged;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final porParcela = valor.parcelas > 0 ? total / valor.parcelas : 0.0;
    final data = valor.dataUnica ?? _padraoDataUnica();

    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, size: 16, color: neu.inkMuted),
              const SizedBox(width: 6),
              // Expanded: o título varia por chamador ("Prazo do que fica a
              // receber" é bem mais longo) e num diálogo estreito ele estourava
              // a linha por fração de pixel.
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          NeuSegmented<ModoPrazo>(
            segments: const {
              ModoPrazo.semPrazo: 'Sem prazo',
              ModoPrazo.dataUnica: 'Data única',
              ModoPrazo.parcelado: 'Parcelado',
            },
            selected: valor.modo,
            onChanged: (m) => onChanged(valor.copyWith(modo: m)),
          ),
          const SizedBox(height: 10),
          switch (valor.modo) {
            ModoPrazo.semPrazo => Text(
                'Fica a receber sem data combinada — aparece em "A receber", '
                'mas não conta como atraso.',
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
            ModoPrazo.dataUnica => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final escolhida = await _escolherData(context, data);
                      if (escolhida != null) {
                        onChanged(valor.copyWith(dataUnica: escolhida));
                      }
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('Paga em ${dataCurtaBr(data)}'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatMoney(total)} numa vez só, em ${dataCurtaBr(data)}.',
                    style: TextStyle(color: neu.inkFaint, fontSize: 12),
                  ),
                ],
              ),
            ModoPrazo.parcelado => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NeuStepperField(
                          value: valor.parcelas.toDouble(),
                          decimals: 0,
                          semanticLabel: 'Parcelas',
                          onChanged: (v) => onChanged(
                            valor.copyWith(parcelas: v.round().clamp(1, 60)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NeuStepperField(
                          value: valor.diaVencimento.toDouble(),
                          decimals: 0,
                          semanticLabel: 'Dia do vencimento',
                          onChanged: (v) => onChanged(
                            valor.copyWith(
                                diaVencimento: v.round().clamp(1, 28)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final escolhida = await _escolherData(
                        context,
                        valor.primeiraParcela ?? _padraoDataUnica(),
                      );
                      if (escolhida != null) {
                        onChanged(valor.copyWith(primeiraParcela: escolhida));
                      }
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      valor.primeiraParcela == null
                          ? '1ª parcela: próximo dia ${valor.diaVencimento}'
                          : '1ª parcela: ${dataCurtaBr(valor.primeiraParcela!)}',
                    ),
                  ),
                  Text(
                    '${valor.parcelas}× de ${formatMoney(porParcela)} '
                    '(1 a 60 parcelas, dia 1 a 28).',
                    style: TextStyle(color: neu.inkFaint, fontSize: 12),
                  ),
                ],
              ),
          },
        ],
      ),
    );
  }

  Future<DateTime?> _escolherData(BuildContext context, DateTime inicial) {
    final hoje = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: inicial.isBefore(hoje) ? hoje : inicial,
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 365 * 2)),
    );
  }
}
