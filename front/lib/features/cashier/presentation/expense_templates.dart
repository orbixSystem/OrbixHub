import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// Fileira de atalhos de despesa fixa dentro do diálogo de lançamento.
///
/// Não ocupa espaço quando não há modelo cadastrado: uma linha vazia com um
/// "gerenciar" solto atrapalharia quem nunca vai usar o recurso. O botão de
/// gerenciar aparece junto dos chips (quem já tem modelos é quem quer editá-los)
/// e também sozinho na primeira vez, como convite discreto.
class AtalhosDespesa extends ConsumerStatefulWidget {
  const AtalhosDespesa({
    super.key,
    required this.categoria,
    required this.onEscolher,
  });

  /// Categoria corrente do formulário — filtra os modelos compatíveis para não
  /// oferecer "Aluguel" (despesa) quando o operador está fazendo uma sangria.
  final String categoria;
  final ValueChanged<ExpenseTemplate>? onEscolher;

  @override
  ConsumerState<AtalhosDespesa> createState() => _AtalhosDespesaState();
}

class _AtalhosDespesaState extends ConsumerState<AtalhosDespesa> {
  TextEditingController? _ctrl;
  FocusNode? _watchedNode;

  @override
  void dispose() {
    _watchedNode?.removeListener(_onFocusMaybeOpen);
    super.dispose();
  }

  /// Ao ganhar foco com o campo vazio, "cutuca" o controller para o Autocomplete
  /// recalcular as opções (ele só recalcula quando o texto muda) — assim a lista
  /// abre no clique, não só depois de digitar. Mesmo truque do picker da venda.
  void _onFocusMaybeOpen() {
    final node = _watchedNode;
    final c = _ctrl;
    if (node == null || c == null) return;
    if (node.hasFocus && c.text.isEmpty) {
      c.value = const TextEditingValue(text: ' ');
      c.value = TextEditingValue.empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final async = ref.watch(expenseTemplatesProvider);
    // Carregando/erro não mostram nada: o provider já degrada para lista vazia,
    // e um spinner acima do campo de valor faria a tela pular.
    final todos = async.value ?? const <ExpenseTemplate>[];
    final modelos = todos
        .where((t) => t.category == widget.categoria)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: modelos.isEmpty
                // Sem modelo cadastrado o seletor não teria o que oferecer —
                // uma linha de texto ocupa menos que um campo morto.
                ? Text(
                    'Cadastre o que você paga sempre e lance com um toque.',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  )
                : _SeletorModelo(
                    modelos: modelos,
                    onEscolher: widget.onEscolher,
                    registrarCampo: (c, node) {
                      _ctrl = c;
                      if (!identical(_watchedNode, node)) {
                        _watchedNode?.removeListener(_onFocusMaybeOpen);
                        _watchedNode = node;
                        node.addListener(_onFocusMaybeOpen);
                      }
                    },
                    limparCampo: () =>
                        Future.microtask(() => _ctrl?.clear()),
                  ),
          ),
          const SizedBox(width: 8),
          _BotaoGerenciar(
            onDone: () => ref.invalidate(expenseTemplatesProvider),
          ),
        ],
      ),
    );
  }
}

/// Seletor de despesa fixa: um campo de busca em vez de uma nuvem de chips.
///
/// Filtra em MEMÓRIA (a lista já está carregada e é curta) — diferente do picker
/// de produto da venda, que precisa do servidor porque o catálogo é grande.
class _SeletorModelo extends StatelessWidget {
  const _SeletorModelo({
    required this.modelos,
    required this.onEscolher,
    required this.registrarCampo,
    required this.limparCampo,
  });

  final List<ExpenseTemplate> modelos;
  final ValueChanged<ExpenseTemplate>? onEscolher;
  final void Function(TextEditingController, FocusNode) registrarCampo;
  final VoidCallback limparCampo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Autocomplete<ExpenseTemplate>(
      displayStringForOption: (t) => t.name,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return modelos;
        return modelos.where((t) => t.name.toLowerCase().contains(q));
      },
      onSelected: (t) {
        onEscolher?.call(t);
        // Limpa o campo: ele é um SELETOR de atalho, não um campo do lançamento
        // — deixar o nome ali daria a impressão de ser mais um dado do formulário.
        limparCampo();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        registrarCampo(controller, focusNode);
        return _Shell(
          label: 'Despesa fixa',
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: onEscolher != null,
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: 'Escolher uma despesa fixa',
              hintStyle: TextStyle(color: neu.inkFaint, fontSize: 14.5),
              prefixIcon: Icon(Icons.bolt_rounded, size: 18, color: neu.accent),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 26, minHeight: 0),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          color: neu.surface,
          child: ConstrainedBox(
            // Teto de altura: a lista rola por dentro em vez de estourar o
            // diálogo quando o tenant cadastra muitas despesas fixas.
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final t = options.elementAt(i);
                return ListTile(
                  dense: true,
                  onTap: () => onSelected(t),
                  // Raio = lança direto; lápis = ainda vai digitar o valor.
                  leading: Icon(
                    t.temValor ? Icons.bolt_rounded : Icons.edit_rounded,
                    size: 18,
                    color: t.temValor ? neu.accent : neu.inkMuted,
                  ),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Text(
                    t.temValor ? formatMoney(t.valor) : 'valor varia',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo em cima + cavidade do design system. Cópia local enxuta do
/// `_FieldShell` do diálogo de lançamento (privado de lá) — só o que o seletor
/// precisa, sem arrastar uma refatoração de widget compartilhado para cá.
class _Shell extends StatelessWidget {
  const _Shell({required this.label, required this.child, this.padding});

  final String label;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

/// Parse de valor digitado (aceita vírgula) → double >= 0, ou null se inválido.
double? _parseValor(String raw) {
  final v = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (v == null || v < 0) return null;
  return v;
}

class _BotaoGerenciar extends StatelessWidget {
  const _BotaoGerenciar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return NeuIconButton(
      icon: Icons.tune_rounded,
      tooltip: 'Gerenciar despesas fixas',
      onPressed: () async {
        await showExpenseTemplatesDialog(context);
        onDone();
      },
    );
  }
}

/// Gerenciamento dos modelos: cadastrar, editar, desativar e reativar.
Future<void> showExpenseTemplatesDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const _GerenciarDialog(),
    );

class _GerenciarDialog extends ConsumerWidget {
  const _GerenciarDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(expenseTemplatesAllProvider);
    final isMobile = context.isMobile;

    return NeuDialog(
      title: 'Despesas fixas',
      maxWidth: 520,
      actions: [
        NeuButton(
          label: 'Fechar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        NeuButton(
          label: 'Nova',
          icon: Icons.add_rounded,
          onPressed: () async {
            final ok = await showEditarModeloDialog(context, ref);
            if (ok) ref.invalidate(expenseTemplatesAllProvider);
          },
        ),
      ],
      child: SizedBox(
        // Altura limitada: a lista rola por dentro em vez de o diálogo crescer
        // até estourar a tela no mobile.
        height: isMobile ? 320 : 380,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              e is AppException ? e.message : 'Erro ao carregar.',
              style: TextStyle(color: neu.danger),
              textAlign: TextAlign.center,
            ),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const NeuEmptyState(
                icon: Icons.repeat_rounded,
                title: 'Nenhuma despesa fixa',
                message:
                    'Cadastre o que você paga todo mês — aluguel, internet, contador — '
                    'e o lançamento no caixa vira um toque.',
              );
            }
            return ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LinhaModelo(
                modelo: lista[i],
                onMudou: () => ref.invalidate(expenseTemplatesAllProvider),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LinhaModelo extends ConsumerWidget {
  const _LinhaModelo({required this.modelo, required this.onMudou});

  final ExpenseTemplate modelo;
  final VoidCallback onMudou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final ativo = modelo.ativo;
    final valor =
        modelo.temValor ? formatMoney(modelo.valor) : 'valor varia';
    final categoria = modelo.category == 'sangria' ? 'Sangria' : 'Despesa';

    return NeuListTile(
      // Desativado esmaece, mas continua visível para poder ser reativado.
      title: Opacity(
        opacity: ativo ? 1 : .5,
        child: Text(
          modelo.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      subtitle: Opacity(
        opacity: ativo ? 1 : .5,
        child: Text(
          [
            valor,
            categoria,
            if (modelo.method != null) methodLabel(modelo.method!),
            if (!ativo) 'desativada',
          ].join(' · '),
          style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Editar',
            onPressed: () async {
              final ok = await showEditarModeloDialog(context, ref, atual: modelo);
              if (ok) onMudou();
            },
          ),
          NeuIconButton(
            icon: ativo ? Icons.block_rounded : Icons.undo_rounded,
            tooltip: ativo ? 'Desativar' : 'Reativar',
            onPressed: () async {
              final repo = ref.read(cashierRepositoryProvider);
              try {
                if (ativo) {
                  await repo.disableExpenseTemplate(modelo.id);
                } else {
                  await repo.updateExpenseTemplate(
                    modelo.id,
                    const ExpenseTemplateDraft(status: 'active'),
                  );
                }
                onMudou();
              } on AppException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Formulário de um modelo (novo ou edição). Devolve `true` quando gravou.
Future<bool> showEditarModeloDialog(
  BuildContext context,
  WidgetRef ref, {
  ExpenseTemplate? atual,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _FormModeloDialog(atual: atual),
  );
  return ok ?? false;
}

class _FormModeloDialog extends ConsumerStatefulWidget {
  const _FormModeloDialog({this.atual});

  final ExpenseTemplate? atual;

  @override
  ConsumerState<_FormModeloDialog> createState() => _FormModeloDialogState();
}

class _FormModeloDialogState extends ConsumerState<_FormModeloDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.atual?.name ?? '');
  late final _amountCtrl = TextEditingController(
    text: (widget.atual?.temValor ?? false)
        ? formatAmountForInput(widget.atual!.valor)
        : '',
  );
  late String _category = widget.atual?.category ?? 'despesa';
  late String? _method = widget.atual?.method;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final texto = _amountCtrl.text.trim();
    // Vazio = "o valor varia" (grava 0). Não é erro de preenchimento.
    final valor = texto.isEmpty ? 0.0 : (_parseValor(texto) ?? 0);
    setState(() => _saving = true);
    final repo = ref.read(cashierRepositoryProvider);
    try {
      final draft = ExpenseTemplateDraft(
        name: _nameCtrl.text.trim(),
        amount: valor,
        category: _category,
        method: _method,
        // Editar para "usar o default" precisa APAGAR a forma antes gravada —
        // ausência no draft significaria "não mexe".
        limparMethod: _method == null,
      );
      if (widget.atual == null) {
        await repo.createExpenseTemplate(draft);
      } else {
        await repo.updateExpenseTemplate(widget.atual!.id, draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final config = ref.watch(cashierControllerProvider).value?.config;
    final formas = config?.paymentMethods ?? const <String>[];

    return NeuDialog(
      title: widget.atual == null ? 'Nova despesa fixa' : 'Editar despesa fixa',
      maxWidth: 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        NeuButton(
          label: 'Salvar',
          loading: _saving,
          onPressed: _saving ? null : _salvar,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeuTextField(
              label: 'Nome *',
              controller: _nameCtrl,
              hint: 'Aluguel, Internet, Contador…',
              autofocus: widget.atual == null,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Informe um nome.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Valor',
              controller: _amountCtrl,
              hint: '0,00',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              helper: 'Deixe vazio se o valor muda todo mês (ex.: conta de luz).',
            ),
            const SizedBox(height: 14),
            _DropdownSimples(
              label: 'Tipo',
              value: _category,
              options: const ['despesa', 'sangria'],
              rotulo: (v) => v == 'sangria' ? 'Sangria' : 'Despesa',
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        _category = v ?? _category;
                        // Sangria é gaveta: a forma é sempre dinheiro, então não
                        // faz sentido guardar outra sugestão no modelo.
                        if (_category == 'sangria') _method = null;
                      }),
            ),
            if (_category != 'sangria') ...[
              const SizedBox(height: 14),
              _DropdownSimples(
                label: 'Forma sugerida',
                value: _method ?? '',
                options: ['', ...formas],
                rotulo: (v) => v.isEmpty ? 'Perguntar na hora' : methodLabel(v),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _method = (v ?? '').isEmpty ? null : v),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'O modelo é só um atalho: nada é lançado no caixa até você confirmar.',
              style: TextStyle(color: neu.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownSimples extends StatelessWidget {
  const _DropdownSimples({
    required this.label,
    required this.value,
    required this.options,
    required this.rotulo,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String) rotulo;
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
            color: neu.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        NeuSurface(
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
                DropdownMenuItem(value: o, child: Text(rotulo(o))),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
