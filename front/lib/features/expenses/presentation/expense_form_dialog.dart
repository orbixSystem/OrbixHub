import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../domain/expense_models.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';

/// Formulário de uma conta a pagar. Devolve `true` quando gravou.
Future<bool> showExpenseFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Expense? atual,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _FormDialog(atual: atual),
  );
  return ok ?? false;
}

class _FormDialog extends ConsumerStatefulWidget {
  const _FormDialog({this.atual});

  final Expense? atual;

  @override
  ConsumerState<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends ConsumerState<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _descCtrl =
      TextEditingController(text: widget.atual?.description ?? '');
  late final _valorCtrl = TextEditingController(
    text: (widget.atual?.temValor ?? false)
        ? widget.atual!.amount.toStringAsFixed(2).replaceAll('.', ',')
        : '',
  );
  late final _obsCtrl = TextEditingController(text: widget.atual?.notes ?? '');

  late DateTime _vencimento = widget.atual?.vencimento ?? DateTime.now();
  late String? _categoriaId = widget.atual?.categoryId;
  // Edição não mexe na regra: repetir é decisão da criação. Alterar a recorrência
  // de uma conta já gerada reescreveria meses que a cliente talvez já tenha
  // conferido.
  late bool _repete = false;
  bool _salvando = false;

  bool get _editando => widget.atual != null;

  @override
  void dispose() {
    _descCtrl.dispose();
    _valorCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      // Janela larga: conta atrasada de meses atrás precisa poder ser lançada,
      // e boleto de fornecedor vence bem à frente.
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: 'Vencimento',
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
    );
    if (escolhida != null) setState(() => _vencimento = escolhida);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final texto = _valorCtrl.text.trim();
    // Vazio = "valor a confirmar" (grava 0). Não é erro de preenchimento: a
    // conta de luz existe antes de a fatura chegar.
    final valor = texto.isEmpty
        ? 0.0
        : (double.tryParse(texto.replaceAll(',', '.')) ?? 0.0);

    final draft = ExpenseDraft(
      description: _descCtrl.text.trim(),
      amount: valor,
      dueDate: _iso(_vencimento),
      categoryId: _categoriaId,
      notes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      limparCategoria: _categoriaId == null,
      recorrencia: (!_editando && _repete)
          ? ExpenseRecurrenceDraft(
              frequency: 'monthly',
              dayOfMonth: _vencimento.day,
            )
          : null,
    );

    final repo = ref.read(expensesRepositoryProvider);
    try {
      if (_editando) {
        await repo.editar(widget.atual!.id, draft);
      } else {
        await repo.criar(draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final categorias =
        ref.watch(despesasDoMesProvider).value?.categories ?? const [];

    return NeuDialog(
      title: _editando ? 'Editar despesa' : 'Nova despesa',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
        ),
        NeuButton(
          label: 'Salvar',
          loading: _salvando,
          onPressed: _salvando ? null : _salvar,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeuTextField(
              label: 'O que é? *',
              controller: _descCtrl,
              hint: 'Aluguel, conta de luz, fornecedor…',
              autofocus: !_editando,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Descreva a despesa.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _CampoData(
              valor: _vencimento,
              onTocar: _salvando ? null : _escolherData,
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Valor',
              controller: _valorCtrl,
              hint: '0,00',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              helper: 'Deixe vazio se ainda não sabe — dá para preencher ao pagar.',
            ),
            const SizedBox(height: 14),
            _SeletorCategoria(
              categorias: categorias,
              selecionada: _categoriaId,
              onMudar: _salvando
                  ? null
                  : (id) => setState(() => _categoriaId = id),
            ),
            if (!_editando) ...[
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                value: _repete,
                onChanged:
                    _salvando ? null : (v) => setState(() => _repete = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Repete todo mês',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _repete
                      ? 'Vai gerar todo dia ${_vencimento.day} dos próximos meses.'
                      : 'Só esta vez.',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
            ],
            const SizedBox(height: 8),
            NeuTextField(
              label: 'Observação',
              controller: _obsCtrl,
              hint: 'Opcional',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de vencimento — abre o date picker ao toque.
class _CampoData extends StatelessWidget {
  const _CampoData({required this.valor, required this.onTocar});

  final DateTime valor;
  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Vence em *',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InkWell(
          onTap: onTocar,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: neu.accent),
                const SizedBox(width: 8),
                Text(
                  '${valor.day.toString().padLeft(2, '0')}/'
                  '${valor.month.toString().padLeft(2, '0')}/${valor.year}',
                  style: TextStyle(color: neu.ink, fontSize: 15),
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_outlined, size: 17, color: neu.inkFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Categorias como chips com ícone e cor — mais rápido de reconhecer que um
/// dropdown de texto, e é o mesmo vocabulário visual da lista.
class _SeletorCategoria extends StatelessWidget {
  const _SeletorCategoria({
    required this.categorias,
    required this.selecionada,
    required this.onMudar,
  });

  final List<ExpenseCategory> categorias;
  final String? selecionada;
  final ValueChanged<String?>? onMudar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (categorias.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Categoria',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in categorias)
              _ChipCategoria(
                categoria: c,
                selecionada: c.id == selecionada,
                // Tocar na já selecionada limpa: sem isso não haveria como
                // voltar para "sem categoria".
                onTap: onMudar == null
                    ? null
                    : () => onMudar!(c.id == selecionada ? null : c.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipCategoria extends StatelessWidget {
  const _ChipCategoria({
    required this.categoria,
    required this.selecionada,
    required this.onTap,
  });

  final ExpenseCategory categoria;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = corHex(categoria.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selecionada ? cor.withValues(alpha: .18) : neu.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionada ? cor : neu.line,
            width: selecionada ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconeDaCategoria(categoria.icon), size: 15, color: cor),
            const SizedBox(width: 6),
            Text(
              categoria.name,
              style: TextStyle(
                color: selecionada ? neu.ink : neu.inkMuted,
                fontSize: 13,
                fontWeight: selecionada ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
