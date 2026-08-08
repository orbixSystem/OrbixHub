import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/offline_routes.dart';
import '../../../core/offline/widgets/connection_banner.dart';
import '../../../core/offline/widgets/connection_chip.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../../customers/presentation/customer_form_dialog.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../expenses/presentation/expense_form_dialog.dart';
import '../../expenses/presentation/expenses_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/simple_item_form_dialog.dart';
import '../../os/presentation/order_form_dialog.dart';
import '../../sale/presentation/sale_create_dialog.dart';
import '../../update/domain/update_models.dart';
import '../../update/presentation/update_banner.dart';
import '../../update/presentation/update_controller.dart';
import 'nav_items.dart';
import 'screen_tutorials.dart';
import 'sidebar.dart';

/// App chrome adaptativo (spec 2026-07-04):
/// desktop ≥1100 → sidebar navy fixa · tablet 600–1100 → drawer ·
/// mobile <600 → bottom navigation (3 destinos + "Mais").
/// Routed screens render only their body — the shell owns the chrome.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Rota cujo tutorial já foi disparado nesta sessão — sem isto, cada rebuild
  /// do shell (e há muitos) tentaria abrir o tutorial de novo.
  String? _tutorialDisparado;

  /// Abre o tutorial da rota, se houver e se o usuário nunca o viu.
  void _talvezTutorial(String location) {
    final tut = tutorialForRoute(location);
    if (tut == null || _tutorialDisparado == tut.id) return;
    _tutorialDisparado = tut.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMark.maybeStart(context, id: tut.id, steps: tut.steps);
    });
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Evita reentrância enquanto o modal de "sem conexão" está aberto / o
  /// redirect em voo (o build re-roda algumas vezes na transição).
  bool _offlineRedirecting = false;

  /// Tira o usuário de uma rota online-only enquanto offline: redireciona para
  /// uma tela que funciona offline e explica em modal (desktop e mobile).
  void _guardOfflineRoute(Me me) {
    if (!mounted || _offlineRedirecting) return;
    _offlineRedirecting = true;
    context.go(offlineSafeRoute(me));
    showNeuDialog<void>(
      context,
      dialog: NeuDialog(
        title: 'Sem conexão',
        maxWidth: 420,
        actions: [
          Builder(
            builder: (ctx) => NeuButton(
              label: 'Entendi',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
        child: Text(
          'Esta área precisa de internet e não funciona offline. '
          'Levamos você para uma tela que funciona sem conexão — suas '
          'alterações sobem sozinhas quando a conexão voltar.',
          style: TextStyle(color: context.neu.inkMuted, height: 1.4),
        ),
      ),
    ).whenComplete(() => _offlineRedirecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final me = session.meOrNull;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Versão velha demais para o servidor atual: seguir usando daria erro a
    // cada ação, então a casca inteira dá lugar ao aviso de atualização.
    final upd = ref.watch(updateStatusProvider).asData?.value;
    if (upd != null && upd.status == UpdateStatus.obrigatoria) {
      return UpdateRequiredView(update: upd.update);
    }

    final items = gatedNavItems(me);
    final location = GoRouterState.of(context).matchedLocation;

    // Guard offline: numa rota 100% online-only sem conexão, avisa em modal e
    // leva o usuário para uma tela que funciona offline. Telas parciais
    // (Config, detalhe da OS) bloqueiam por seção — não entram aqui.
    if (ref.watch(isOfflineProvider) && isOnlineOnlyRoute(location)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _guardOfflineRoute(me),
      );
    }
    // Tutorial da tela: um ponto de disparo para TODAS, porque o shell é quem
    // conhece a rota. Só na primeira visita (o `maybeStart` guarda "já visto") e
    // depois do 1º frame, para não competir com a montagem da tela.
    _talvezTutorial(location);

    final selected = selectedNavIndex(items, location);
    final size = context.screenSize;

    void navigate(String route) {
      context.go(route);
      _scaffoldKey.currentState?.closeDrawer();
    }

    final isMobile = size == ScreenSize.mobile;
    final isDesktop = size == ScreenSize.desktop;
    // Colapso só no desktop; no drawer (tablet) sempre expandido.
    final collapsed = isDesktop && ref.watch(sidebarCollapsedProvider);

    final sidebar = SidebarContent(
      me: me,
      items: items,
      selectedIndex: selected,
      onNavigate: navigate,
      collapsed: collapsed,
      onToggleCollapse: isDesktop
          ? () => ref.read(sidebarCollapsedProvider.notifier).toggle()
          : null,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.neu.base,
      drawer: (!isDesktop && !isMobile)
          ? Drawer(width: 272, child: sidebar)
          : null,
      bottomNavigationBar: isMobile
          ? _NeuBottomBar(
              items: items,
              selectedIndex: selected,
              onNavigate: navigate,
            )
          : null,
      body: Row(
        children: [
          if (isDesktop) sidebar,
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          _ContentHeader(
                            title: items[selected].label,
                            showMenu: !isDesktop && !isMobile,
                          ),
                          // Banner de transição de conectividade (offline/syncing/
                          // flash de reconexão): no topo da ÁREA DE CONTEÚDO — ou
                          // seja, ABAIXO do header, que já reserva a status bar.
                          // Antes ficava acima do header e corria sob os ícones de
                          // bateria/rede. O header/FAB seguem no topo do Stack, então
                          // a matemática do notch não muda.
                          const ConnectionBanner(),
                          // Versão nova disponível (adiável). A obrigatória não
                          // chega aqui — ela substitui a casca inteira.
                          const UpdateBanner(),
                          // A transição entre telas é feita pelo Navigator do
                          // ShellRoute (pageBuilder + neuPage), não aqui — envolver
                          // o child num AnimatedSwitcher duplicava a GlobalKey da
                          // página do go_router.
                          Expanded(child: widget.child),
                        ],
                      ),
                      // FAB de criação rápida aninhado no berço do header (centro).
                      // Sobe para dentro do entalhe fundo → protrai só ~8px na tela.
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 68 - 46,
                        left: 0,
                        right: 0,
                        // Alvo de tutorial presente em TODAS as telas: o "+" é o
                        // atalho de criação universal, e todo tutorial pode
                        // apontá-lo sem depender da tela.
                        child: const Center(
                          child: CoachTarget(
                            'shell.criar',
                            child: _QuickCreateFab(),
                          ),
                        ),
                      ),
                    ],
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

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title, required this.showMenu});

  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // Faixa do topo com borda inferior em ENTALHE (berço do FAB) e cor levemente
    // diferente do canvas (neu.surface sobre neu.base) — o visual "soft" da
    // referência. SafeArea(top) impede o conteúdo de colidir com a barra de
    // status no mobile. Uma linha sobre a curva evita que a faixa se funda com
    // os cards abaixo (nos dois temas).
    return Stack(
      children: [
        PhysicalShape(
          clipper: _HeaderWaveClipper(),
          color: neu.surface,
          elevation: 3,
          shadowColor: neu.shadowDark,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 68,
              child: Padding(
                padding: EdgeInsets.only(
                  // No mobile o canto esquerdo é do "?" do tutorial (overlay,
                  // espelhando o sino do outro lado do "+"): reservamos a faixa
                  // dele para o chip de conexão não ficar por baixo. 54 = 8 de
                  // margem + 38 do botão + respiro.
                  left: showMenu
                      ? 8
                      : context.isMobile
                          ? 54
                          : 28,
                  right: 20,
                  bottom: 16,
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    // O berço do FAB é centralizado; o título nunca pode alcançá-lo.
                    // No mobile o espaço à esquerda é pequeno demais e o bottom nav
                    // já indica a seção — então o título fica só em tablet/desktop,
                    // limitado (ellipsis) para parar antes do berço.
                    final showTitle = !context.isMobile;
                    final titleMax = (c.maxWidth / 2 - _headerNotchR - 28)
                        .clamp(0.0, 520.0);
                    return Row(
                      children: [
                        if (showMenu)
                          Builder(
                            builder: (context) => IconButton(
                              icon: Icon(Icons.menu_rounded, color: neu.ink),
                              tooltip: 'Menu',
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        if (showTitle)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: titleMax),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(color: neu.ink),
                            ),
                          ),
                        // Mobile não tem sidebar visível (bottom nav) — o status de
                        // conexão (persistente, mesmo indicador da sidebar) entra
                        // compacto aqui em vez de sumir de vista. Flexible é
                        // obrigatório: como filho direto do Row o chip receberia
                        // largura ILIMITADA e o Flexible interno dele nunca
                        // ativaria — rótulo longo (muitas pendências) estouraria
                        // o header num telefone estreito.
                        if (context.isMobile)
                          const Flexible(child: ConnectionChip(dense: true)),
                        const Spacer(),
                        // Sino, "?" do tutorial e toggle de tema vivem no overlay
                        // global (GlobalControls), lado a lado no topo-direita.
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _HeaderBorderPainter(
                color: neu.ink.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const double _headerNotchR =
    64.0; // meia-largura do entalhe (~128px, cabe o FAB)
const double _headerNotchDepth =
    56.0; // profundidade do recorte (folga acima do FAB)

/// Traça a borda INFERIOR do header (reta com o entalhe circular no centro),
/// assumindo que o ponto atual já está em `(0, h)`. Compartilhada pelo clipper
/// (recorte) e pelo painter (linha da borda) para não divergirem.
void _traceHeaderBottom(Path path, double w, double h) {
  final cx = w / 2;
  const r = _headerNotchR;
  const depth = _headerNotchDepth;
  path
    ..lineTo(cx - r - 14, h)
    ..cubicTo(cx - r + 8, h, cx - r + 16, h - depth, cx, h - depth)
    ..cubicTo(cx + r - 16, h - depth, cx + r - 8, h, cx + r + 14, h)
    ..lineTo(w, h);
}

/// Recorta a faixa do topo com um ENTALHE circular pequeno e centralizado (um
/// "berço", como o notch do FAB na referência): borda inferior reta, com um
/// recorte suave no centro. Simétrico e responsivo (só depende da largura).
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, h);
    _traceHeaderBottom(path, w, h);
    path
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Desenha a linha da borda inferior do header (na própria curva do entalhe),
/// para a faixa não se fundir com os cards abaixo. Cor derivada do `ink` →
/// contrasta nos dois temas (hairline escuro no claro, claro no escuro).
class _HeaderBorderPainter extends CustomPainter {
  const _HeaderBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    _traceHeaderBottom(path, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderBorderPainter old) => old.color != color;
}

/// Bottom navigation neumórfica do mobile: até 3 destinos principais + "Mais"
/// (sheet com o restante do menu gated). Alvos grandes, rótulo sempre visível
/// (usuário pouco digital — ícone sozinho não basta).
class _NeuBottomBar extends StatelessWidget {
  const _NeuBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final void Function(String route) onNavigate;

  static const int _slots = 3;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final primary = items.take(_slots).toList();
    final overflow = items.skip(_slots).toList();
    final overflowSelected = selectedIndex >= _slots;

    return Container(
      decoration: BoxDecoration(
        color: neu.surface,
        boxShadow: [
          BoxShadow(
            color: neu.shadowDark,
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < primary.length; i++)
                Expanded(
                  child: _BottomItem(
                    icon: primary[i].icon,
                    label: primary[i].label,
                    active: !overflowSelected && i == selectedIndex,
                    onTap: () => onNavigate(primary[i].route),
                  ),
                ),
              if (overflow.isNotEmpty)
                Expanded(
                  child: _BottomItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Mais',
                    active: overflowSelected,
                    onTap: () => _showMore(context, overflow),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, List<NavItem> overflow) {
    final neu = context.neu;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: neu.surface,
      // Permite a folha crescer e evita overflow: a lista rola quando há muitos
      // itens (telas baixas). O punho fica fixo no topo.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neu.inkFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in overflow)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NeuListTile(
                            leading: Icon(
                              item.icon,
                              color: neu.inkMuted,
                              size: 22,
                            ),
                            title: Text(item.label),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              onNavigate(item.route);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = active ? neu.navy : neu.inkMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: active ? neu.accentTint : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Atalho de criação rápida aninhado no berço do header. Abre um menu com as
/// ações de criação que o usuário PODE fazer (gated por módulo + permissão).
/// Some quando não há nenhuma.
class _QuickCreateFab extends ConsumerWidget {
  const _QuickCreateFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final me = session.meOrNull;
    if (me == null) return const SizedBox.shrink();
    final actions = quickActionsFor(me);
    if (actions.isEmpty) return const SizedBox.shrink();
    final neu = context.neu;
    return Tooltip(
      message: 'Criar',
      child: GestureDetector(
        onTap: () => _openMenu(context, ref, actions),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: neu.navy,
              boxShadow: [
                BoxShadow(
                  color: neu.navy.withValues(alpha: 0.42),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: neu.onNavy, size: 28),
          ),
        ),
      ),
    );
  }

  void _openMenu(
    BuildContext context,
    WidgetRef ref,
    List<QuickAction> actions,
  ) {
    final neu = context.neu;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: neu.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // Sem isto a folha fica limitada a 9/16 da tela: com mais ações — a de
      // despesa foi a 5ª — a lista passava do teto e estourava por poucos
      // pixels, no desktop e no celular. Com o teto solto, o `mainAxisSize.min`
      // do Column dimensiona pelo conteúdo e nada transborda.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neu.inkFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  'Criar',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuListTile(
                    leading: NeuIconChip.glyph(
                      context,
                      icon: a.icon,
                      index: a.glyph,
                      size: 40,
                    ),
                    title: Text(a.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _run(context, ref, a.key);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String key) async {
    switch (key) {
      case 'os':
        final id = await OrderFormDialog.show(context);
        if (id != null && context.mounted) context.go('/m/os/$id');
      case 'customer':
        final cfg = ref.read(customersConfigProvider).value;
        final ok = await CustomerFormDialog.show(
          context,
          documentRequired: cfg?.documentRequired ?? false,
        );
        if (ok != null) ref.invalidate(customersListProvider);
      case 'product':
        // Simples por padrão; "Cadastro completo" (dentro do diálogo) cobre
        // serviço e os campos avançados (código de barras, fiscal…).
        final ok = await SimpleItemFormDialog.show(context);
        if (ok != null) ref.invalidate(itemListProvider);
      case 'sale':
        // Venda avulsa = fluxo único em dialog (módulo `sale`, ação do Caixa).
        await showSaleCreateDialog(context);
      case 'expense':
        // Cadastro de conta a pagar (módulo `expenses`), não mais o lançamento
        // cru do caixa: o formulário pergunta o tipo (uma vez / todo mês /
        // parcelada), vencimento, categoria e fornecedor — e é o mesmo caminho
        // da tela de Despesas, para os dois lugares não divergirem.
        final criou = await showExpenseFormDialog(context, ref);
        // Invalida mesmo fora da tela de Despesas: se ela estiver montada atrás
        // (ou for aberta em seguida sem recarregar), a conta nova precisa estar lá.
        if (criou) ref.invalidate(despesasDoMesProvider);
    }
  }
}

/// Ações do menu "+" para este usuário — MÓDULO + PERMISSÃO, função pura.
///
/// Pública e sem contexto de propósito: o gating de menu é testado por fora da
/// árvore de widgets neste projeto (mesmo padrão de `gatedNavItems`), porque o
/// `AppShell` exige GoRouter e montá-lo só para conferir uma lista é frágil.
List<QuickAction> quickActionsFor(Me me) {
  return [
    if (me.hasModule('os') && me.hasPermission('os.write'))
      const QuickAction('os', Icons.build_rounded, 0, 'Nova ordem de serviço'),
    if (me.hasModule('sale') && me.hasPermission('sale.write'))
      const QuickAction('sale', Icons.point_of_sale_rounded, 2, 'Nova venda'),
    // Despesa é do módulo `expenses` (contas a pagar), não do caixa.
    //
    // Era `cashier.manage` + diálogo de lançamento do caixa: um gasto sem
    // vencimento, sem categoria própria e sem lugar para voltar. Agora abre o
    // cadastro de conta a pagar — que dá baixa NO caixa quando paga, então o
    // lançamento continua acontecendo, com contexto.
    if (me.hasModule('expenses') && me.hasPermission('finance.write'))
      const QuickAction(
        'expense',
        Icons.receipt_long_outlined,
        4,
        'Nova despesa',
      ),
    if (me.hasModule('customers') && me.hasPermission('customer.write'))
      const QuickAction(
        'customer',
        Icons.person_add_alt_1_rounded,
        3,
        'Novo cliente',
      ),
    if (me.hasModule('inventory') && me.hasPermission('inventory.write'))
      const QuickAction(
        'product',
        Icons.inventory_2_rounded,
        5,
        'Novo produto ou serviço',
      ),
  ];
}

/// Especificação de uma ação de criação rápida do menu "+".
class QuickAction {
  const QuickAction(this.key, this.icon, this.glyph, this.label);
  final String key;
  final IconData icon;
  final int glyph;
  final String label;
}
