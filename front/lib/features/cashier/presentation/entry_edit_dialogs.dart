import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// **Editar** × **Corrigir** um lançamento do caixa.
///
/// A distinção não é capricho: um livro caixa não sobrescreve movimento de
/// dinheiro. Então
///  - **Editar** mexe no que o lançamento DIZ (descrição, e categoria que não
///    inverte entrada/saída). O valor continua o mesmo, nada a rastrear.
///  - **Corrigir** mexe no VALOR ou na forma: estorna o original (com motivo) e
///    relança. Para o usuário é uma ação só; no histórico ficam as duas linhas,
///    com o estorno riscado — é assim que se sabe o que aconteceu de verdade.
///
/// Ambas são de gestão (`cashier.manage`), como o estorno.

/// Categorias oferecidas na EDIÇÃO: só as de mesma direção da atual. Trocar
/// despesa (saída) por suprimento (entrada) mudaria o saldo do caixa sem
/// registro nenhum — isso é correção, não edição, e o backend recusa.
List<String> categoriasDaMesmaDirecao(String categoriaAtual) {
  const saidas = {'despesa', 'sangria'};
  return saidas.contains(categoriaAtual)
      ? const ['despesa', 'sangria']
      : const ['os_payment', 'venda_avulsa', 'suprimento'];
}

/// Abre a edição de texto do lançamento. `true` se salvou.
Future<bool> showEditEntryDialog(
  BuildContext context,
  CashEntry entry,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _EditEntryDialog(entry: entry),
      ),
    ) ??
    false;

/// Abre a correção de valor/forma. `true` se corrigiu.
Future<bool> showCorrectEntryDialog(
  BuildContext context,
  CashEntry entry,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _CorrectEntryDialog(entry: entry),
      ),
    ) ??
    false;

/// Estorno do lançamento (cancela o movimento, com motivo obrigatório).
Future<bool> showReverseEntryDialog(
  BuildContext context,
  WidgetRef ref,
  CashEntry entry,
) async {
  final motivoCtrl = TextEditingController();
  final ok = await showNeuDialog<bool>(
    context,
    dialog: NeuDialog(
      title: 'Estornar lançamento',
      maxWidth: 420,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Cancelar',
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Estornar',
            kind: NeuButtonKind.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
      child: NeuTextField(
        label: 'Motivo do estorno',
        controller: motivoCtrl,
        hint: 'Ex.: valor lançado errado',
        maxLength: 500,
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final motivo = motivoCtrl.text.trim();
  if (motivo.length < 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Informe um motivo (mín. 3 caracteres).')),
    );
    return false;
  }
  try {
    await ref.read(cashierControllerProvider.notifier).reverse(entry.id, motivo);
    return true;
  } catch (e) {
    if (context.mounted) {
      showNeuErrorSnackBar(context, '$e');
    }
    return false;
  }
}

/// Ações de gestão de um lançamento: editar o texto, corrigir o valor, estornar.
///
/// Num menu (não em ícones soltos) porque são operações raras e a linha do
/// extrato já carrega valor, hora, forma e cliente — no celular não sobra espaço.
/// Usado no extrato do dia E no histórico: corrigir uma despesa de ontem não
/// deveria exigir voltar para a tela de hoje.
class EntryActionsMenu extends ConsumerWidget {
  const EntryActionsMenu({super.key, required this.entry});

  final CashEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    return PopupMenuButton<String>(
      tooltip: 'Ações do lançamento',
      icon: Icon(Icons.more_vert_rounded, size: 20, color: neu.inkMuted),
      color: neu.surface,
      onSelected: (acao) async {
        switch (acao) {
          case 'editar':
            await showEditEntryDialog(context, entry);
          case 'corrigir':
            await showCorrectEntryDialog(context, entry);
          case 'estornar':
            await showReverseEntryDialog(context, ref, entry);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'editar',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Editar'),
            subtitle: Text('Descrição e categoria'),
          ),
        ),
        PopupMenuItem(
          value: 'corrigir',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.published_with_changes_rounded, size: 18),
            title: Text('Corrigir valor'),
            subtitle: Text('Estorna e relança'),
          ),
        ),
        PopupMenuItem(
          value: 'estornar',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.undo_rounded, size: 18),
            title: Text('Estornar'),
            subtitle: Text('Cancela o lançamento'),
          ),
        ),
      ],
    );
  }
}

class _EditEntryDialog extends ConsumerStatefulWidget {
  const _EditEntryDialog({required this.entry});
  final CashEntry entry;

  @override
  ConsumerState<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends ConsumerState<_EditEntryDialog> {
  late final _descCtrl =
      TextEditingController(text: widget.entry.description ?? '');
  late String _categoria = widget.entry.category;
  bool _salvando = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref.read(cashierRepositoryProvider).updateEntry(
            widget.entry.id,
            description: _descCtrl.text.trim(),
            // Só manda a categoria se mudou — evita um PATCH que não diz nada.
            category: _categoria == widget.entry.category ? null : _categoria,
          );
      ref.invalidate(cashierControllerProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        showNeuErrorSnackBar(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = categoriasDaMesmaDirecao(widget.entry.category);
    return NeuDialog(
      title: 'Editar lançamento',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
        ),
        NeuButton(
          label: 'Salvar',
          loading: _salvando,
          onPressed: _salvando ? null : _salvar,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // O valor aparece, mas como INFORMAÇÃO: aqui não se muda dinheiro.
          _ValorTravado(entry: widget.entry),
          const SizedBox(height: 14),
          if (opcoes.length > 1) ...[
            _Dropdown(
              label: 'Categoria',
              value: _categoria,
              options: opcoes,
              optionLabel: categoryLabel,
              onChanged: _salvando
                  ? null
                  : (v) => setState(() => _categoria = v ?? _categoria),
            ),
            const SizedBox(height: 12),
          ],
          NeuTextField(
            label: 'Descrição',
            controller: _descCtrl,
            hint: 'Ex.: Óleo 5W30 — nota 123',
            maxLength: 500,
          ),
        ],
      ),
    );
  }
}

class _CorrectEntryDialog extends ConsumerStatefulWidget {
  const _CorrectEntryDialog({required this.entry});
  final CashEntry entry;

  @override
  ConsumerState<_CorrectEntryDialog> createState() =>
      _CorrectEntryDialogState();
}

class _CorrectEntryDialogState extends ConsumerState<_CorrectEntryDialog> {
  late final _valorCtrl = TextEditingController(
      text: formatAmountForInput(moneyToDouble(widget.entry.amount)));
  final _motivoCtrl = TextEditingController();
  late String _metodo = widget.entry.method;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _corrigir() async {
    final motivo = _motivoCtrl.text.trim();
    final valor = moneyToDouble(_valorCtrl.text);
    // Valida antes de fechar: o motivo é o que explica o estorno no histórico.
    if (motivo.length < 3) {
      setState(() => _erro = 'Informe um motivo (mín. 3 caracteres).');
      return;
    }
    if (valor <= 0) {
      setState(() => _erro = 'Informe um valor maior que zero.');
      return;
    }
    setState(() {
      _erro = null;
      _salvando = true;
    });
    try {
      await ref.read(cashierRepositoryProvider).correctEntry(
            widget.entry.id,
            reason: motivo,
            amount: valor,
            method: _metodo,
          );
      ref.invalidate(cashierControllerProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento corrigido: o original ficou estornado.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        showNeuErrorSnackBar(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: 'Corrigir lançamento',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
        ),
        NeuButton(
          label: 'Corrigir',
          loading: _salvando,
          onPressed: _salvando ? null : _corrigir,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dizer ANTES o que vai acontecer: o usuário pediu "editar" e vai ver
          // duas linhas no histórico. Sem este aviso, parece bug.
          _AvisoCorrecao(valorAtual: widget.entry.amount),
          const SizedBox(height: 14),
          NeuTextField(
            label: 'Novo valor (R\$)',
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [DecimalInputFormatter()],
          ),
          const SizedBox(height: 12),
          _Dropdown(
            label: 'Forma',
            value: _metodo,
            options: cashierMethods,
            optionLabel: methodLabel,
            onChanged:
                _salvando ? null : (v) => setState(() => _metodo = v ?? _metodo),
          ),
          const SizedBox(height: 12),
          NeuTextField(
            label: 'Motivo da correção',
            controller: _motivoCtrl,
            hint: 'Ex.: valor digitado errado',
            maxLength: 500,
            errorText: _erro,
          ),
        ],
      ),
    );
  }
}

/// Select no visual do design system (mesmo tratamento dos campos vizinhos).
class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String) optionLabel;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: neu.inkMuted, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            dropdownColor: neu.surface,
            icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(optionLabel(o))),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Mostra o valor do lançamento na EDIÇÃO, deixando claro que ali não se mexe.
class _ValorTravado extends StatelessWidget {
  const _ValorTravado({required this.entry});

  final CashEntry entry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isIn = entry.direction == 'in';
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: neu.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Valor ${isIn ? 'recebido' : 'pago'}: ${formatMoney(entry.amount)}'
              ' · para mudar o valor, use Corrigir',
              style: TextStyle(color: neu.inkMuted, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explica a consequência da correção antes de confirmar.
class _AvisoCorrecao extends StatelessWidget {
  const _AvisoCorrecao({required this.valorAtual});

  final String valorAtual;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: neu.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'O lançamento de ${formatMoney(valorAtual)} será estornado e um '
              'novo será criado com o valor corrigido. Os dois ficam no '
              'histórico — é assim que o caixa fecha.',
              style: TextStyle(color: neu.inkMuted, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
