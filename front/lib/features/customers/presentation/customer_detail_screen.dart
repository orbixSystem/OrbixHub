import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';
import 'brand_logo.dart';
import 'customer_form_dialog.dart';
import 'customers_providers.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import 'os_report_dialog.dart';
import 'subject_form_dialog.dart';

const _maxContentWidth = 940.0;

/// Ícone por chave de campo (genérico; cai num default quando desconhecido).
IconData _fieldIcon(String chave) {
  switch (chave) {
    case 'identifier':
      return Icons.confirmation_number_outlined;
    case 'marca':
      return Icons.sell_outlined;
    case 'modelo':
      return Icons.directions_car_outlined;
    case 'ano':
      return Icons.event_outlined;
    case 'cor':
      return Icons.palette_outlined;
    case 'km':
      return Icons.speed_outlined;
    default:
      return Icons.info_outline;
  }
}

/// Ficha do cliente: cabeçalho fixo + abas Veículos (cards colapsáveis) e
/// Histórico (timeline do cliente, filtrável por carro). Sem tela separada de
/// veículo. Corpo apenas — moldura é do shell.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  bool _has(WidgetRef ref, String perm) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission(perm) ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerProvider(customerId));
    final configAsync = ref.watch(customersConfigProvider);

    return customerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e is AppException ? e.message : 'Erro ao carregar cliente.',
        ),
      ),
      data: (customer) {
        final config = configAsync.value ?? const CustomersConfig();
        final usaSubjects = config.usaSubjects;
        return DefaultTabController(
          length: usaSubjects ? 2 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bounded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/m/customers'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Voltar'),
                    ),
                  ),
                ),
              ),
              _Bounded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
                  child: _CustomerHeader(
                    customer: customer,
                    canWrite: _has(ref, 'customer.write'),
                    onEdit: () async {
                      final ok = await CustomerFormDialog.show(
                        context,
                        existing: customer,
                        documentRequired: config.documentRequired,
                      );
                      if (ok != null) {
                        ref.invalidate(customerProvider(customerId));
                      }
                    },
                    onArchiveToggle: () async {
                      final repo = ref.read(customersRepositoryProvider);
                      if (customer.status == 'archived') {
                        await repo.unarchiveCustomer(customer.id);
                      } else {
                        await repo.archiveCustomer(customer.id);
                      }
                      ref.invalidate(customerProvider(customerId));
                    },
                    onDelete: () => _deleteCustomer(context, ref, customer),
                  ),
                ),
              ),
              _Bounded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        // Abas e conteúdo são os mesmos widgets em desktop e
                        // mobile (este cabeçalho é compartilhado), então um alvo
                        // só vale nos dois tamanhos.
                        child: CoachTarget(
                          'cliente.abas',
                          child: TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              if (usaSubjects)
                                Tab(
                                  icon: const Icon(
                                    Icons.directions_car_outlined,
                                    size: 18,
                                  ),
                                  text: config.subjectLabel.plural,
                                ),
                              const Tab(
                                icon: Icon(Icons.history, size: 18),
                                text: 'Histórico',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (usaSubjects && _has(ref, 'subject.write')) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () async {
                            final ok = await SubjectFormDialog.show(
                              context,
                              customerId: customerId,
                              config: config,
                            );
                            if (ok == true) {
                              ref.invalidate(
                                subjectsForCustomerProvider(customerId),
                              );
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Novo ${config.subjectLabel.singular}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CoachTarget(
                  'cliente.conteudo',
                  child: TabBarView(
                    children: [
                      if (usaSubjects)
                        _VehiclesTab(
                          customerId: customerId,
                          config: config,
                          canWrite: _has(ref, 'subject.write'),
                        ),
                      _CustomerHistoryTab(
                        customerId: customerId,
                        config: config,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Excluir cliente?',
      message:
          'Excluir "${customer.name}"? Ele sai das listagens. O registro é '
          'preservado (exclusão reversível pelo suporte).',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(customersRepositoryProvider).deleteCustomer(customer.id);
    ref.invalidate(customersListProvider);
    if (context.mounted) context.go('/m/customers');
  }
}

/// Centraliza e limita a largura do conteúdo.
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

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.customer,
    required this.canWrite,
    required this.onEdit,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final Customer customer;
  final bool canWrite;
  final VoidCallback onEdit;
  final Future<void> Function() onArchiveToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final archived = customer.status == 'archived';
    final rows = <(String, String?)>[
      ('Tipo', customer.type == 'PJ' ? 'Pessoa jurídica' : 'Pessoa física'),
      ('Documento', customer.document),
      ('Telefone', customer.phone),
      ('E-mail', customer.email),
      ('Endereço', customer.address),
      ('Observações', customer.notes),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  customer.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (archived)
                const _Pill(
                  icon: Icons.inventory_2_outlined,
                  text: 'Arquivado',
                ),
              if (canWrite) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: archived ? 'Desarquivar' : 'Arquivar',
                  icon: Icon(
                    archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: onArchiveToggle,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 28,
            runSpacing: 4,
            children: [
              for (final (label, value) in rows)
                if (value != null && value.isNotEmpty)
                  _InlineFact(label: label, value: value),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      // Limita a largura de cada fato para valores longos (e-mail/endereço)
      // truncarem com reticências em vez de estourar o Wrap na horizontal.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Veículos tab =====================

class _VehiclesTab extends ConsumerWidget {
  const _VehiclesTab({
    required this.customerId,
    required this.config,
    required this.canWrite,
  });

  final String customerId;
  final CustomersConfig config;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsForCustomerProvider(customerId));
    final singular = config.subjectLabel.singular;

    return subjectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e is AppException
              ? e.message
              : 'Erro ao carregar ${config.subjectLabel.plural}.',
        ),
      ),
      data: (page) => _Bounded(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            if (page.items.isEmpty)
              _EmptyBox(
                icon: Icons.directions_car_outlined,
                text: 'Nenhum ${singular.toLowerCase()} cadastrado ainda.',
              )
            else
              for (final s in page.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VehicleCard(
                    subject: s,
                    customerId: customerId,
                    config: config,
                    canWrite: canWrite,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Card de veículo colapsável (expande inline na tela do cliente).
class _VehicleCard extends ConsumerStatefulWidget {
  const _VehicleCard({
    required this.subject,
    required this.customerId,
    required this.config,
    required this.canWrite,
  });

  final Subject subject;
  final String customerId;
  final CustomersConfig config;
  final bool canWrite;

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  bool _expanded = false;
  bool _photoBusy = false;

  Subject get _s => widget.subject;
  String get _title => _s.label?.isNotEmpty == true
      ? _s.label!
      : (_s.identifier ?? widget.config.subjectLabel.singular);

  void _invalidate() =>
      ref.invalidate(subjectsForCustomerProvider(widget.customerId));

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpeg').toLowerCase();
    setState(() => _photoBusy = true);
    try {
      await ref
          .read(customersRepositoryProvider)
          .setSubjectPhoto(
            _s.id,
            bytes: bytes,
            filename: file.name,
            contentType: 'image/$ext',
          );
      _invalidate();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Remover foto?',
      message: 'A foto de "$_title" será removida.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await ref.read(customersRepositoryProvider).removeSubjectPhoto(_s.id);
      _invalidate();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// Abre a tela do veículo: dados do cadastro, informações adicionais da
  /// consulta por placa (persistidas) e as ordens de serviço, com impressão.
  void _open() =>
      context.go('/m/customers/${widget.customerId}/veiculo/${_s.id}');

  Future<void> _edit() async {
    final ok = await SubjectFormDialog.show(
      context,
      customerId: widget.customerId,
      config: widget.config,
      existing: _s,
    );
    if (ok == true) _invalidate();
  }

  Future<void> _toggleArchive() async {
    final repo = ref.read(customersRepositoryProvider);
    if (_s.status == 'archived') {
      await repo.unarchiveSubject(_s.id);
    } else {
      await repo.archiveSubject(_s.id);
    }
    _invalidate();
  }

  Future<void> _delete() async {
    final singular = widget.config.subjectLabel.singular;
    final confirmed = await showNeuConfirm(
      context,
      title: 'Excluir $singular?',
      message: 'Excluir "$_title"? O registro é preservado no sistema.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(customersRepositoryProvider).deleteSubject(_s.id);
    _invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final archived = _s.status == 'archived';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _SubjectThumb(
                    photoUrl: _s.photoUrl,
                    brand: _s.attributes['marca']?.toString(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_s.identifier?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            _s.identifier!,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (archived)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: _Pill(
                        icon: Icons.inventory_2_outlined,
                        text: 'Arquivado',
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _VehicleBody(
              subject: _s,
              config: widget.config,
              canWrite: widget.canWrite,
              archived: archived,
              photoBusy: _photoBusy,
              onPickPhoto: _pickPhoto,
              onRemovePhoto: _removePhoto,
              onEdit: _edit,
              onArchive: _toggleArchive,
              onDelete: _delete,
              onOpen: _open,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

/// Miniatura 48x48 do veículo: mostra a FOTO (com placeholder de erro) quando há;
/// senão cai no avatar da marca (_BrandAvatar).
class _SubjectThumb extends StatelessWidget {
  const _SubjectThumb({required this.photoUrl, required this.brand});

  final String? photoUrl;
  final String? brand;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return NeuNetworkImage(url: photoUrl, width: 48, height: 48, radius: 12);
    }
    return _BrandAvatar(name: brand);
  }
}

/// Avatar 48x48 com o logo da marca (best-effort); cai no ícone de carro quando
/// não há marca ou a imagem não carrega.
class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final url = brandLogoUrl(name);
    const fallback = Icon(
      Icons.directions_car_outlined,
      color: AppColors.brandDeep,
      size: 22,
    );
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: url == null
          ? fallback
          : Padding(
              padding: const EdgeInsets.all(7),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

/// Bloco de foto do veículo no corpo expandido: preview (com placeholder de erro)
/// + ações "Trocar"/"Remover"; ou, quando não há foto e o usuário pode escrever,
/// um estado vazio tocável para adicionar.
class _SubjectPhotoBlock extends StatelessWidget {
  const _SubjectPhotoBlock({
    required this.photoUrl,
    required this.busy,
    required this.canWrite,
    required this.onPick,
    required this.onRemove,
  });

  final String? photoUrl;
  final bool busy;
  final bool canWrite;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (!_hasPhoto) {
      // Sem foto (só chega aqui com canWrite): estado vazio tocável.
      return GestureDetector(
        onTap: busy ? null : onPick,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 30, color: neu.navy),
                  const SizedBox(height: 8),
                  Text(
                    'Adicionar foto',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: GestureDetector(
            onTap: (busy || !canWrite) ? null : onPick,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NeuNetworkImage(
                  url: photoUrl,
                  radius: NeuTokens.rField,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                if (busy)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NeuTokens.rField),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (canWrite) ...[
          const SizedBox(height: 10),
          // "Trocar" fica só no ícone: com a coluna da foto estreita, o rótulo
          // não cabia ao lado do "Remover" e quebrava dentro do botão. O
          // "Remover" mantém o texto e leva o espaço restante.
          Row(
            children: [
              NeuIconButton(
                icon: Icons.sync_rounded,
                tooltip: 'Trocar foto',
                size: 44,
                onPressed: busy ? null : onPick,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: neu.danger,
                  ),
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remover'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VehicleBody extends StatelessWidget {
  const _VehicleBody({
    required this.subject,
    required this.config,
    required this.canWrite,
    required this.archived,
    required this.photoBusy,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onOpen,
  });

  final Subject subject;
  final CustomersConfig config;
  final bool canWrite;
  final bool archived;
  final bool photoBusy;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  /// Abre a tela de detalhes do veículo (dados + consulta + OS).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldsWrap = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final f in config.subjectFields)
          _FieldTile(
            icon: _fieldIcon(f.chave),
            label: f.rotulo,
            value: f.chave == 'identifier'
                ? subject.identifier
                : subject.attributes[f.chave]?.toString(),
          ),
      ],
    );

    // Foto aparece quando existe OU quando o usuário pode adicioná-la.
    final showPhoto =
        (subject.photoUrl?.trim().isNotEmpty ?? false) || canWrite;
    final photoBlock = showPhoto
        ? _SubjectPhotoBlock(
            photoUrl: subject.photoUrl,
            busy: photoBusy,
            canWrite: canWrite,
            onPick: onPickPhoto,
            onRemove: onRemovePhoto,
          )
        : null;

    // Desktop: foto ao lado dos dados; mobile/tablet: foto em cima, empilhado.
    final Widget content;
    if (photoBlock == null) {
      content = fieldsWrap;
    } else if (context.isDesktop) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: photoBlock),
          const SizedBox(width: 20),
          Expanded(child: fieldsWrap),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [photoBlock, const SizedBox(height: 16), fieldsWrap],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          content,
          ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Abre a tela do veículo (dados, informações da consulta por
                // placa e ordens de serviço). Leitura — fora do guard canWrite.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Abrir'),
                ),
                if (canWrite) ...[
                  OutlinedButton.icon(
                    // Pin a finite min width (global theme uses infinite width).
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onArchive,
                    icon: Icon(
                      archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                    ),
                    label: Text(archived ? 'Desarquivar' : 'Arquivar'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: scheme.error,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Excluir'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = value != null && value!.trim().isNotEmpty;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  filled ? value! : '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: filled ? scheme.onSurface : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tipo do fato em PT-BR. Antes a timeline mostrava a chave crua ("os"), que não
/// diz nada ao usuário — e agora há mais de um tipo para distinguir.
String _rotuloDoTipo(String kind) => switch (kind) {
  'os' => 'Ordem de serviço',
  'sale' => 'Venda de balcão',
  _ => kind,
};

// ===================== Histórico tab (timeline do cliente) =====================

class _CustomerHistoryTab extends ConsumerStatefulWidget {
  const _CustomerHistoryTab({required this.customerId, required this.config});

  final String customerId;
  final CustomersConfig config;

  @override
  ConsumerState<_CustomerHistoryTab> createState() =>
      _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends ConsumerState<_CustomerHistoryTab> {
  String? _subjectId; // null = todos

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      customerHistoryProvider((
        customerId: widget.customerId,
        subjectId: _subjectId,
      )),
    );
    final subjects =
        ref
            .watch(subjectsForCustomerProvider(widget.customerId))
            .value
            ?.items ??
        const <Subject>[];

    return _Bounded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.config.usaSubjects && subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _subjectId == null,
                    onSelected: (_) => setState(() => _subjectId = null),
                  ),
                  for (final s in subjects)
                    ChoiceChip(
                      label: Text(
                        s.label?.isNotEmpty == true
                            ? s.label!
                            : (s.identifier ??
                                  widget.config.subjectLabel.singular),
                      ),
                      selected: _subjectId == s.id,
                      onSelected: (_) => setState(() => _subjectId = s.id),
                    ),
                ],
              ),
            ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e is AppException ? e.message : 'Erro ao carregar histórico.',
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) return const _HistoryEmpty();
                return ListView.builder(
                  padding: const EdgeInsets.all(28),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _TimelineItem(
                    entry: entries[i],
                    isFirst: i == 0,
                    isLast: i == entries.length - 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Item da timeline: trilho (ponto + linha) à esquerda + card do evento.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final SubjectHistoryEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // OS abre o relatório da OS; venda de balcão abre o detalhe da venda. As
    // duas são clicáveis: o histórico serve para chegar ao documento.
    final isOs = entry.kind == 'os';
    final isVenda = entry.kind == 'sale';
    final clicavel = isOs || isVenda;

    final cardInner = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (entry.subjectLabel?.isNotEmpty == true)
                      entry.subjectLabel!,
                    _rotuloDoTipo(entry.kind),
                    ?fmtDataHora(entry.occurredAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                if (clicavel) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVenda
                            ? Icons.shopping_bag_outlined
                            : Icons.description_outlined,
                        size: 15,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ver detalhes',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(icon: Icons.flag_outlined, text: entry.status),
          if (clicavel) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant),
    );

    final Widget card = clicavel
        ? Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => isVenda
                  ? showSaleDetailDialog(context, saleId: entry.id)
                  : showOsReportDialog(context, entry.id),
              child: Ink(decoration: decoration, child: cardInner),
            ),
          )
        : Container(decoration: decoration, child: cardInner);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 10,
                  color: isFirst ? Colors.transparent : scheme.outlineVariant,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : scheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off,
                color: AppColors.brandDeep,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sem histórico ainda',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'As ordens de serviço deste cliente vão aparecer aqui em uma '
              'linha do tempo assim que o módulo de OS estiver disponível.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgc = scheme.surfaceContainerHighest;
    final fgc = scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgc,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgc),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fgc,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
