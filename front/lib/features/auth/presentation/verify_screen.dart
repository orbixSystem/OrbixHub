import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import 'auth_scaffold.dart';

/// Consumes the email-verification token from the deep link (`/verify?token=…`).
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  bool _loading = true;
  String? _error;
  bool _verified = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final token = GoRouterState.of(context).uri.queryParameters['token'];
    _verify(token);
  }

  Future<void> _verify(String? token) async {
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Link de verificação inválido.';
      });
      return;
    }
    try {
      await ref.read(authRepositoryProvider).verifyEmail(token);
      if (mounted) setState(() => _verified = true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verificação de e-mail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_verified) ...[
            const Icon(Icons.verified, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text('E-mail verificado com sucesso!',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ir para o login'),
            ),
          ] else ...[
            if (_error != null) AuthErrorBanner(message: _error!),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Voltar ao login'),
            ),
          ],
        ],
      ),
    );
  }
}
