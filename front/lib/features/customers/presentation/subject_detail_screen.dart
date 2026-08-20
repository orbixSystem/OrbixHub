import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/pdf/document_company.dart';
import '../../os/presentation/os_pdf.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/os_status.dart';
import '../domain/customers_models.dart';
import 'customers_providers.dart';
import 'os_report_dialog.dart';
import '../../../verticals/veiculos/plate_labels.dart';
import 'subject_form_dialog.dart';
import '../../../verticals/veiculos/vehicle_ficha_dialog.dart';

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
                                TextStyle(color: neu.inkMuted, fontSize: 14),
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
              // Mesmo cabeçalho em desktop e mobile — um alvo serve aos dois.
              child: CoachTarget(
                'veiculo.abas',
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
          ),
          const Divider(height: 1),
          Expanded(
            child: CoachTarget(
              'veiculo.conteudo',
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
    showNeuErrorSnackBar(context, msg);
  }

  /// Empresa do cabeçalho da ficha. Assíncrona porque o LOGO precisa ser
  /// baixado; falha cai para os dados do tenant (que o `/me` já trouxe), então a
  /// ficha nunca deixa de sair por causa da imagem.
  Future<DocumentCompany?> _company() async {
    try {
      return await ref.read(companyForDocumentsProvider.future);
    } on Object {
      final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
      if (t == null) return null;
      return DocumentCompany(
        name: t.name,
        legalName: t.legalName,
        cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
      );
    }
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
          _PlateHero(info: info, consultadoEm: _s.plateDataAt),
          // Ações da ficha.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NeuButton(
                label: 'Ficha / imprimir',
                icon: Icons.picture_as_pdf_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: () async {
                  final company = await _company();
                  if (!context.mounted) return;
                  await showVehicleFichaDialog(
                    context,
                    info: info,
                    company: company,
                    apelido: _s.label,
                    customerName: widget.customerName,
                    km: _s.attributes['km']?.toString(),
                    // Foto do cadastro entra impressa na ficha.
                    photoUrl: _s.photoUrl,
                  );
                },
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
          const SizedBox(height: 14),
          _InfoSection(
            icon: Icons.badge_outlined,
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
            icon: Icons.tune_rounded,
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
            icon: Icons.assignment_outlined,
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
              icon: Icons.precision_manufacturing_outlined,
              title: 'Dados técnicos e restrições',
              // Campos curtos: cabem 4 por linha num monitor.
              minTileWidth: 170,
              pairs: [for (final (l, v) in tecnicos) (l, v)],
            ),
          if (info.fipeTodos.isNotEmpty) _FipeSection(fipes: info.fipeTodos),
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

  /// Busca a OS completa (o histórico é um resumo) e EXPORTA em PDF.
  ///
  /// Direto para arquivo, como na tela da OS — o diálogo de impressão era um
  /// passo a mais para quem só quer mandar o documento para o cliente.
  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      final order = await ref.read(osRepositoryProvider).getOrder(
            widget.entry.id,
          );
      if (!mounted) return;
      // Empresa com logo/IE/endereço (Configurações › Empresa); se falhar, cai
      // para o tenant, que o `/me` já trouxe.
      DocumentCompany? company;
      try {
        company = await ref.read(companyForDocumentsProvider.future);
      } on Object {
        final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
        company = t == null
            ? null
            : DocumentCompany(
                name: t.name,
                legalName: t.legalName,
                cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty)
                    ? formatCnpj(t.cnpj)
                    : null,
              );
      }
      if (!mounted) return;
      final bytes = await buildOsPdf(
        order,
        PdfPageFormat.a4,
        company: company,
      );
      final nome =
          'OS-${order.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exportado: $nome')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        showNeuErrorSnackBar(context, e.message);
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
/// Card de uma seção de informações: cabeçalho com ícone + grid alinhado.
///
/// O grid usa COLUNAS DE LARGURA IGUAL calculadas pela largura disponível (2 a
/// 4 por linha) em vez de um Wrap de caixas soltas — assim os rótulos alinham
/// entre linhas e a página aproveita a horizontal em vez de virar uma coluna
/// alta de cartõezinhos.
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.pairs,
    this.icon = Icons.info_outline_rounded,
    this.minTileWidth = 210,
  });

  final String title;
  final List<(String, String?)> pairs;
  final IconData icon;

  /// Largura-alvo de cada célula; define quantas colunas cabem.
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final filled = [
      for (final (label, value) in pairs)
        if ((value ?? '').trim().isNotEmpty) (label, value!.trim()),
    ];
    if (filled.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rPanel,
        color: neu.surface,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: neu.accent),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoGrid(pairs: filled, minTileWidth: minTileWidth),
          ],
        ),
      ),
    );
  }
}

/// Grid de pares rótulo→valor com colunas de largura igual.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.pairs, this.minTileWidth = 210});

  final List<(String, String)> pairs;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minTileWidth).floor().clamp(1, 4);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value) in pairs)
              SizedBox(width: w, child: _InfoTile(label: label, value: value)),
          ],
        );
      },
    );
  }
}

/// Célula do grid: rótulo pequeno em cima, valor em destaque embaixo, numa
/// cavidade neumórfica. Valores são selecionáveis (copiar chassi/placa).
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final v = (value ?? '').trim();
    final filled = v.isNotEmpty;
    // "SEM RESTRICAO" é boa notícia — vale ler em verde no meio dos técnicos.
    final ok = filled && v.toUpperCase().startsWith('SEM RESTRI');
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      color: neu.base,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.inkFaint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            filled ? v : '—',
            maxLines: 2,
            style: TextStyle(
              color: !filled
                  ? neu.inkFaint
                  : ok
                      ? neu.success
                      : neu.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa de destaque no topo da aba: placa, veículo e valor FIPE — o que a
/// oficina olha primeiro, antes de descer para os detalhes.
class _PlateHero extends StatelessWidget {
  const _PlateHero({required this.info, this.consultadoEm});

  final PlateInfo info;
  final String? consultadoEm;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final titulo = [info.marca, info.modelo]
        .where((p) => (p ?? '').isNotEmpty)
        .cast<String>()
        .join(' ');
    final valorFipe = info.fipe?.valor;

    final placa = NeuSurface(
      elevation: NeuElevation.flat,
      radius: NeuTokens.rChip,
      color: neu.accent.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(
        info.placa,
        style: TextStyle(
          color: neu.accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );

    final identificacao = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo.isEmpty ? 'Veículo' : titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: neu.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if ((info.versao ?? '').isNotEmpty && info.versao != info.modelo)
          Text(
            info.versao!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
        if ((consultadoEm ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Consultado em ${_formatDate(consultadoEm!)}',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ),
      ],
    );

    final fipe = valorFipe == null || valorFipe.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'REFERÊNCIA FIPE',
                style: TextStyle(
                  color: neu.inkFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valorFipe,
                style: TextStyle(
                  color: neu.success,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rPanel,
        color: neu.surface,
        padding: const EdgeInsets.all(18),
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [placa]),
                  const SizedBox(height: 12),
                  identificacao,
                  if (fipe != null) ...[
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: fipe),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  placa,
                  const SizedBox(width: 16),
                  Expanded(child: identificacao),
                  if (fipe != null) ...[const SizedBox(width: 16), fipe],
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

/// Valores FIPE em formato de tabela: modelo à esquerda (com a referência
/// abaixo) e valor à direita. Em card, como as demais seções — antes ficava
/// solto no fundo da página, destoando do resto.
class _FipeSection extends StatelessWidget {
  const _FipeSection({required this.fipes});

  final List<PlateFipe> fipes;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rPanel,
        color: neu.surface,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.request_quote_outlined, size: 18, color: neu.accent),
                const SizedBox(width: 8),
                Text(
                  'VALORES DE REFERÊNCIA FIPE',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < fipes.length; i++) ...[
              if (i > 0) Divider(height: 18, color: neu.line),
              _FipeRow(fipe: fipes[i], best: i == 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _FipeRow extends StatelessWidget {
  const _FipeRow({required this.fipe, required this.best});

  final PlateFipe fipe;

  /// A primeira é a de maior score — a correspondência mais provável.
  final bool best;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ref = [
      if ((fipe.codigoFipe ?? '').isNotEmpty) 'Cód. ${fipe.codigoFipe}',
      if ((fipe.anoModelo ?? '').isNotEmpty) fipe.anoModelo!,
      if ((fipe.combustivel ?? '').isNotEmpty) fipe.combustivel!,
      if ((fipe.mesReferencia ?? '').isNotEmpty) 'ref. ${fipe.mesReferencia}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fipe.modelo ?? '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (best) ...[
                      const SizedBox(width: 8),
                      NeuSurface(
                        elevation: NeuElevation.flat,
                        radius: NeuTokens.rChip,
                        color: neu.successTint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          'melhor correspondência',
                          style: TextStyle(
                            color: neu.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ref.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ref,
                      style: TextStyle(color: neu.inkFaint, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if ((fipe.valor ?? '').isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              fipe.valor!,
              style: TextStyle(
                color: best ? neu.success : neu.ink,
                fontSize: best ? 17 : 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
