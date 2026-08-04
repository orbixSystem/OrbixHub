import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import 'auth_scaffold.dart';

/// Redefines the password using the token from `/reset?token=…`.
///
/// O token é detalhe de implementação: quem chega pelo link do e-mail nunca o
/// vê. O campo só aparece quando a URL não trouxe token.
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});

  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _prefilled = false;
  bool _fromLink = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  /// Só aparece para quem abriu /reset sem token na URL — aí é a única saída
  /// além de pedir outro link. Em dev, navegue para `/reset?token=<besouro>`.
  bool get _showTokenField => !_fromLink;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final token = GoRouterState.of(context).uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      _token.text = token;
      _fromLink = true;
    }
  }

  @override
  void dispose() {
    _token.dispose();
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
      await ref.read(authRepositoryProvider).resetPassword(
            token: _token.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida. Faça login.')),
      );
      context.go('/login');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Redefinir senha',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthErrorBanner(message: _error!),
            if (_showTokenField) ...[
              TextFormField(
                controller: _token,
                decoration: const InputDecoration(labelText: 'Token'),
                validator: Validators.required('Token'),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Nova senha (mín. 8)',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.combine([
                Validators.required('Senha'),
                Validators.minLength(8, 'Senha'),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscureConfirm ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => v == _password.text
                  ? null
                  : 'As senhas não conferem.',
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
                  : const Text('Redefinir'),
            ),
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
