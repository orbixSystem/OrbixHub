import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/util/validators.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';

/// Dialog de edição da OS: relato, previsões (calendário), responsável e
/// desconto. O diagnóstico é editado inline na tela de detalhe. PATCH envia só
/// os campos presentes. UI fala só com o repository.
class OrderEditDialog extends ConsumerStatefulWidget {
  const OrderEditDialog({super.key, required this.order});

  final ServiceOrder order;

  static Future<bool?> show(BuildContext context, {required ServiceOrder order}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => OrderEditDialog(order: order),
    );
  }

  @override
  ConsumerState<OrderEditDialog> createState() => _OrderEditDialogState();
}

class _OrderEditDialogState extends ConsumerState<OrderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _complaint;
  late final TextEditingController _discount;

  // Previsões: agora via calendário (DateTime ou null), não texto livre.
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;

  // Responsável: dropdown de membros (uuid ou null) — nunca string vazia/nome.
  String? _assignedTo;
  List<MemberOption> _members = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _complaint = TextEditingController(text: o.complaint ?? '');
    _assignedTo = (o.assignedTo?.isNotEmpty ?? false) ? o.assignedTo : null;
    _scheduledStart = _parse(o.scheduledStart);
    _scheduledEnd = _parse(o.scheduledEnd);
    _discount = TextEditingController(text: _fmt(o.discount));
    _loadMembers();
  }

  DateTime? _parse(String? iso) =>
      (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso)?.toLocal();

  /// dd/MM/yyyy HH:mm (pt-BR) para exibir data+hora escolhida.
  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ref.read(osRepositoryProvider).listMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        // Se o responsável atual não está na lista, não força um valor inválido
        // no dropdown (deixa null para não disparar assert do Dropdown).
        if (_assignedTo != null && !members.any((m) => m.id == _assignedTo)) {
          _assignedTo = null;
        }
      });
    } on AppException {
      // falha silenciosa — dropdown fica só com "sem responsável".
    }
  }

  String _fmt(String? decimal) {
    final v = double.tryParse(decimal ?? '');
    if (v == null || v == 0) return '';
    return v.toString().replaceAll('.', ',');
  }

  @override
  void dispose() {
    _complaint.dispose();
    _discount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _scheduledStart : _scheduledEnd) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: start ? 'Previsão de início' : 'Previsão de fim',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _scheduledStart = dt;
        if (_scheduledEnd != null && _scheduledEnd!.isBefore(dt)) {
          _scheduledEnd = null;
        }
      } else {
        _scheduledEnd = dt;
      }
    });
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  double? _toDouble(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return 0;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final patch = OrderPatch(
      complaint: _opt(_complaint.text),
      assignedTo: _assignedTo,
      scheduledStart: _scheduledStart?.toUtc().toIso8601String(),
      scheduledEnd: _scheduledEnd?.toUtc().toIso8601String(),
      discount: _toDouble(_discount.text),
    );
    try {
      await ref.read(osRepositoryProvider).updateOrder(widget.order.id, patch);
      ref.invalidate(orderProvider(widget.order.id));
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar ${widget.order.number}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _complaint,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Relato do cliente',
                  prefixIcon: Icon(Icons.chat_outlined),
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _assignedTo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Responsável',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Sem responsável —'),
                  ),
                  for (final m in _members)
                    DropdownMenuItem<String?>(
                      value: m.id,
                      child: Text(m.name),
                    ),
                ],
                onChanged:
                    _saving ? null : (id) => setState(() => _assignedTo = id),
              ),
              // Troca de responsável offline: fica no aparelho até sincronizar.
              const Align(
                alignment: Alignment.centerLeft,
                child: OfflinePendingNotice(
                  dense: true,
                  message: 'A troca de responsável só será enviada ao sistema '
                      'quando a conexão voltar',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Previsão início',
                      icon: Icons.event_outlined,
                      value: _scheduledStart == null
                          ? null
                          : _fmtDate(_scheduledStart!),
                      enabled: !_saving,
                      onTap: () => _pickDate(start: true),
                      onClear: _scheduledStart == null
                          ? null
                          : () => setState(() => _scheduledStart = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Previsão fim',
                      icon: Icons.event_available_outlined,
                      value: _scheduledEnd == null
                          ? null
                          : _fmtDate(_scheduledEnd!),
                      enabled: !_saving,
                      onTap: () => _pickDate(start: false),
                      onClear: _scheduledEnd == null
                          ? null
                          : () => setState(() => _scheduledEnd = null),
                    ),
                  ),
                ],
              ),
              // Datas de serviço offline: idem — só chegam ao sistema com rede.
              const Align(
                alignment: Alignment.centerLeft,
                child: OfflinePendingNotice(
                  dense: true,
                  message: 'As datas de serviço só serão enviadas ao sistema '
                      'quando a conexão voltar',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Desconto da OS',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.discount_outlined),
                ),
                validator:
                    Validators.positiveNumber(optional: true, field: 'Desconto'),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Campo somente-leitura que abre um calendário ao toque. Mostra a data
/// formatada (dd/MM/yyyy) ou um placeholder; permite limpar quando há valor.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final String? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: (value != null && onClear != null)
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Limpar',
                  onPressed: enabled ? onClear : null,
                )
              : const Icon(Icons.calendar_month_outlined, size: 18),
        ),
        child: Text(
          value ?? 'Selecionar data e hora',
          style: value == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
