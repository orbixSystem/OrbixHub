import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';

/// Dialog "Nova OS": busca/seleciona um cliente (autocomplete) → opcionalmente um
/// veículo do cliente → relato + previsões/responsável opcionais → cria.
/// Retorna o id da OS criada (String) via Navigator.pop. UI fala só com o repo.
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

  CustomerOption? _customer;
  List<SubjectOption> _subjects = const [];
  SubjectOption? _subject;
  bool _loadingSubjects = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _complaint.dispose();
    _assignedTo.dispose();
    super.dispose();
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

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

  Future<void> _save() async {
    if (_customer == null) {
      setState(() => _error = 'Selecione um cliente.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = OrderDraft(
      customerId: _customer!.id,
      subjectId: _subject?.id,
      complaint: _opt(_complaint.text),
      assignedTo: _opt(_assignedTo.text),
    );
    try {
      final order = await ref.read(osRepositoryProvider).createOrder(draft);
      if (mounted) Navigator.of(context).pop(order.id);
    } on AppException catch (e) {
      setState(() => _error = e.message);
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
                // ---- cliente (autocomplete) ----
                Autocomplete<CustomerOption>(
                  displayStringForOption: (c) => c.name,
                  optionsBuilder: (value) async {
                    final res = await ref
                        .read(osRepositoryProvider)
                        .searchCustomers(value.text);
                    return res;
                  },
                  onSelected: _pickCustomer,
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmit) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Cliente *',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Buscar por nome',
                      ),
                      validator: (_) =>
                          _customer == null ? 'Selecione um cliente' : null,
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
                  // ---- veículo opcional ----
                  if (_loadingSubjects)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_subjects.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _subject?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Veículo',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— nenhum —')),
                        for (final s in _subjects)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(_subjectTitle(s)),
                          ),
                      ],
                      onChanged: (id) => setState(() {
                        _subject = id == null
                            ? null
                            : _subjects.firstWhere((s) => s.id == id);
                      }),
                    ),
                ],
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
          onPressed: _saving ? null : _save,
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
}
