import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import 'auth_scaffold.dart';

/// Public "accept invite" screen reached via `/convite/:token`. An invited
/// member sets their name (optional) and password, which both accepts the
/// invite and signs them in.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{6,}$');

  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  bool get _tokenValid => _tokenPattern.hasMatch(widget.token);

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      await ref.read(sessionControllerProvider.notifier).acceptInvite(
            token: widget.token,
            fullName: name.isEmpty ? null : name,
            password: _password.text,
          );
      if (!mounted) return;
      context.go('/');
    } on AppException catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Convite inválido, expirado ou já utilizado.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_tokenValid) {
      return AuthScaffold(
        title: 'Aceitar convite',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthErrorBanner(message: 'Convite inválido.'),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Voltar ao login'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Aceitar convite',
      subtitle: 'Defina sua senha para entrar na oficina.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthErrorBanner(message: _error!),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Seu nome',
                counterText: '',
              ),
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              validator: Validators.required('Nome'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.combine([
                Validators.required('Senha'),
                Validators.minLength(8, 'Senha'),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
              obscureText: true,
              validator: (v) =>
                  (v != _password.text) ? 'As senhas não coincidem' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aceitar convite'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Voltar ao login'),
            ),
          ],
        ),
      ),
    );
  }
}
