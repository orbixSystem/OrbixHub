import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';

/// Dois modos de origem do cliente na "Nova OS".
enum _CustomerMode { existing, novo }

/// Dialog "Nova OS": cria uma OS com **cliente existente** (autocomplete +
/// veículo opcional) OU com **cliente novo na hora** (nome + telefone e, se o
/// tenant usa veículos, placa/marca/modelo). Retorna o id da OS criada (String)
/// via Navigator.pop. UI fala só com o repo.
class OrderFormDialog extends ConsumerStatefulWidget {
  const OrderFormDialog({super.key});

  /// Abre o dialog. Resolve para o id da OS criada (String) ou null se cancelado.
  static Future<Object?> show(BuildContext context) {
    return showDialog<Object?>(
      context: context,
      builder: (_) => const OrderFormDialog(),
    );
  }

  @override
  ConsumerState<OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends ConsumerState<OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();
  final _assignedTo = TextEditingController();

  // Cliente novo
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();
  final _subjIdentifier = TextEditingController();
  final _subjMarca = TextEditingController();
  final _subjModelo = TextEditingController();

  _CustomerMode _mode = _CustomerMode.existing;

  // Cliente existente
  CustomerOption? _customer;
  List<SubjectOption> _subjects = const [];
  SubjectOption? _subject;
  bool _loadingSubjects = false;

  // Config (usaSubjects + rótulo). Default seguro: usa veículos.
  bool _usaSubjects = true;
  String _subjectLabelSingular = 'Veículo';

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in [
      _complaint,
      _assignedTo,
      _newName,
      _newPhone,
      _subjIdentifier,
      _subjMarca,
      _subjModelo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await ref.read(osRepositoryProvider).customersConfig();
      if (!mounted) return;
      setState(() {
        _usaSubjects = cfg.usaSubjects;
        _subjectLabelSingular = cfg.subjectLabel.singular;
      });
    } on AppException {
      // falha graciosa: mantém o default (usaSubjects=true, "Veículo").
    }
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  bool get _canSubmit => _mode == _CustomerMode.existing
      ? _customer != null
      : _newName.text.trim().isNotEmpty;

  Future<void> _pickCustomer(CustomerOption c) async {
    setState(() {
      _customer = c;
      _subject = null;
      _subjects = const [];
      _loadingSubjects = true;
    });
    try {
      final subs = await ref.read(osRepositoryProvider).subjectsOf(c.id);
      if (mounted) setState(() => _subjects = subs);
    } on AppException {
      // sem veículos / falha silenciosa — segue sem subject
    } finally {
      if (mounted) setState(() => _loadingSubjects = false);
    }
  }

  OrderDraft _buildDraft() {
    final complaint = _opt(_complaint.text);
    final assignedTo = _opt(_assignedTo.text);
    if (_mode == _CustomerMode.existing) {
      return OrderDraft(
        customerId: _customer!.id,
        subjectId: _subject?.id,
        complaint: complaint,
        assignedTo: assignedTo,
      );
    }
    // Cliente novo: monta atributos do veículo só se o tenant usa subjects.
    Map<String, dynamic>? attrs;
    String? identifier;
    if (_usaSubjects) {
      identifier = _opt(_subjIdentifier.text);
      attrs = {
        if (_opt(_subjMarca.text) != null) 'marca': _subjMarca.text.trim(),
        if (_opt(_subjModelo.text) != null) 'modelo': _subjModelo.text.trim(),
      };
      if (attrs.isEmpty) attrs = null;
    }
    return OrderDraft(
      newCustomerName: _newName.text.trim(),
      newCustomerPhone: _opt(_newPhone.text),
      newSubjectIdentifier: identifier,
      newSubjectAttributes: attrs,
      complaint: complaint,
      assignedTo: assignedTo,
    );
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(osRepositoryProvider).createOrder(_buildDraft());
      if (mounted) Navigator.of(context).pop(order.id);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _subjectTitle(SubjectOption s) =>
      s.label?.isNotEmpty == true ? s.label! : (s.identifier ?? 'Veículo');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova ordem de serviço'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- toggle de origem do cliente ----
                SegmentedButton<_CustomerMode>(
                  segments: const [
                    ButtonSegment(
                      value: _CustomerMode.existing,
                      icon: Icon(Icons.person_search_outlined),
                      label: Text('Cliente existente'),
                    ),
                    ButtonSegment(
                      value: _CustomerMode.novo,
                      icon: Icon(Icons.person_add_alt_1_outlined),
                      label: Text('Cliente novo'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _saving
                      ? null
                      : (sel) => setState(() {
                            _mode = sel.first;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 16),
                if (_mode == _CustomerMode.existing)
                  _existingSection()
                else
                  _novoSection(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _complaint,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Relato do cliente',
                    prefixIcon: Icon(Icons.chat_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'Responsável',
                    prefixIcon: Icon(Icons.engineering_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_saving || !_canSubmit) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar OS'),
        ),
      ],
    );
  }

  /// Cliente existente: autocomplete + veículo opcional. Sem clientes não quebra —
  /// o campo fica vazio e o usuário pode trocar para "Cliente novo".
  Widget _existingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Autocomplete<CustomerOption>(
          displayStringForOption: (c) => c.name,
          optionsBuilder: (value) async {
            try {
              return await ref
                  .read(osRepositoryProvider)
                  .searchCustomers(value.text);
            } on AppException {
              return const Iterable<CustomerOption>.empty();
            }
          },
          onSelected: _pickCustomer,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Cliente *',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Buscar por nome',
              ),
              onChanged: (_) {
                // Limpa a seleção se o usuário editar o texto após escolher.
                if (_customer != null) setState(() => _customer = null);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, maxWidth: 412),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final c in options)
                        ListTile(
                          dense: true,
                          title: Text(c.name),
                          subtitle: (c.document ?? c.phone) == null
                              ? null
                              : Text([
                                  if (c.document != null) c.document!,
                                  if (c.phone != null) c.phone!,
                                ].join(' · ')),
                          onTap: () => onSelected(c),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_customer != null) ...[
          const SizedBox(height: 12),
          if (_loadingSubjects)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_subjects.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _subject?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _subjectLabelSingular,
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— nenhum —')),
                for (final s in _subjects)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(_subjectTitle(s)),
                  ),
              ],
              onChanged: (id) => setState(() {
                _subject =
                    id == null ? null : _subjects.firstWhere((s) => s.id == id);
              }),
            ),
        ],
      ],
    );
  }

  /// Cliente novo na hora: nome* + telefone e, se o tenant usa veículos, uma
  /// seção com placa/identificação + marca + modelo.
  Widget _novoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _newName,
          decoration: const InputDecoration(
            labelText: 'Nome *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          // Reavalia o botão "Criar OS" enquanto digita.
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        if (_usaSubjects) ...[
          const SizedBox(height: 16),
          _subjectCard(),
        ],
      ],
    );
  }

  Widget _subjectCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined,
                  size: 18, color: AppColors.brandDeep),
              const SizedBox(width: 8),
              Text(
                _subjectLabelSingular,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subjIdentifier,
            decoration: const InputDecoration(
              labelText: 'Placa / Identificação',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _subjMarca,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _subjModelo,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
