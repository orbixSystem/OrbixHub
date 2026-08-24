import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/devtools/dev_flag.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import 'auth_scaffold.dart';
import 'session_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _remember = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = ref.read(sessionControllerProvider.notifier);
      await controller.login(
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
      );
      if (!mounted) return;
      // B6 — sem rede, a senha foi validada contra o hash local: entra no modo
      // offline (sem picker de oficina; a oficina é a do último login online).
      if (ref.read(sessionControllerProvider).isOffline) {
        context.go('/');
        return;
      }
      // >1 workshop → show the picker first; otherwise straight to the app.
      final me = controller.currentMe;
      context.go(me != null && me.hasMultipleTenants ? '/picker' : '/');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dev-only: fills the fields with a seed account (does NOT submit).
  void _fillSeed(String email) {
    _email.text = email;
    _password.text = 'Dev@12345';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // B6 — aviso offline (âmbar): o cold-start não alcançou a API mas há
    // credencial offline neste dispositivo. Entrar valida a senha localmente.
    final offlineNotice = ref.watch(offlineNoticeProvider);
    return AuthScaffold(
      title: 'Bem-vindo de volta',
      subtitle: 'Acesse o painel da sua oficina.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offlineNotice != null) _OfflineNoticeBanner(message: offlineNotice),
            if (_error != null) AuthErrorBanner(message: _error!),
            NeuTextField(
              label: 'E-mail',
              controller: _email,
              hint: 'voce@oficina.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              maxLength: 160,
              validator: Validators.email(optional: false),
            ),
            const SizedBox(height: 14),
            // O olhinho vem do próprio NeuTextField. Esta tela montava o seu à
            // mão (feito em paralelo, na `qa`), e manter os dois deixaria de
            // novo duas implementações da mesma coisa divergindo no rótulo.
            NeuTextField(
              label: 'Senha',
              controller: _password,
              obscureText: !_showPassword,
              prefixIcon: Icons.lock_outline_rounded,
              validator: Validators.required('Senha'),
              onFieldSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
                tooltip: _showPassword ? 'Ocultar senha' : 'Ver senha',
              ),
            ),
            const SizedBox(height: 12),
            // "Manter conectado" (opt-in): persiste a sessão por ~1 mês.
            _RememberToggle(
              value: _remember,
              enabled: !_loading,
              onChanged: (v) => setState(() => _remember = v),
            ),
            const SizedBox(height: 16),
            NeuButton(
              label: 'Entrar',
              expanded: true,
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/forgot'),
              child: const Text('Esqueci minha senha'),
            ),
            if (kDevTools) _DevQuickLogin(onPick: _fillSeed),
          ],
        ),
      ),
    );
  }
}

/// Aviso âmbar do modo offline (B6) — informativo, não é erro.
class _OfflineNoticeBanner extends StatelessWidget {
  const _OfflineNoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309); // âmbar escuro (contraste em fundo claro)
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        border: Border.all(color: const Color(0xFFF5C77E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: amber,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle "Manter conectado" neumórfico: trilha cavada com o marcador que
/// desliza; rótulo sempre visível (alvo grande, usuário pouco digital).
class _RememberToggle extends StatelessWidget {
  const _RememberToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Semantics(
      toggled: value,
      label: 'Manter conectado',
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              NeuSurface(
                elevation: NeuElevation.inset,
                radius: 999,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 44,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: value ? neu.navy : neu.inkFaint,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Manter conectado',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dev-only quick-login: buttons that FILL the credentials of seed accounts
/// (does not submit). Tree-shaken out of release builds via [kDevTools].
class _DevQuickLogin extends StatelessWidget {
  const _DevQuickLogin({required this.onPick});

  final void Function(String email) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(
          'Login rápido (dev)',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        // Wrap → nunca estoura a largura no mobile; empilha se faltar espaço.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            NeuButton(
              label: 'Dono',
              kind: NeuButtonKind.secondary,
              icon: Icons.person_outline,
              onPressed: () => onPick('dono@oficina-demo.dev'),
            ),
            NeuButton(
              label: 'Mecânico',
              kind: NeuButtonKind.secondary,
              icon: Icons.build_outlined,
              onPressed: () => onPick('mecanico@oficina-demo.dev'),
            ),
          ],
        ),
      ],
    );
  }
}
