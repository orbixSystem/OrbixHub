import 'package:flutter/material.dart';
import '../../../core/vertical/vertical_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/pdf/document_company.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/cnpj.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/os_models.dart';
import 'detail/os_customer_tab.dart';
import 'detail/os_header.dart';
import 'detail/os_items_tab.dart';
import 'detail/os_photos_tab.dart';
import 'detail/os_service_tab.dart';
import 'detail/os_timeline_tab.dart';
import 'order_edit_dialog.dart';
import 'os_pdf.dart';
import 'os_providers.dart';
import 'os_status.dart';

const _maxContentWidth = 1200.0;

/// Ficha da OS.
///
/// A tela era uma rolagem única com sete seções empilhadas (relato, diagnóstico,
/// itens, totais, linha do tempo, mensagens, link público e fotos) — no celular
/// isso é uma página que não acaba, onde achar a foto significava passar por
/// tudo. Agora há **um cabeçalho fixo com a identidade e a ação do momento** e
/// **cinco abas** que separam o trabalho (Serviço) da evidência (Fotos), do
/// registro (Histórico) e da conversa (Cliente).
///
/// As abas são as mesmas no celular e no desktop de propósito: quem aprende a
/// tela num aparelho não reaprende no outro.
class OsDetailScreen extends ConsumerStatefulWidget {
  const OsDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OsDetailScreen> createState() => _OsDetailScreenState();
}

class _OsDetailScreenState extends ConsumerState<OsDetailScreen> {
  /// Push em tempo real: a OS muda pelas mãos de outra pessoa (outro mecânico
  /// mudando status, o cliente mandando mensagem) e esta tela precisa refletir
  /// sem depender de o usuário recarregar.
  final RealtimeChat _rt = RealtimeChat();

  /// Aba corrente. Serviço abre por padrão — é onde se trabalha.
  _OsTab _tab = _OsTab.servico;

  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken == null) return;
    _rt.connectStaff(
      accessToken: accessToken,
      // Mensagem nova numa conversa desta OS: a linha do tempo/contador muda.
      onMessage: (_) => _recarregar(),
      onOsChanged: (evt) {
        // A sala é do TENANT: chega mudança de QUALQUER OS. Só recarrega se for
        // esta — senão a tela recarregaria a cada movimento da oficina.
        if (evt['orderId'] == orderId) _recarregar();
      },
    );
  }

  /// Recarrega pela API. O socket avisa QUE mudou; o dado continua vindo de uma
  /// fonte só — o payload do evento é mínimo de propósito.
  void _recarregar() {
    if (!mounted) return;
    ref.invalidate(orderProvider(orderId));
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  bool _has(String perm) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission(perm) ?? false;
  }

  bool _hasModule(String key) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasModule(key) ?? false;
  }

  /// Empresa para o PDF — Configurações › Empresa, com logo, IE, endereço e
  /// contato. Falha de leitura cai para os dados do tenant ativo: o documento
  /// sai com menos dados no topo em vez de não sair.
  Future<DocumentCompany?> _companyParaPdf() async {
    try {
      return await ref.read(companyForDocumentsProvider.future);
    } on Object {
      final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
      if (t == null) return null;
      return DocumentCompany(
        name: t.name,
        legalName: t.legalName,
        cnpj:
            (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final canWrite = _has('os.write');
    final canApprove = _has('os.approve');
    final canRead = _has('os.read');
    // "Emitir NF" só aparece com o módulo fiscal habilitado E a permissão de
    // emissão — o backend é a verdade (aqui só refletimos para UX).
    // NF desligada no front (kInvoiceEnabled=false): sem emitir nota na OS,
    // mesmo com módulo/permissão. O backend segue capaz — é retirada de UI.
    final canIssueInvoice =
        kInvoiceEnabled && _hasModule('invoice') && _has('invoice.issue');

    return orderAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar a OS.'),
      ),
      data: (order) {
        // Estado terminal (cancelada/entregue) trava a edição de conteúdo —
        // espelha o backend; cancelada volta a editar reabrindo-a.
        final canEdit = canWrite && !osIsTerminal(order.status);
        final isDesktop = context.isDesktop;

        return _Bounded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              12,
              isDesktop ? 28 : 16,
              28,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/m/os'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Voltar'),
                ),
              ),
              const SizedBox(height: 8),
              OsDetailHeader(
                order: order,
                actions: OsActionBar(
                  order: order,
                  canWrite: canWrite,
                  canApprove: canApprove,
                  canEdit: canEdit,
                  canRead: canRead,
                  canIssueInvoice: canIssueInvoice,
                  onEdit: () => _edit(order),
                  onExport: () => _exportOrder(order),
                ),
              ),
              const SizedBox(height: 20),
              _TabBar(
                selecionada: _tab,
                itens: order.items.length,
                fotos: order.photos.length,
                onChanged: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 20),
              switch (_tab) {
                _OsTab.servico =>
                  OsServiceTab(order: order, canWrite: canEdit),
                _OsTab.itens => OsItemsTab(order: order, canWrite: canEdit),
                _OsTab.fotos => OsPhotosTab(order: order, canWrite: canEdit),
                _OsTab.historico =>
                  OsTimelineTab(order: order, canWrite: canEdit),
                _OsTab.cliente => OsCustomerTab(order: order),
              },
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(ServiceOrder order) async {
    final ok = await OrderEditDialog.show(context, order: order);
    if (ok == true) ref.invalidate(orderProvider(orderId));
  }

  /// Exporta a OS em PDF DIRETO para arquivo — sem passar pelo diálogo de
  /// impressão. Quem quer papel imprime o arquivo; quem quer mandar no WhatsApp
  /// (o caso comum) não deveria ter de cancelar uma janela de impressora antes.
  Future<void> _exportOrder(ServiceOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final company = await _companyParaPdf();
      final bytes = await buildOsPdf(order, PdfPageFormat.a4,
          company: company, objetoLabel: ref.read(vocabProvider)['objeto.singular'] ?? 'Objeto',);
      final nome =
          'OS-${order.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      showNeuSuccessOn(messenger, 'PDF exportado: $nome');
    } on Object {
      showNeuErrorOn(messenger, 'Não foi possível gerar o PDF.');
    }
  }
}

/// As quatro lentes da OS.
enum _OsTab { servico, itens, fotos, historico, cliente }

/// Navegação entre as abas. Rola na horizontal quando não cabe (celular
/// estreito) em vez de espremer os rótulos até virarem "…".
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selecionada,
    required this.itens,
    required this.fotos,
    required this.onChanged,
  });

  final _OsTab selecionada;
  final int itens;
  final int fotos;
  final ValueChanged<_OsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final abas = <(_OsTab, String, IconData, int?)>[
      (_OsTab.servico, 'Serviço', Icons.build_outlined, null),
      (_OsTab.itens, 'Itens', Icons.list_alt_rounded, itens),
      (_OsTab.fotos, 'Fotos', Icons.photo_library_outlined, fotos),
      (_OsTab.historico, 'Histórico', Icons.history_rounded, null),
      (_OsTab.cliente, 'Cliente', Icons.person_outline_rounded, null),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (aba, rotulo, icone, contador) in abas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabChip(
                label: rotulo,
                icon: icone,
                // Contador só quando há o que contar: "Fotos 0" é ruído.
                badge: (contador ?? 0) > 0 ? '$contador' : null,
                selected: selecionada == aba,
                onTap: () => onChanged(aba),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : neu.raised(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? neu.onNavy : neu.inkMuted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? neu.onNavy : neu.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? neu.onNavy.withValues(alpha: .22)
                      : neu.inkFaint.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected ? neu.onNavy : neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
