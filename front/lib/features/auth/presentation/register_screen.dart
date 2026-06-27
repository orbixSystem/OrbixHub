import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/util/cnpj.dart';
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
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
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
    super.dispose();
  }

  Future<void> _lookupCnpj() async {
    final digits = normalizeCnpj(_cnpj.text);
    if (digits == _lastLookedUp) return;
    if (!isValidCnpj(digits)) {
      // Só sinaliza erro se o usuário digitou algo "completo" porém inválido.
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
      // Autofill: razão social + nome de exibição (fantasia ou razão) + slug.
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
        _lastLookedUp = ''; // permite tentar de novo (ex.: fonte fora do ar)
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

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
    return AuthScaffold(
      title: 'Criar empresa',
      subtitle: 'Informe o CNPJ e a gente preenche o resto.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthErrorBanner(message: _error!),
            TextFormField(
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
              validator: (v) =>
                  isValidCnpj(v) ? null : 'Informe um CNPJ válido',
            ),
            if (_cnpjError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _cnpjError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_cnpjInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _cnpjInfo!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _legalName,
              decoration: const InputDecoration(
                labelText: 'Razão social',
                helperText: 'Preenchida automaticamente pelo CNPJ',
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Informe a razão social'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tenantName,
              decoration: const InputDecoration(
                labelText: 'Nome de exibição',
                hintText: 'ex.: nome fantasia',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Nome muito curto' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Identificador (slug)',
                hintText: 'ex.: minha-empresa',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
              ],
              validator: (v) => (v == null || !_slugPattern.hasMatch(v.trim()))
                  ? 'Use letras minúsculas, números e hífens'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Seu nome'),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Nome muito curto' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Senha (mín. 8)'),
              obscureText: true,
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Mínimo de 8 caracteres' : null,
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
}
