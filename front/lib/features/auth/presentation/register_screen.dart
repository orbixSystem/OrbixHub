import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/util/cnpj.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import '../domain/auth_models.dart';
import 'auth_scaffold.dart';

final _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

String _slugify(String input) {
  final base = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-+)|(-+$)'), '');
  return base.length > 40 ? base.substring(0, 40) : base;
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _cnpj = TextEditingController();
  final _tenantName = TextEditingController();
  final _slug = TextEditingController();
  final _legalName = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;

  // Lookup de CNPJ
  bool _lookingUp = false;
  String? _cnpjInfo; // razão social / situação encontradas
  String? _cnpjError;
  String _lastLookedUp = ''; // evita repetir a mesma consulta

  @override
  void dispose() {
    _cnpj.dispose();
    _tenantName.dispose();
    _slug.dispose();
    _legalName.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _lookupCnpj() async {
    final digits = normalizeCnpj(_cnpj.text);
    if (digits == _lastLookedUp) return;
    if (!isValidCnpj(digits)) {
      if (digits.length == 14) {
        setState(() {
          _cnpjError = 'CNPJ inválido — confira os números.';
          _cnpjInfo = null;
        });
      }
      return;
    }
    _lastLookedUp = digits;
    setState(() {
      _lookingUp = true;
      _cnpjError = null;
      _cnpjInfo = null;
    });
    try {
      final CnpjCompany c =
          await ref.read(authRepositoryProvider).lookupCnpj(digits);
      if (!mounted) return;
      if (c.alreadyRegistered) {
        setState(() {
          _cnpjError = 'Este CNPJ já possui cadastro. Faça login.';
          _cnpjInfo = null;
        });
        return;
      }
      _legalName.text = c.razaoSocial;
      final display = (c.nomeFantasia?.trim().isNotEmpty ?? false)
          ? c.nomeFantasia!.trim()
          : c.razaoSocial;
      if (_tenantName.text.trim().isEmpty) _tenantName.text = display;
      if (_slug.text.trim().isEmpty) _slug.text = _slugify(display);
      setState(() {
        _cnpjInfo = [
          c.razaoSocial,
          if (c.municipio != null && c.uf != null) '${c.municipio}/${c.uf}',
          if (c.situacao != null) c.situacao,
        ].join(' · ');
      });
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _cnpjError = e.message;
          _cnpjInfo = null;
        });
        _lastLookedUp = '';
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  String? _vertical;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).register(
            tenantName: _tenantName.text.trim(),
            slug: _slug.text.trim(),
            cnpj: normalizeCnpj(_cnpj.text),
            legalName: _legalName.text.trim(),
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            vertical: _vertical,
          );
      if (mounted) context.go('/');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 920;

    return AuthScaffold(
      title: 'Criar empresa',
      subtitle: 'Informe o CNPJ e a gente preenche o resto.',
      maxFormWidth: wide ? 660 : 440,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthErrorBanner(message: _error!),

            // ── CNPJ + Razão social ──────────────────────────────────────
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _cnpjField(),
                        if (_cnpjError != null) _cnpjErrorWidget(theme),
                        if (_cnpjInfo != null) _cnpjInfoWidget(theme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: _legalNameField()),
                ],
              )
            else ...[
              _cnpjField(),
              if (_cnpjError != null) _cnpjErrorWidget(theme),
              if (_cnpjInfo != null) _cnpjInfoWidget(theme),
              const SizedBox(height: 12),
              _legalNameField(),
            ],

            const SizedBox(height: 12),

            // ── Nome de exibição + Slug ──────────────────────────────────
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _tenantNameField()),
                  const SizedBox(width: 12),
                  Expanded(child: _slugField()),
                ],
              )
            else ...[
              _tenantNameField(),
              const SizedBox(height: 12),
              _slugField(),
            ],

            const SizedBox(height: 12),

            // ── Seu nome + E-mail ────────────────────────────────────────
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _fullNameField()),
                  const SizedBox(width: 12),
                  Expanded(child: _emailField()),
                ],
              )
            else ...[
              _fullNameField(),
              const SizedBox(height: 12),
              _emailField(),
            ],

            const SizedBox(height: 12),

            // ── Senha + Confirmar senha ──────────────────────────────────
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _passwordField()),
                  const SizedBox(width: 12),
                  Expanded(child: _confirmPasswordField()),
                ],
              )
            else ...[
              _passwordField(),
              const SizedBox(height: 12),
              _confirmPasswordField(),
            ],

            VerticalPicker(
              selecionado: _vertical,
              onChanged: (v) => setState(() => _vertical = v),
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
                  : const Text('Criar e entrar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Já tenho conta'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Campos individuais ───────────────────────────────────────────────────

  Widget _cnpjField() => TextFormField(
        controller: _cnpj,
        keyboardType: TextInputType.number,
        inputFormatters: [CnpjInputFormatter()],
        decoration: InputDecoration(
          labelText: 'CNPJ',
          hintText: '00.000.000/0000-00',
          suffixIcon: _lookingUp
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Buscar dados da empresa',
                  icon: const Icon(Icons.search),
                  onPressed: _lookingUp ? null : _lookupCnpj,
                ),
        ),
        onChanged: (v) {
          if (normalizeCnpj(v).length == 14) _lookupCnpj();
        },
        onEditingComplete: _lookupCnpj,
        validator: (v) => isValidCnpj(v) ? null : 'Informe um CNPJ válido',
      );

  Widget _cnpjErrorWidget(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _cnpjError!,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error),
        ),
      );

  Widget _cnpjInfoWidget(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_cnpjInfo!, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      );

  Widget _legalNameField() => TextFormField(
        controller: _legalName,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Razão social',
          helperText: 'Preenchida automaticamente pelo CNPJ',
          counterText: '',
        ),
        validator: Validators.required('Razão social'),
      );

  Widget _tenantNameField() => TextFormField(
        controller: _tenantName,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Nome de exibição',
          hintText: 'ex.: nome fantasia',
          counterText: '',
        ),
        validator: Validators.required('Nome de exibição'),
      );

  Widget _slugField() => TextFormField(
        controller: _slug,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: 'Identificador (slug)',
          hintText: 'ex.: minha-empresa',
          counterText: '',
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
        ],
        validator: (v) => (v == null || !_slugPattern.hasMatch(v.trim()))
            ? 'Use letras minúsculas, números e hífens'
            : null,
      );

  Widget _fullNameField() => TextFormField(
        controller: _fullName,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Seu nome',
          counterText: '',
        ),
        validator: Validators.required('Nome'),
      );

  Widget _emailField() => TextFormField(
        controller: _email,
        decoration: const InputDecoration(
          labelText: 'E-mail',
          counterText: '',
        ),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        maxLength: 160,
        validator: Validators.email(optional: false),
      );

  Widget _passwordField() => TextFormField(
        controller: _password,
        decoration: InputDecoration(
          labelText: 'Senha (mín. 8)',
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
            tooltip: _showPassword ? 'Ocultar senha' : 'Ver senha',
          ),
        ),
        obscureText: !_showPassword,
        autofillHints: const [AutofillHints.newPassword],
        validator: Validators.combine([
          Validators.required('Senha'),
          Validators.minLength(8, 'Senha'),
        ]),
      );

  Widget _confirmPasswordField() => TextFormField(
        controller: _confirmPassword,
        decoration: InputDecoration(
          labelText: 'Confirmar senha',
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                setState(() => _showConfirmPassword = !_showConfirmPassword),
            tooltip: _showConfirmPassword ? 'Ocultar senha' : 'Ver senha',
          ),
        ),
        obscureText: !_showConfirmPassword,
        autofillHints: const [AutofillHints.newPassword],
        validator: (v) =>
            v != _password.text ? 'As senhas não coincidem' : null,
      );
}

/// Provider da lista de nichos (rota pública `/verticals`).
///
/// A lista NÃO é escrita no Flutter: vem do catálogo do servidor, como planos e
/// módulos. Um nicho novo aparece aqui sozinho, sem release do app.
final verticalOptionsProvider = FutureProvider<List<VerticalOption>>((ref) {
  return ref.read(authRepositoryProvider).listVerticals();
});

/// Seletor do ramo da empresa no cadastro.
///
/// Falha graciosa por design: se a rota não responder, o seletor some e o
/// cadastro segue sem escolha — o servidor aplica o pacote padrão. Bloquear a
/// criação de conta por causa de um rótulo seria desproporcional.
class VerticalPicker extends ConsumerWidget {
  const VerticalPicker({
    super.key,
    required this.selecionado,
    required this.onChanged,
  });

  final String? selecionado;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(verticalOptionsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (opcoes) {
        if (opcoes.length < 2) return const SizedBox.shrink();

        final atual = selecionado ??
            opcoes
                .firstWhere(
                  (o) => o.isDefault,
                  orElse: () => opcoes.first,
                )
                .key;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Segmento de atuação',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O sistema adapta os termos ao seu ramo.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            for (final o in opcoes) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: o.key == atual
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: ListTile(
                  key: Key('vertical-${o.key}'),
                  selected: o.key == atual,
                  onTap: () => onChanged(o.key),
                  title: Text(
                    o.nome,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _descricao(o.key),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    o.key == atual
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: o.key == atual
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  dense: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _descricao(String key) {
    switch (key) {
      case 'veiculos':
        return 'Para oficinas e autocenters — OS por veículo, consulta de placa e histórico por proprietário.';
      case 'equipamentos':
        return 'Para assistências técnicas — OS por equipamento, com número de série, marca e modelo.';
      default:
        return 'Vocabulário ajustado ao segmento da sua empresa.';
    }
  }
}
