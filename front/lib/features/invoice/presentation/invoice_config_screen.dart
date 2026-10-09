import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/invoice_config_models.dart';

const _maxContentWidth = 720.0;

/// Tela de Configuração Fiscal (`/m/invoice/config`) — permissão `invoice.config`,
/// gated pelo módulo `invoice`. Prontidão para emitir, certificado A1
/// (.pfx/.p12), classificação do serviço na NFS-e e preferências
/// (ambiente/séries). Com emissão direta pelo governo (`provider == govbr`) não
/// há cadastro em provedor. Corpo apenas — a moldura é do shell.
class InvoiceConfigScreen extends ConsumerWidget {
  const InvoiceConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final configAsync = ref.watch(invoiceConfigControllerProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: neu.danger),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar a configuração fiscal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err is AppException ? err.message : 'Algo deu errado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: neu.inkMuted),
              ),
              const SizedBox(height: 16),
              NeuButton(
                label: 'Tentar novamente',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.read(invoiceConfigControllerProvider.notifier).load(),
              ),
            ],
          ),
        ),
      ),
      data: (config) => _InvoiceConfigBody(config: config),
    );
  }
}

class _InvoiceConfigBody extends ConsumerStatefulWidget {
  const _InvoiceConfigBody({required this.config});

  final InvoiceFiscalConfig config;

  @override
  ConsumerState<_InvoiceConfigBody> createState() =>
      _InvoiceConfigBodyState();
}

class _InvoiceConfigBodyState extends ConsumerState<_InvoiceConfigBody> {
  late final TextEditingController _serieNfse;
  late final TextEditingController _serieNfce;
  late final TextEditingController _serieNfe;
  late final TextEditingController _idCsc;
  late final TextEditingController _codigoServico;
  late final TextEditingController _codigoNbs;
  late final TextEditingController _aliquotaIss;
  late final TextEditingController _percentualSimples;
  late String _ambiente;

  bool _savingPreferences = false;
  bool _registeringEmpresa = false;
  bool _uploadingCertificate = false;

  @override
  void initState() {
    super.initState();
    _seedFrom(widget.config);
  }

  @override
  void didUpdateWidget(covariant _InvoiceConfigBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reseed por campo — só quando o valor daquele campo especificamente mudou
    // no servidor (novo fetch/tenant/save). Ações como "Cadastrar empresa" ou
    // "Enviar certificado" trazem um novo AsyncData que muda
    // empresaRegistrada/certificado mas NÃO as séries/CSC; reseedar tudo
    // incondicionalmente sobrescreveria edição de série/CSC que o usuário
    // ainda não salvou. Comparar por campo preserva o texto em digitação.
    final old = oldWidget.config;
    final next = widget.config;
    if (old == next) return;
    if (old.serieNfse != next.serieNfse) _serieNfse.text = next.serieNfse;
    if (old.serieNfce != next.serieNfce) _serieNfce.text = next.serieNfce;
    if (old.serieNfe != next.serieNfe) _serieNfe.text = next.serieNfe;
    if (old.idCsc != next.idCsc) _idCsc.text = next.idCsc;
    if (old.codigoServicoNacional != next.codigoServicoNacional) {
      _codigoServico.text = next.codigoServicoNacional;
    }
    if (old.codigoNbs != next.codigoNbs) _codigoNbs.text = next.codigoNbs;
    if (old.aliquotaIss != next.aliquotaIss) {
      _aliquotaIss.text = _formatPercent(next.aliquotaIss);
    }
    if (old.percentualTributosSimples != next.percentualTributosSimples) {
      _percentualSimples.text = _formatPercent(next.percentualTributosSimples);
    }
    if (old.ambiente != next.ambiente) {
      setState(() => _ambiente = next.ambiente);
    }
  }

  void _seedFrom(InvoiceFiscalConfig config) {
    _serieNfse = TextEditingController(text: config.serieNfse);
    _serieNfce = TextEditingController(text: config.serieNfce);
    _serieNfe = TextEditingController(text: config.serieNfe);
    _idCsc = TextEditingController(text: config.idCsc);
    _codigoServico = TextEditingController(text: config.codigoServicoNacional);
    _codigoNbs = TextEditingController(text: config.codigoNbs);
    _aliquotaIss =
        TextEditingController(text: _formatPercent(config.aliquotaIss));
    _percentualSimples = TextEditingController(
        text: _formatPercent(config.percentualTributosSimples));
    _ambiente = config.ambiente;
  }

  static String _formatPercent(double? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  /// '' → null (limpa); '2,5' → 2.5. Texto inválido também vira null.
  static double? _parsePercent(String text) {
    final t = text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  @override
  void dispose() {
    _serieNfse.dispose();
    _serieNfce.dispose();
    _serieNfe.dispose();
    _idCsc.dispose();
    _codigoServico.dispose();
    _codigoNbs.dispose();
    _aliquotaIss.dispose();
    _percentualSimples.dispose();
    super.dispose();
  }

  bool get _canManage {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated &&
        session.me.hasPermission('invoice.config');
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.neu.danger : null,
      ),
    );
  }

  Future<void> _registerEmpresa() async {
    setState(() => _registeringEmpresa = true);
    try {
      await ref.read(invoiceConfigControllerProvider.notifier).registerEmpresa();
      _snack('Empresa cadastrada no provedor fiscal com sucesso.');
    } on AppException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Erro ao cadastrar a empresa no provedor.', isError: true);
    } finally {
      if (mounted) setState(() => _registeringEmpresa = false);
    }
  }

  Future<void> _pickAndUploadCertificate() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pfx', 'p12'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final password = await _CertificatePasswordDialog.show(context);
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _uploadingCertificate = true);
    try {
      await ref
          .read(invoiceConfigControllerProvider.notifier)
          .pickAndUploadCertificate(bytes, file.name, password);
      _snack('Certificado enviado com sucesso.');
    } on AppException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Erro ao enviar o certificado.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingCertificate = false);
    }
  }

  Future<void> _savePreferences() async {
    final patch = <String, dynamic>{};
    if (_ambiente != widget.config.ambiente) patch['ambiente'] = _ambiente;
    if (_serieNfse.text != widget.config.serieNfse) {
      patch['serieNfse'] = _serieNfse.text;
    }
    if (_serieNfce.text != widget.config.serieNfce) {
      patch['serieNfce'] = _serieNfce.text;
    }
    if (_serieNfe.text != widget.config.serieNfe) {
      patch['serieNfe'] = _serieNfe.text;
    }
    if (_idCsc.text != widget.config.idCsc) patch['idCsc'] = _idCsc.text;
    if (_codigoServico.text != widget.config.codigoServicoNacional) {
      patch['codigoServicoNacional'] = _codigoServico.text;
    }
    if (_codigoNbs.text != widget.config.codigoNbs) {
      patch['codigoNbs'] = _codigoNbs.text;
    }
    final aliquota = _parsePercent(_aliquotaIss.text);
    if (aliquota != widget.config.aliquotaIss) patch['aliquotaIss'] = aliquota;
    final percentual = _parsePercent(_percentualSimples.text);
    if (percentual != widget.config.percentualTributosSimples) {
      patch['percentualTributosSimples'] = percentual;
    }

    if (patch.isEmpty) {
      _snack('Nenhuma alteração detectada.');
      return;
    }
    setState(() => _savingPreferences = true);
    try {
      await ref.read(invoiceConfigControllerProvider.notifier).save(patch);
      _snack('Configuração fiscal salva com sucesso.');
    } on AppException catch (e) {
      _snack(e.message, isError: true);
    } catch (_) {
      _snack('Erro ao salvar a configuração fiscal.', isError: true);
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isMobile = context.isMobile;
    final canManage = _canManage;
    final govBr = widget.config.isGovBr;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuração Fiscal',
                style: TextStyle(
                  color: neu.ink,
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                govBr
                    ? 'Emissão de NFS-e direto na Nota Fiscal Nacional (gov.br): '
                        'certificado digital, código do serviço e preferências.'
                    : 'Cadastro no provedor fiscal, certificado digital e '
                        'preferências de emissão de notas.',
                style: TextStyle(color: neu.inkMuted, fontSize: 14),
              ),
              if (!canManage) ...[
                const SizedBox(height: 16),
                _ReadOnlyNotice(),
              ],
              const SizedBox(height: 24),
              if (govBr)
                _ProntidaoSection(pendencias: widget.config.pendencias)
              else
                _EmpresaSection(
                  empresaRegistrada: widget.config.empresaRegistrada,
                  loading: _registeringEmpresa,
                  canManage: canManage,
                  onRegister: _registerEmpresa,
                ),
              const SizedBox(height: 20),
              _CertificadoSection(
                validoAte: widget.config.certificado.validoAte,
                loading: _uploadingCertificate,
                canManage: canManage,
                govBr: govBr,
                onUpload: _pickAndUploadCertificate,
              ),
              const SizedBox(height: 20),
              _ServicoNfseSection(
                codigoServico: _codigoServico,
                codigoNbs: _codigoNbs,
                aliquotaIss: _aliquotaIss,
                percentualSimples: _percentualSimples,
                canManage: canManage,
              ),
              const SizedBox(height: 20),
              _PreferenciasSection(
                ambiente: _ambiente,
                serieNfse: _serieNfse,
                serieNfce: _serieNfce,
                serieNfe: _serieNfe,
                idCsc: _idCsc,
                canManage: canManage,
                onlyNfse: govBr,
                onAmbienteChanged: (v) => setState(() => _ambiente = v),
              ),
              const SizedBox(height: 24),
              if (canManage)
                if (isMobile)
                  NeuButton(
                    label: 'Salvar',
                    icon: Icons.check_rounded,
                    onPressed: _savePreferences,
                    loading: _savingPreferences,
                    expanded: true,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NeuButton(
                        label: 'Salvar',
                        icon: Icons.check_rounded,
                        onPressed: _savePreferences,
                        loading: _savingPreferences,
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checklist do que falta para emitir (o backend manda em `pendencias`).
class _ProntidaoSection extends StatelessWidget {
  const _ProntidaoSection({required this.pendencias});

  final List<String> pendencias;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ready = pendencias.isEmpty;
    final color = ready ? neu.success : neu.warning;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.fact_check_outlined, index: 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pronto para emitir?',
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ready
                          ? 'Tudo certo: as notas de serviço já podem ser '
                              'emitidas.'
                          : 'Complete os itens abaixo para emitir a primeira '
                              'nota.',
                      style: TextStyle(color: neu.inkMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              NeuStatusChip(
                label: ready ? 'Pronto' : 'Pendente',
                color: color,
                tint: color.withValues(alpha: .14),
                icon: ready
                    ? Icons.check_circle_outline
                    : Icons.error_outline_rounded,
              ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 14),
            for (final p in pendencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.radio_button_unchecked,
                          size: 16, color: neu.inkMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _capitalize(p),
                        style: TextStyle(
                            color: neu.ink, fontSize: 14, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Classificação padrão do serviço na NFS-e (códigos nacionais + alíquotas).
class _ServicoNfseSection extends StatelessWidget {
  const _ServicoNfseSection({
    required this.codigoServico,
    required this.codigoNbs,
    required this.aliquotaIss,
    required this.percentualSimples,
    required this.canManage,
  });

  final TextEditingController codigoServico;
  final TextEditingController codigoNbs;
  final TextEditingController aliquotaIss;
  final TextEditingController percentualSimples;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.build_circle_outlined, index: 2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serviço na nota',
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Códigos que classificam o serviço prestado. Confirme '
                      'com o seu contador.',
                      style: TextStyle(color: neu.inkMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              const minField = 200.0;
              final maxW = constraints.maxWidth;
              final twoCols =
                  !context.isMobile && maxW >= (minField * 2 + gap);
              final w = twoCols ? ((maxW - gap) / 2).floorToDouble() : maxW;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: w,
                    child: NeuTextField(
                      label: 'Código de tributação nacional',
                      controller: codigoServico,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DigitsOnlyFormatter(6)],
                      helper: '6 dígitos: item e subitem da LC 116 + desdobro '
                          '(conserto de veículos começa com 1401).',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: NeuTextField(
                      label: 'Código NBS',
                      controller: codigoNbs,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DigitsOnlyFormatter(9)],
                      helper:
                          '9 dígitos (Nomenclatura Brasileira de Serviços).',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: NeuTextField(
                      label: 'Alíquota do ISS % (opcional)',
                      controller: aliquotaIss,
                      enabled: canManage,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      helper: 'Só se a prefeitura exigir. Ex.: 2,00.',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: NeuTextField(
                      label: 'Tributos aproximados % (opcional)',
                      controller: percentualSimples,
                      enabled: canManage,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      helper: 'Para optantes do Simples. Ex.: 6,00.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: neu.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Você não tem permissão para alterar a configuração fiscal — '
              'apenas visualização.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cadastro da empresa no provedor fiscal — status + ação.
class _EmpresaSection extends StatelessWidget {
  const _EmpresaSection({
    required this.empresaRegistrada,
    required this.loading,
    required this.canManage,
    required this.onRegister,
  });

  final bool empresaRegistrada;
  final bool loading;
  final bool canManage;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = empresaRegistrada ? neu.success : neu.inkMuted;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context, icon: Icons.storefront_outlined, index: 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Empresa no provedor fiscal',
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Necessário antes de emitir a primeira nota fiscal.',
                      style: TextStyle(color: neu.inkMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              NeuStatusChip(
                label: empresaRegistrada ? 'Registrada' : 'Não registrada',
                color: color,
                tint: color.withValues(alpha: .14),
                icon: empresaRegistrada
                    ? Icons.check_circle_outline
                    : Icons.hourglass_empty_rounded,
              ),
            ],
          ),
          if (canManage && !empresaRegistrada) ...[
            const SizedBox(height: 16),
            NeuButton(
              label: 'Cadastrar empresa no provedor',
              icon: Icons.cloud_upload_outlined,
              kind: NeuButtonKind.secondary,
              onPressed: loading ? null : onRegister,
              loading: loading,
            ),
          ],
        ],
      ),
    );
  }
}

/// Certificado digital A1 — validade + upload.
class _CertificadoSection extends StatelessWidget {
  const _CertificadoSection({
    required this.validoAte,
    required this.loading,
    required this.canManage,
    required this.govBr,
    required this.onUpload,
  });

  final String? validoAte;
  final bool loading;
  final bool canManage;
  final bool govBr;
  final VoidCallback onUpload;

  String? get _validoAteLabel {
    final iso = validoAte;
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final label = _validoAteLabel;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context, icon: Icons.verified_user_outlined, index: 3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificado digital (A1)',
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label != null
                          ? 'Válido até $label.'
                          : 'Nenhum certificado enviado ainda.',
                      style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            NeuButton(
              label: label != null ? 'Trocar certificado' : 'Enviar certificado',
              icon: Icons.upload_outlined,
              kind: NeuButtonKind.secondary,
              onPressed: loading ? null : onUpload,
              loading: loading,
            ),
            const SizedBox(height: 8),
            Text(
              govBr
                  ? 'Arquivo .pfx ou .p12 (e-CNPJ A1) da própria empresa. Ele '
                      'fica guardado criptografado no servidor e só é usado '
                      'para assinar e enviar as suas notas.'
                  : 'Arquivo .pfx ou .p12 — a senha é enviada direto ao '
                      'provedor fiscal e nunca é guardada aqui.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ambiente (homologação/produção) + séries + CSC.
class _PreferenciasSection extends StatelessWidget {
  const _PreferenciasSection({
    required this.ambiente,
    required this.serieNfse,
    required this.serieNfce,
    required this.serieNfe,
    required this.idCsc,
    required this.canManage,
    required this.onlyNfse,
    required this.onAmbienteChanged,
  });

  final String ambiente;
  final TextEditingController serieNfse;
  final TextEditingController serieNfce;
  final TextEditingController serieNfe;
  final TextEditingController idCsc;
  final bool canManage;

  /// Emissão direta pelo governo só emite NFS-e: séries de NFC-e/NF-e e CSC
  /// não se aplicam e ficam escondidos.
  final bool onlyNfse;
  final ValueChanged<String> onAmbienteChanged;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context, icon: Icons.tune_rounded, index: 1),
              const SizedBox(width: 12),
              Text(
                'Ambiente e séries',
                style: TextStyle(
                  color: neu.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AmbienteDropdown(
            value: ambiente,
            enabled: canManage,
            onChanged: onAmbienteChanged,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              const minField = 200.0;
              final maxW = constraints.maxWidth;
              final twoCols = !context.isMobile && maxW >= (minField * 2 + gap);
              final halfW = twoCols ? ((maxW - gap) / 2).floorToDouble() : maxW;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: twoCols ? halfW : maxW,
                    child: NeuTextField(
                      label:
                          onlyNfse ? 'Série da NFS-e' : 'Série NFS-e (opcional)',
                      controller: serieNfse,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DigitsOnlyFormatter(5)],
                      helper: onlyNfse
                          ? 'Use 1, a menos que o seu contador indique outra.'
                          : null,
                    ),
                  ),
                  if (!onlyNfse) ...[
                  SizedBox(
                    width: twoCols ? halfW : maxW,
                    child: NeuTextField(
                      label: 'Série NFC-e (opcional)',
                      controller: serieNfce,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DigitsOnlyFormatter(3)],
                    ),
                  ),
                  SizedBox(
                    width: twoCols ? halfW : maxW,
                    child: NeuTextField(
                      label: 'Série NF-e (opcional)',
                      controller: serieNfe,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DigitsOnlyFormatter(3)],
                    ),
                  ),
                  SizedBox(
                    width: twoCols ? halfW : maxW,
                    child: NeuTextField(
                      label: 'ID do CSC (opcional)',
                      controller: idCsc,
                      enabled: canManage,
                      keyboardType: TextInputType.text,
                      maxLength: 60,
                      helper: 'Identificador do CSC (o segredo fica no provedor).',
                    ),
                  ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AmbienteDropdown extends StatelessWidget {
  const _AmbienteDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('homologacao', 'Homologação (testes)'),
    ('producao', 'Produção'),
  ];

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Ambiente',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(NeuTokens.rField),
              dropdownColor: neu.surface,
              icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
              style: TextStyle(color: neu.ink, fontSize: 15),
              items: [
                for (final o in _options)
                  DropdownMenuItem(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: enabled
                  ? (v) {
                      if (v != null) onChanged(v);
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Use homologação para testar a emissão sem valor fiscal.',
            style: TextStyle(color: neu.inkFaint, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Diálogo que pede a senha do certificado antes do upload.
class _CertificatePasswordDialog extends StatefulWidget {
  const _CertificatePasswordDialog();

  static Future<String?> show(BuildContext context) {
    return showNeuDialog<String>(
      context,
      dialog: const NeuDialog(
        title: 'Senha do certificado',
        maxWidth: 380,
        child: _CertificatePasswordDialog(),
      ),
    );
  }

  @override
  State<_CertificatePasswordDialog> createState() =>
      _CertificatePasswordDialogState();
}

class _CertificatePasswordDialogState
    extends State<_CertificatePasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informe a senha do arquivo .pfx/.p12 para concluir o envio.',
          style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        // Olhinho por conta do NeuTextField (antes era montado aqui à mão).
        NeuTextField(
          label: 'Senha',
          controller: _controller,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NeuButton(
              label: 'Cancelar',
              kind: NeuButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            NeuButton(
              label: 'Enviar',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        ),
      ],
    );
  }
}
