import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../os/presentation/os_pdf.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/os_status.dart';
import '../domain/customers_models.dart';
import 'customers_providers.dart';
import 'os_report_dialog.dart';
import 'plate_labels.dart';
import 'subject_form_dialog.dart';
import 'vehicle_ficha_dialog.dart';
import 'vehicle_ficha_pdf.dart';

const _maxContentWidth = 940.0;

/// Tela de detalhes do veículo (subject), com três abas:
///  • **Dados** — foto + campos do cadastro (o que o usuário digitou);
///  • **Informações adicionais** — TUDO o que a consulta por placa devolveu,
///    persistido no próprio veículo (colunas exclusivas). Permite reconsultar
///    e imprimir a ficha;
///  • **Ordens de serviço** — histórico do veículo, com impressão da OS em PDF.
///
/// Corpo apenas — a moldura é do shell.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.customerId,
    required this.subjectId,
  });

  final String customerId;
  final String subjectId;

  bool _has(WidgetRef ref, String perm) =>
      ref.read(sessionControllerProvider).meOrNull?.hasPermission(perm) ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsForCustomerProvider(customerId));
    final configAsync = ref.watch(customersConfigProvider);
    final config = configAsync.value ?? const CustomersConfig();

    return subjectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e is AppException ? e.message : 'Erro ao carregar o veículo.',
        ),
      ),
      data: (page) {
        final subject =
            page.items.where((s) => s.id == subjectId).firstOrNull;
        if (subject == null) {
          return Center(
            child: NeuEmptyState(
              icon: Icons.directions_car_outlined,
              title: '${config.subjectLabel.singular} não encontrado',
              message: 'Ele pode ter sido excluído ou pertence a outro cliente.',
              actionLabel: 'Voltar ao cliente',
              onAction: () => context.go('/m/customers/$customerId'),
            ),
          );
        }
        return _Body(
          customerId: customerId,
          subject: subject,
          config: config,
          canWrite: _has(ref, 'subject.write'),
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.customerId,
    required this.subject,
    required this.config,
    required this.canWrite,
  });

  final String customerId;
  final Subject subject;
  final CustomersConfig config;
  final bool canWrite;

  String get _title => subject.label?.isNotEmpty == true
      ? subject.label!
      : (subject.identifier ?? config.subjectLabel.singular);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final customerName =
        ref.watch(customerProvider(customerId)).whenOrNull(data: (c) => c.name);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bounded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/m/customers/$customerId'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(customerName == null
                      ? 'Voltar'
                      : 'Voltar para $customerName'),
                ),
              ),
            ),
          ),
          _Bounded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
              child: Row(
                children: [
                  NeuIconChip.glyph(context,
                      icon: Icons.directions_car_rounded, index: 1, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((subject.identifier ?? '').isNotEmpty)
                          Text(
                            subject.identifier!,
                            style:
                                TextStyle(color: neu.inkMuted, fontSize: 13.5),
                          ),
                      ],
                    ),
                  ),
                  if (canWrite)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      onPressed: () async {
                        final ok = await SubjectFormDialog.show(
                          context,
                          customerId: customerId,
                          config: config,
                          existing: subject,
                        );
                        if (ok == true) {
                          ref.invalidate(
                            subjectsForCustomerProvider(customerId),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                ],
              ),
            ),
          ),
          const _Bounded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    icon: Icon(Icons.description_outlined, size: 18),
                    text: 'Dados',
                  ),
                  Tab(
                    icon: Icon(Icons.travel_explore_outlined, size: 18),
                    text: 'Informações adicionais',
                  ),
                  Tab(
                    icon: Icon(Icons.build_outlined, size: 18),
                    text: 'Ordens de serviço',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _DadosTab(subject: subject, config: config),
                _PlacaTab(
                  customerId: customerId,
                  subject: subject,
                  customerName: customerName,
                  canWrite: canWrite,
                ),
                _OrdensTab(customerId: customerId, subject: subject),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aba 1 — o que está no cadastro (foto + campos dinâmicos da config).
class _DadosTab extends StatelessWidget {
  const _DadosTab({required this.subject, required this.config});

  final Subject subject;
  final CustomersConfig config;

  @override
  Widget build(BuildContext context) {
    final photo = subject.photoUrl;
    return _Bounded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        children: [
          if ((photo ?? '').isNotEmpty) ...[
            SizedBox(
              height: 220,
              width: double.infinity,
              child: NeuNetworkImage(
                url: photo,
                radius: NeuTokens.rField,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final f in config.subjectFields)
                _InfoTile(
                  label: f.rotulo,
                  value: f.chave == 'identifier'
                      ? subject.identifier
                      : subject.attributes[f.chave]?.toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aba 2 — informações adicionais vindas da consulta por placa, persistidas no
/// veículo. Sem consulta salva, oferece fazer a primeira.
class _PlacaTab extends ConsumerStatefulWidget {
  const _PlacaTab({
    required this.customerId,
    required this.subject,
    required this.customerName,
    required this.canWrite,
  });

  final String customerId;
  final Subject subject;
  final String? customerName;
  final bool canWrite;

  @override
  ConsumerState<_PlacaTab> createState() => _PlacaTabState();
}

class _PlacaTabState extends ConsumerState<_PlacaTab> {
  bool _busy = false;

  Subject get _s => widget.subject;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  FichaCompany? _company() {
    final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
    if (t == null) return null;
    return FichaCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }

  /// Consulta a placa de novo e SALVA no veículo (renova o carimbo de data).
  /// Reaproveita o cache do servidor — normalmente não gasta cota.
  Future<void> _reconsultar() async {
    final plate = _s.identifier ?? '';
    setState(() => _busy = true);
    try {
      final repo = ref.read(customersRepositoryProvider);
      final info = await repo.plateLookup(plate);
      await repo.updateSubject(
        _s.id,
        SubjectDraft(
          plateData: info.copyWith(cached: false, usage: null).toJson(),
        ),
      );
      ref.invalidate(subjectsForCustomerProvider(widget.customerId));
      final usage = info.usage;
      _snack(info.cached
          ? 'Informações atualizadas do cache — não gastou consulta.'
          : 'Informações atualizadas — consulta ${usage?.used} de '
              '${usage?.limit} do mês.');
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final info = _s.plateInfo;
    final plate = _s.identifier ?? '';
    final podeConsultar = isValidPlate(plate) && widget.canWrite;

    if (info == null) {
      return _Bounded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NeuEmptyState(
                  icon: Icons.travel_explore_outlined,
                  title: 'Sem informações da consulta',
                  message: isValidPlate(plate)
                      ? 'Consulte a placa para trazer marca, modelo, dados '
                          'técnicos, restrições e valores FIPE deste veículo.'
                      : 'Cadastre uma placa válida no veículo para consultar '
                          'os dados oficiais.',
                ),
                if (podeConsultar) ...[
                  const SizedBox(height: 18),
                  RequiresConnection(
                    reason: 'a consulta de placa é feita no servidor',
                    child: NeuButton(
                      label: 'Consultar placa',
                      icon: Icons.manage_search_rounded,
                      loading: _busy,
                      onPressed: _busy ? null : _reconsultar,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final tecnicos = plateTechnicalRows(info.extra);

    return _Bounded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        children: [
          // Barra de ações + quando o dado foi obtido.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if ((_s.plateDataAt ?? '').isNotEmpty)
                Text(
                  'Consultado em ${_formatDate(_s.plateDataAt!)}',
                  style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
                ),
              NeuButton(
                label: 'Ficha / imprimir',
                icon: Icons.picture_as_pdf_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: () => showVehicleFichaDialog(
                  context,
                  info: info,
                  company: _company(),
                  apelido: _s.label,
                  customerName: widget.customerName,
                  km: _s.attributes['km']?.toString(),
                ),
              ),
              if (podeConsultar)
                RequiresConnection(
                  reason: 'a consulta de placa é feita no servidor',
                  child: NeuButton(
                    label: 'Atualizar consulta',
                    icon: Icons.refresh_rounded,
                    kind: NeuButtonKind.secondary,
                    loading: _busy,
                    onPressed: _busy ? null : _reconsultar,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoSection(
            title: 'Identificação',
            pairs: [
              ('Placa', info.placa),
              ('Placa anterior', info.placaAlternativa),
              ('Marca', info.marca),
              ('Modelo', info.modelo),
              ('Marca/modelo (registro)', info.marcaModelo),
              ('Versão', info.versao == info.modelo ? null : info.versao),
              ('Ano de fabricação', info.ano),
              ('Ano do modelo', info.anoModelo),
              ('Cor', info.cor),
              ('Chassi', info.chassi),
            ],
          ),
          _InfoSection(
            title: 'Características',
            pairs: [
              ('Combustível', info.combustivel),
              ('Cilindradas', info.cilindradas),
              ('Tipo de veículo', info.tipoVeiculo),
              ('Espécie', info.especie),
              ('Passageiros', info.passageiros),
              ('Segmento', info.segmento),
            ],
          ),
          _InfoSection(
            title: 'Registro',
            pairs: [
              ('Município', info.municipio),
              ('UF', info.uf),
              ('Situação', info.situacao),
              ('Origem', info.origem),
              ('Nacionalidade', info.nacionalidade),
              ('Equivalente FIPE', info.fipeMatch?.modelo?.value),
              ('Dados do registro em', info.consultadoEm),
            ],
          ),
          if (tecnicos.isNotEmpty)
            _InfoSection(
              title: 'Dados técnicos e restrições',
              pairs: [for (final (l, v) in tecnicos) (l, v)],
            ),
          if (info.fipeTodos.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Valores de referência FIPE',
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final f in info.fipeTodos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuSurface(
                  elevation: NeuElevation.flat,
                  radius: NeuTokens.rField,
                  color: neu.base,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.modelo ?? '—',
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if ((f.valor ?? '').isNotEmpty)
                        Text(
                          f.valor!,
                          style: TextStyle(
                            color: neu.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Aba 3 — ordens de serviço do veículo, com impressão em PDF.
class _OrdensTab extends ConsumerWidget {
  const _OrdensTab({required this.customerId, required this.subject});

  final String customerId;
  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      customerHistoryProvider(
        (customerId: customerId, subjectId: subject.id),
      ),
    );

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e is AppException ? e.message : 'Erro ao carregar o histórico.',
        ),
      ),
      data: (entries) {
        final ordens = entries.where((e) => e.kind == 'os').toList();
        if (ordens.isEmpty) {
          return const _Bounded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: NeuEmptyState(
                  icon: Icons.build_outlined,
                  title: 'Nenhuma ordem de serviço',
                  message: 'As OS abertas para este veículo aparecem aqui, '
                      'prontas para consultar e imprimir.',
                ),
              ),
            ),
          );
        }
        return _Bounded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            itemCount: ordens.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _OrdemTile(entry: ordens[i]),
          ),
        );
      },
    );
  }
}

/// Uma OS do veículo: abre o relatório e imprime o PDF (mesmo layout da OS).
class _OrdemTile extends ConsumerStatefulWidget {
  const _OrdemTile({required this.entry});

  final SubjectHistoryEntry entry;

  @override
  ConsumerState<_OrdemTile> createState() => _OrdemTileState();
}

class _OrdemTileState extends ConsumerState<_OrdemTile> {
  bool _printing = false;

  /// Busca a OS completa (o histórico é um resumo) e manda para a impressão.
  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      final order = await ref.read(osRepositoryProvider).getOrder(
            widget.entry.id,
          );
      if (!mounted) return;
      final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
      final company = t == null
          ? null
          : OsCompany(
              name: t.name,
              legalName: t.legalName,
              cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty)
                  ? formatCnpj(t.cnpj)
                  : null,
            );
      await Printing.layoutPdf(
        onLayout: (format) => buildOsPdf(order, format, company: company),
      );
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final e = widget.entry;
    return NeuSurface(
      elevation: NeuElevation.flat,
      radius: NeuTokens.rField,
      color: neu.base,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${osStatusLabel(e.status)} · ${_formatDate(e.occurredAt)}',
                  style: TextStyle(color: neu.inkFaint, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.visibility_outlined,
            tooltip: 'Ver relatório',
            size: 40,
            onPressed: () => showOsReportDialog(context, e.id),
          ),
          const SizedBox(width: 6),
          // Impressão é local (o PDF é montado no app); só depende de ter a OS.
          _printing
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              : RequiresConnection(
                  reason: 'a OS é carregada do servidor para imprimir',
                  child: NeuIconButton(
                    icon: Icons.picture_as_pdf_outlined,
                    tooltip: 'Imprimir OS em PDF',
                    size: 40,
                    onPressed: _print,
                  ),
                ),
        ],
      ),
    );
  }
}

/// Bloco rótulo→valor; some quando não há nada preenchido.
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.pairs});

  final String title;
  final List<(String, String?)> pairs;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final filled = [
      for (final (label, value) in pairs)
        if ((value ?? '').trim().isNotEmpty) (label, value!.trim()),
    ];
    if (filled.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            color: neu.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value) in filled)
              _InfoTile(label: label, value: value),
          ],
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final filled = (value ?? '').trim().isNotEmpty;
    return SizedBox(
      width: context.isMobile ? double.infinity : 220,
      child: NeuSurface(
        elevation: NeuElevation.flat,
        radius: NeuTokens.rField,
        color: neu.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: neu.inkFaint, fontSize: 11)),
            const SizedBox(height: 3),
            SelectableText(
              filled ? value!.trim() : '—',
              style: TextStyle(
                color: filled ? neu.ink : neu.inkFaint,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data ISO (ou "dd/MM/yyyy HH:mm:ss" da consulta) → "dd/MM/yyyy".
String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final d = parsed.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Bounded extends StatelessWidget {
  const _Bounded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );
}
