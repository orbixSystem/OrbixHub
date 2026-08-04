import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/expense_models.dart';
import '../domain/expense_next_due.dart';
import '../domain/expense_status.dart';
import 'expense_form_dialog.dart';
import 'expense_pdf.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';

/// Detalhe de uma conta a pagar. Devolve `true` quando algo mudou (baixa,
/// edição, exclusão) para quem chamou recarregar a lista.
///
/// Recebe o **id**, não o objeto: a porta de entrada mais importante é o clique
/// no lançamento do Caixa, que conhece só o id da despesa que gerou a saída.
Future<bool> showExpenseDetailDialog(
  BuildContext context,
  WidgetRef ref, {
  required String id,
}) async {
  final mudou = await showDialog<bool>(
    context: context,
    builder: (_) => _DetailDialog(id: id),
  );
  return mudou ?? false;
}

class _DetailDialog extends ConsumerStatefulWidget {
  const _DetailDialog({required this.id});

  final String id;

  @override
  ConsumerState<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends ConsumerState<_DetailDialog> {
  /// Carregado uma vez e guardado no State (não num provider `autoDispose`): as
  /// ações daqui recarregam o detalhe, e um provider que se descarta no meio do
  /// `await` já custou "Cannot use ref after dispose" nesta base.
  Future<ExpenseDetail>? _futuro;
  bool _ocupado = false;

  /// `true` quando alguma ação mexeu na conta — é o que volta para a lista.
  bool _mudou = false;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(expensesRepositoryProvider).detalhe(widget.id);
  }

  void _recarregar() {
    setState(() {
      _mudou = true;
      _futuro = ref.read(expensesRepositoryProvider).detalhe(widget.id);
    });
  }

  Future<void> _comAviso(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) _recarregar();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Sempre no `finally`: resetar só no `catch` deixava o spinner girando
      // para sempre no caminho de SUCESSO — foi o "load infinito" das despesas.
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExpenseDetail>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const NeuDialog(
            title: 'Despesa',
            maxWidth: 560,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          final erro = snap.error;
          return NeuDialog(
            title: 'Despesa',
            maxWidth: 560,
            actions: [
              NeuButton(
                label: 'Fechar',
                kind: NeuButtonKind.secondary,
                onPressed: () => Navigator.pop(context, _mudou),
              ),
            ],
            child: Text(
              erro is AppException
                  ? erro.message
                  : 'Não foi possível carregar esta despesa.',
              style: TextStyle(color: context.neu.inkMuted),
            ),
          );
        }
        return _corpo(snap.data!);
      },
    );
  }

  Widget _corpo(ExpenseDetail d) {
    final neu = context.neu;
    final e = d.expense;
    final hoje = DateTime.now();
    final s = e.situacao(hoje);
    final categorias =
        ref.watch(despesasDoMesProvider).value?.categories ?? const [];
    final categoria = categorias.where((c) => c.id == e.categoryId).firstOrNull;
    final proxima = proximaCobranca(
      e,
      regras: [if (d.recurrence != null) d.recurrence!],
      irmas: d.parcelas,
    );

    return NeuDialog(
      title: e.description,
      maxWidth: 560,
      actions: _acoes(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cartaz do estado: valor grande + situação. É a resposta às duas
          // perguntas que trazem alguém a esta tela ("quanto?" e "tá paga?").
          _Cartaz(despesa: e, status: s, hoje: hoje),
          const SizedBox(height: 18),
          _Bloco(
            titulo: 'A conta',
            icone: Icons.description_outlined,
            linhas: [
              if (categoria != null)
                _Linha(
                  rotulo: 'Categoria',
                  valor: categoria.name,
                  icone: iconeDaCategoria(categoria.icon),
                  cor: corHex(categoria.color),
                ),
              _Linha(rotulo: 'Vencimento', valor: _data(e.vencimento)),
              _Linha(
                rotulo: 'Valor previsto',
                valor: e.temValor ? formatMoney(e.amount) : 'a confirmar',
              ),
              _Linha(rotulo: 'Tipo', valor: _tipo(d)),
              if (proxima != null)
                _Linha(
                  rotulo: 'Próxima cobrança',
                  valor: _data(proxima),
                  icone: Icons.event_repeat_outlined,
                ),
            ],
          ),
          if ((e.supplierName ?? '').isNotEmpty ||
              (e.supplierDoc ?? '').isNotEmpty)
            _Bloco(
              titulo: 'Fornecedor',
              icone: Icons.storefront_outlined,
              linhas: [
                if ((e.supplierName ?? '').isNotEmpty)
                  _Linha(rotulo: 'Nome', valor: e.supplierName!),
                if ((e.supplierDoc ?? '').isNotEmpty)
                  _Linha(rotulo: 'CNPJ/CPF', valor: formatCnpj(e.supplierDoc)),
              ],
            ),
          if (e.pago)
            _Bloco(
              titulo: 'Pagamento',
              icone: Icons.payments_outlined,
              linhas: [
                _Linha(rotulo: 'Pago em', valor: _data(e.pagoEm!)),
                if ((e.paidMethod ?? '').isNotEmpty)
                  _Linha(rotulo: 'Forma', valor: methodLabel(e.paidMethod!)),
                _Linha(
                  rotulo: 'Valor pago',
                  valor: formatMoney(e.valorEfetivo),
                  destaque: true,
                ),
                // Divergência mostrada, não escondida: juros e desconto são a
                // razão comum de o pago diferir do previsto, e é justamente o
                // número que alguém veio conferir.
                if (e.paidAmount != null &&
                    e.temValor &&
                    e.paidAmount != e.amount)
                  _Linha(
                    rotulo: e.valorEfetivo > e.amount ? 'Juros/multa' : 'Desconto',
                    valor: formatMoney((e.valorEfetivo - e.amount).abs()),
                    cor: e.valorEfetivo > e.amount ? neu.danger : neu.success,
                  ),
                // Só o ID do lançamento (regra 1): este módulo aponta para o
                // caixa, nunca lê a tabela dele. O caminho de ida e volta com o
                // extrato existe pela ORIGEM gravada no lançamento.
                if (e.cashEntryId != null)
                  const _Linha(
                    rotulo: 'No caixa',
                    valor: 'Saída lançada no livro caixa',
                    icone: Icons.point_of_sale_outlined,
                  ),
              ],
            ),
          if (d.parcelas.isNotEmpty) _BlocoParcelas(detalhe: d, hoje: hoje),
          if (d.recurrence != null)
            _Bloco(
              titulo: 'Despesa fixa',
              icone: Icons.autorenew_rounded,
              linhas: [
                _Linha(
                  rotulo: 'Repete',
                  valor: d.recurrence!.frequency == 'yearly'
                      ? 'Todo ano, dia ${d.recurrence!.dayOfMonth}'
                      : 'Todo mês, dia ${d.recurrence!.dayOfMonth}',
                ),
                if (d.recurrence!.endsOn != null)
                  _Linha(
                    rotulo: 'Até',
                    valor: _data(DateTime.parse(d.recurrence!.endsOn!)),
                  ),
              ],
            ),
          if ((e.notes ?? '').trim().isNotEmpty)
            _Bloco(
              titulo: 'Observação',
              icone: Icons.sticky_note_2_outlined,
              linhas: [_Linha(rotulo: '', valor: e.notes!.trim())],
            ),
        ],
      ),
    );
  }

  /// Rodapé de ações ordenado por INTENÇÃO, como no detalhe da venda: primeiro o
  /// que se faz com a conta, depois o documento, por último fechar.
  List<Widget> _acoes(ExpenseDetail d) {
    final e = d.expense;
    return [
      if (_ocupado)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else ...[
        NeuButton(
          label: e.pago ? 'Desfazer pagamento' : 'Marcar como paga',
          icon: e.pago
              ? Icons.undo_rounded
              : Icons.check_circle_outline_rounded,
          onPressed: () => _comAviso(() async {
            final repo = ref.read(expensesRepositoryProvider);
            if (e.pago) {
              await repo.desmarcarPaga(e.id);
            } else {
              await repo.marcarPaga(e.id);
            }
          }),
        ),
        NeuButton(
          label: 'Editar',
          kind: NeuButtonKind.secondary,
          onPressed: () async {
            final ok = await showExpenseFormDialog(context, ref, atual: e);
            if (ok && mounted) _recarregar();
          },
        ),
        _BotaoExportar(detalhe: d),
      ],
      NeuButton(
        label: 'Fechar',
        kind: NeuButtonKind.secondary,
        onPressed: () => Navigator.pop(context, _mudou),
      ),
    ];
  }

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _tipo(ExpenseDetail d) {
    if (d.expense.parcelada) {
      return 'Compra parcelada (${d.expense.rotuloParcela})';
    }
    if (d.expense.fixa) return 'Despesa fixa';
    return 'Despesa única';
  }
}

/// Valor grande + chip de situação.
class _Cartaz extends StatelessWidget {
  const _Cartaz({
    required this.despesa,
    required this.status,
    required this.hoje,
  });

  final Expense despesa;
  final ExpenseStatus status;
  final DateTime hoje;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = corDoStatus(neu, status);
    final dias = diasAte(despesa.vencimento, hoje);

    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    despesa.temValor
                        ? formatMoney(despesa.valorEfetivo)
                        : 'valor a confirmar',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: despesa.temValor ? 26 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(iconeDoStatus(status), size: 14, color: cor),
                    const SizedBox(width: 5),
                    Text(
                      textoDoPrazo(status, dias),
                      style: TextStyle(
                        color: cor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (despesa.parcelada)
            NeuStatusChip(
              label: 'Parcela ${despesa.rotuloParcela}',
              color: neu.inkMuted,
              tint: neu.navy.withValues(alpha: .08),
            ),
        ],
      ),
    );
  }
}

/// Bloco titulado do detalhe.
class _Bloco extends StatelessWidget {
  const _Bloco({
    required this.titulo,
    required this.icone,
    required this.linhas,
  });

  final String titulo;
  final IconData icone;
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, size: 15, color: neu.inkFaint),
              const SizedBox(width: 6),
              Text(
                titulo.toUpperCase(),
                style: TextStyle(
                  color: neu.inkFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...linhas,
        ],
      ),
    );
  }
}

/// Rótulo à esquerda, valor à direita.
class _Linha extends StatelessWidget {
  const _Linha({
    required this.rotulo,
    required this.valor,
    this.icone,
    this.cor,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final IconData? icone;
  final Color? cor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rotulo.isNotEmpty)
            SizedBox(
              width: 132,
              child: Text(
                rotulo,
                style: TextStyle(color: neu.inkMuted, fontSize: 13),
              ),
            ),
          if (icone != null) ...[
            Icon(icone, size: 14, color: cor ?? neu.inkFaint),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: cor ?? neu.ink,
                fontSize: 13.5,
                fontWeight: destaque ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// As irmãs do parcelamento, com total e quantas já foram pagas.
///
/// Mostrar o grupo é o ponto do parcelamento: uma parcela isolada não responde
/// "quanto ainda falta desta compra", que é a pergunta de quem abre a conta.
class _BlocoParcelas extends StatelessWidget {
  const _BlocoParcelas({required this.detalhe, required this.hoje});

  final ExpenseDetail detalhe;
  final DateTime hoje;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final pagas = detalhe.parcelasPagas;
    final total = detalhe.parcelas.length;
    final falta = detalhe.parcelas
        .where((p) => !p.pago)
        .fold<num>(0, (a, p) => a + p.amount);

    return _Bloco(
      titulo: 'Parcelamento',
      icone: Icons.view_week_outlined,
      linhas: [
        _Linha(
          rotulo: 'Total da compra',
          valor: formatMoney(detalhe.totalParcelado),
          destaque: true,
        ),
        _Linha(rotulo: 'Pagas', valor: '$pagas de $total'),
        if (falta > 0)
          _Linha(rotulo: 'Falta pagar', valor: formatMoney(falta)),
        const SizedBox(height: 6),
        for (final p in detalhe.parcelas)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  p.pago
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: p.pago
                      ? neu.success
                      : corDoStatus(neu, p.situacao(hoje)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    p.rotuloParcela,
                    style: TextStyle(
                      color: neu.inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${p.vencimento.day.toString().padLeft(2, '0')}/'
                    '${p.vencimento.month.toString().padLeft(2, '0')}/'
                    '${p.vencimento.year}',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                ),
                Text(
                  formatMoney(p.amount),
                  style: TextStyle(
                    color: p.pago ? neu.inkFaint : neu.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: p.pago ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Exporta a ficha em PDF. Direto para o arquivo, sem abrir diálogo de impressão
/// — mesma decisão já tomada na OS e na venda.
class _BotaoExportar extends ConsumerStatefulWidget {
  const _BotaoExportar({required this.detalhe});

  final ExpenseDetail detalhe;

  @override
  ConsumerState<_BotaoExportar> createState() => _BotaoExportarState();
}

class _BotaoExportarState extends ConsumerState<_BotaoExportar> {
  bool _gerando = false;

  Future<void> _exportar() async {
    setState(() => _gerando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final company = await ref.read(companyForDocumentsProvider.future);
      final cats =
          ref.read(despesasDoMesProvider).value?.categories ?? const [];
      final cat = cats
          .where((c) => c.id == widget.detalhe.expense.categoryId)
          .firstOrNull;

      final bytes = await buildExpensePdf(
        widget.detalhe,
        PdfPageFormat.a4,
        company: company,
        categoria: cat?.name,
      );
      // Nome legível a partir da descrição: "despesa-aluguel-do-galpao.pdf" diz
      // o que é na pasta de downloads; um uuid não diz nada.
      final slug = widget.detalhe.expense.description
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final nome =
          'despesa-${slug.isEmpty ? widget.detalhe.expense.id.substring(0, 8) : slug}.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      messenger.showSnackBar(SnackBar(content: Text('PDF exportado: $nome')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      label: 'Exportar PDF',
      icon: Icons.picture_as_pdf_outlined,
      kind: NeuButtonKind.secondary,
      loading: _gerando,
      onPressed: _gerando ? null : _exportar,
    );
  }
}
