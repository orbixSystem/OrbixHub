import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../di.dart';

/// Porta de entrada do link de suporte da Orbix (`/suporte-orbix?code=...`).
///
/// A tela existe só para trocar o código por uma sessão e sair do caminho: quem
/// abre este link é alguém do suporte com um problema para olhar, não um
/// usuário navegando. Deu certo, cai no dashboard do cliente; deu errado, diz
/// o motivo e oferece o login normal — nunca um dashboard vazio sem explicação.
class SupportSessionScreen extends ConsumerStatefulWidget {
  const SupportSessionScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<SupportSessionScreen> createState() =>
      _SupportSessionScreenState();
}

class _SupportSessionScreenState extends ConsumerState<SupportSessionScreen> {
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Depois do primeiro frame: entrar mexe na sessão, que redesenha o router.
    WidgetsBinding.instance.addPostFrameCallback((_) => _entrar());
  }

  Future<void> _entrar() async {
    if (widget.code.isEmpty) {
      setState(() => _erro = 'O link não trouxe o código de acesso.');
      return;
    }
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .entrarPorSuporte(widget.code);
      if (mounted) context.go('/');
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível abrir a sessão de suporte.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: 28),
                if (_erro == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Abrindo o ambiente do cliente…',
                    style: t.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Icon(
                    Icons.link_off_outlined,
                    size: 34,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _erro!,
                    style: t.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Links de suporte valem uma vez só e por 5 minutos. '
                    'Gere outro no painel.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Ir para o login'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(180, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
