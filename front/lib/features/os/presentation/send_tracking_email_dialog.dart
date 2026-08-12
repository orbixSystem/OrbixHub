import 'package:flutter/material.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// Confirmação do destinatário antes de enviar o link de acompanhamento da OS.
///
/// Abre já com o e-mail do CADASTRO do cliente (buscado no backend) para o
/// atendente conferir — o cadastro envelhece, e um link mandado para o endereço
/// errado entrega a OS de um cliente a outra pessoa. Editar aqui vale só para
/// este envio: o cadastro do cliente não é alterado. Devolve o e-mail usado
/// quando o envio dá certo; `null` se o usuário cancelar.
class SendTrackingEmailDialog extends StatefulWidget {
  const SendTrackingEmailDialog({
    super.key,
    required this.repo,
    required this.order,
  });

  final OsRepository repo;
  final ServiceOrder order;

  static Future<String?> show(
    BuildContext context, {
    required OsRepository repo,
    required ServiceOrder order,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => SendTrackingEmailDialog(repo: repo, order: order),
    );
  }

  @override
  State<SendTrackingEmailDialog> createState() =>
      _SendTrackingEmailDialogState();
}

class _SendTrackingEmailDialogState extends State<SendTrackingEmailDialog> {
  final _email = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestion() async {
    try {
      final suggestion =
          await widget.repo.trackingRecipientEmail(widget.order.id);
      if (!mounted) return;
      // Cliente sem e-mail: campo em branco, o atendente digita na hora.
      _email.text = suggestion ?? '';
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Validação só de forma (o backend é a verdade) — evita a ida ao servidor
  /// com um endereço obviamente quebrado.
  bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value);

  Future<void> _send() async {
    final to = _email.text.trim();
    if (!_looksLikeEmail(to)) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repo.sendTrackingLinkEmail(widget.order.id, to);
      if (mounted) Navigator.of(context).pop(to);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final customer = widget.order.customerName?.trim();
    return NeuDialog(
      title: 'Enviar link por e-mail',
      maxWidth: context.isMobile ? 560 : 440,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Confirmar e enviar',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _loading || _sending ? null : _send,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer != null && customer.isNotEmpty
                ? 'Confira o e-mail de $customer antes de enviar o link de acompanhamento.'
                : 'Confira o e-mail do cliente antes de enviar o link de acompanhamento.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            TextField(
              controller: _email,
              autofocus: true,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sending ? null : _send(),
              decoration: const InputDecoration(
                labelText: 'E-mail do cliente',
                hintText: 'cliente@email.com',
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Corrigir aqui vale só para este envio — o cadastro do cliente não muda.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12, height: 1.35),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: neu.danger, fontSize: 13, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
