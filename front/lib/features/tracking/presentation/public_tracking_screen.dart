import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/notification_sound.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../../os/presentation/os_status.dart';
import '../domain/tracking_models.dart';
import '../domain/tracking_repository.dart';

/// PUBLIC deep-link screen (`/t/:token`) — sem autenticação. É o que o cliente
/// abre no celular: status da OS + previsão + fotos + linha do tempo + chat com
/// a oficina. Layout standalone (sem sidebar/shell), mobile-first, centralizado.
class PublicTrackingScreen extends ConsumerStatefulWidget {
  const PublicTrackingScreen({super.key, required this.token});

  final String token;

  /// Token opaco bem-formado: url-safe, comprimento razoável.
  static final tokenPattern = RegExp(r'^[A-Za-z0-9_-]{6,128}$');

  @override
  ConsumerState<PublicTrackingScreen> createState() =>
      _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends ConsumerState<PublicTrackingScreen> {
  // Fallback do WebSocket: intervalo folgado (o tempo real vem do socket).
  static const _pollInterval = Duration(seconds: 30);

  late final TrackingRepository _repo = ref.read(trackingRepositoryProvider);
  late final bool _validToken =
      PublicTrackingScreen.tokenPattern.hasMatch(widget.token);

  bool _loading = true;
  AppException? _error;
  PublicTrack? _track;
  List<PublicMessage> _messages = const [];

  /// Aba selecionada na navegação por seções (0 = primeira aba disponível).
  int _tab = 0;

  final _msgController = TextEditingController();
  final _chatScroll = ScrollController();
  bool _sending = false;
  Timer? _poll;
  final RealtimeChat _rt = RealtimeChat();

  @override
  void initState() {
    super.initState();
    if (_validToken) {
      _load();
      // Tempo real: a resposta da oficina aparece na hora (push via WebSocket).
      // Toca um aviso sonoro quando a mensagem vem da oficina (não no próprio eco).
      _rt.connectPublic(
        token: widget.token,
        onMessage: (m) {
          if (m['sender'] == 'staff') unawaited(NotificationSound.play());
          _refreshQuietly();
        },
      );
      // Polling de segurança (fallback se o WS cair) — intervalo folgado.
      _poll = Timer.periodic(_pollInterval, (_) => _refreshQuietly());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _rt.dispose();
    _msgController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  /// Rola o chat para a mensagem mais recente (no fim da lista). Em [force] rola
  /// sempre (após enviar); senão só se o usuário já estava perto do fim — para
  /// não arrancar a rolagem dele enquanto lê o histórico durante o polling.
  void _scrollChatToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      final pos = _chatScroll.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (force || nearBottom) {
        _chatScroll.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.track(widget.token),
        _repo.messages(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _track = results[0] as PublicTrack;
        _messages = results[1] as List<PublicMessage>;
        _loading = false;
      });
      _scrollChatToBottom(force: true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Polling: atualiza track + mensagens sem mexer no estado de loading/erro.
  /// Engole erros (rede instável não deve estragar a tela).
  Future<void> _refreshQuietly() async {
    try {
      final results = await Future.wait([
        _repo.track(widget.token),
        _repo.messages(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _track = results[0] as PublicTrack;
        _messages = results[1] as List<PublicMessage>;
      });
      _scrollChatToBottom();
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _send() async {
    final body = _msgController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // Sem nome: o backend credita a mensagem ao nome do cliente da OS.
      await _repo.sendMessage(widget.token, body);
      _msgController.clear();
      final fresh = await _repo.messages(widget.token);
      if (!mounted) return;
      setState(() => _messages = fresh);
      _scrollChatToBottom(force: true);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Tokens do design system: esta página força tema claro (lavanda/navy) para
  // passar confiança e nunca quebrar, independente do modo do staff.
  late final NeuTokens _neu = NeuTokens.light();

  @override
  Widget build(BuildContext context) {
    // Página voltada ao cliente: tema FIXO claro e on-brand, independente do
    // modo de tema do staff (claro/escuro) — as cores nunca quebram.
    return Theme(
      data: AppTheme.light(seed: AppColors.brand),
      child: Scaffold(
        backgroundColor: _neu.base,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_validToken) {
      return _notFoundBody();
    }
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null || _track == null) {
      return _notFoundBody();
    }
    return _content(_track!);
  }

  Widget _notFoundBody() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 24),
            Center(child: BrandMark(size: 28)),
            SizedBox(height: 28),
            NeuEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Acompanhamento não encontrado',
              message:
                  'Verifique o link recebido. Se o problema continuar, entre '
                  'em contato com a oficina.',
            ),
          ],
        ),
      );

  Widget _content(PublicTrack t) {
    // Navegação por seções: o cliente não se perde num scroll longo. Header de
    // marca + status ficam SEMPRE visíveis (o que ele mais quer ver); o resto é
    // organizado em abas. Abas condicionais (ex.: Fotos) só aparecem se há dado.
    final tabs = <_TrackTab>[
      _TrackTab('Serviço', Icons.build_outlined, () => _servicoTab(t)),
      if (t.photos.isNotEmpty)
        _TrackTab('Fotos', Icons.photo_library_outlined,
            () => _photosCard(t.photos)),
      _TrackTab('Histórico', Icons.timeline_outlined,
          () => _timelineCard(t.timeline)),
      _TrackTab('Conversa', Icons.chat_bubble_outline, _chatCard),
    ];
    final sel = _tab.clamp(0, tabs.length - 1);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, context.isMobile ? 32 : 40),
        children: [
          _brandHeader(t),
          const SizedBox(height: 16),
          _statusSection(t),
          const SizedBox(height: 16),
          _SectionNav(
            tabs: tabs,
            selected: sel,
            onSelect: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(key: ValueKey(sel), child: tabs[sel].builder()),
        ],
      ),
    );
  }

  /// Aba "Serviço": previsão de entrega + diagnóstico. Vazia → aviso amigável.
  Widget _servicoTab(PublicTrack t) {
    final hasPrev = t.scheduledEnd != null && t.scheduledEnd!.isNotEmpty;
    final hasDiag = t.diagnosis != null && t.diagnosis!.trim().isNotEmpty;
    if (!hasPrev && !hasDiag) {
      return _sectionCard(
        icon: Icons.build_outlined,
        color: _neu.glyphs[0],
        title: 'Serviço',
        child: Text(
          'Assim que a oficina registrar o diagnóstico e a previsão de entrega, '
          'as informações aparecerão aqui.',
          style: TextStyle(color: _neu.inkMuted, fontSize: 14, height: 1.4),
        ),
      );
    }
    return Column(
      children: [
        if (hasPrev) _previsao(t.scheduledEnd!),
        if (hasPrev && hasDiag) const SizedBox(height: 16),
        if (hasDiag) _diagnosisCard(t.diagnosis!.trim()),
      ],
    );
  }

  // ---- Cabeçalho de marca (bloco navy de destaque) ----

  Widget _brandHeader(PublicTrack t) {
    final company = t.company;
    final tt = Theme.of(context).textTheme;
    final onNavyMuted = Colors.white.withValues(alpha: .66);
    return NeuPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (company.logoUrl != null && company.logoUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      company.logoUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  company.name.isEmpty ? 'Oficina' : company.name,
                  style: (tt.titleLarge ?? const TextStyle()).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'ORDEM DE SERVIÇO',
            style: TextStyle(
              color: onNavyMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            t.number.isEmpty ? 'Em andamento' : 'Nº ${t.number}',
            style: (tt.headlineSmall ?? const TextStyle()).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (t.subjectLabel != null && t.subjectLabel!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.subjectLabel!,
              style: TextStyle(color: onNavyMuted, fontSize: 14),
            ),
          ],
          if (t.responsibleName != null && t.responsibleName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: onNavyMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Responsável: ${t.responsibleName!}',
                    style: TextStyle(color: onNavyMuted, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- Status atual + linha de progresso ----

  Widget _statusSection(PublicTrack t) {
    final cancelled = _isCancelled(t.status);
    final color =
        t.status.isNotEmpty ? osStatusColor(t.status) : _neu.accent;
    final label = t.statusLabel.isNotEmpty
        ? t.statusLabel
        : (t.status.isNotEmpty ? osStatusLabel(t.status) : 'Em andamento');
    return _sectionCard(
      icon: Icons.assignment_turned_in_outlined,
      color: _neu.glyphs[1],
      title: 'Status atual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bigStatusPill(color, label),
          const SizedBox(height: 18),
          if (cancelled) _cancelledBanner() else _stepper(t.status),
        ],
      ),
    );
  }

  Widget _bigStatusPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelledBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _neu.dangerTint,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined, color: _neu.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta ordem de serviço foi cancelada. Fale com a oficina para '
              'mais informações.',
              style: TextStyle(
                color: _neu.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mini-stepper da jornada do cliente (derivado do status real da OS).
  static const _journeyLabels = ['Recebida', 'Aprovada', 'Em execução', 'Pronta'];

  int _stageIndex(String status) {
    switch (status) {
      case 'aprovada':
        return 1;
      case 'em_execucao':
        return 2;
      case 'concluida':
      case 'entregue':
        return 3;
      case 'aberta':
      case 'aguardando_aprovacao':
      default:
        return 0;
    }
  }

  bool _isCancelled(String status) => status == 'cancelada';

  Widget _stepper(String status) {
    final current = _stageIndex(status);
    final n = _journeyLabels.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++)
          Expanded(child: _stepNode(i, current, n)),
      ],
    );
  }

  Widget _stepNode(int i, int current, int n) {
    final reached = i <= current;
    final active = i == current;
    final done = i < current;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: i == 0
                  ? const SizedBox()
                  : Container(
                      height: 3,
                      color: i <= current ? _neu.navy : _neu.line,
                    ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? _neu.navy : _neu.surface,
                border: Border.all(
                  color: reached ? _neu.navy : _neu.line,
                  width: 2,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _neu.navy.withValues(alpha: .35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 15, color: _neu.onNavy)
                  : (active
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _neu.onNavy,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null),
            ),
            Expanded(
              child: i == n - 1
                  ? const SizedBox()
                  : Container(
                      height: 3,
                      color: (i + 1) <= current ? _neu.navy : _neu.line,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          _journeyLabels[i],
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.15,
            color: reached ? _neu.ink : _neu.inkFaint,
            fontWeight: active
                ? FontWeight.w800
                : (reached ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // ---- Cards de conteúdo ----

  Widget _previsao(String iso) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          NeuIconChip(
            icon: Icons.event_available_rounded,
            color: _neu.info,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Previsão de entrega',
                  style: TextStyle(color: _neu.inkMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(iso),
                  style: TextStyle(
                    color: _neu.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosisCard(String text) {
    return _sectionCard(
      icon: Icons.build_circle_outlined,
      color: _neu.glyphs[0],
      title: 'Diagnóstico',
      child: Text(
        text,
        style: TextStyle(color: _neu.ink, fontSize: 14.5, height: 1.5),
      ),
    );
  }

  Widget _photosCard(List<PublicPhoto> photos) {
    return _sectionCard(
      icon: Icons.photo_library_outlined,
      color: _neu.glyphs[3],
      title: 'Fotos',
      child: _gallery(photos),
    );
  }

  Widget _gallery(List<PublicPhoto> photos) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = photos[i];
          return GestureDetector(
            onTap: () => _openPhotoViewer(photos, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NeuTokens.rCard),
              child: Image.network(
                p.url,
                width: 162,
                height: 124,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 162,
                  height: 124,
                  color: _neu.base,
                  child: Icon(Icons.broken_image, color: _neu.inkFaint),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Abre o visualizador em tela cheia (zoom + swipe entre as fotos),
  /// começando na foto tocada.
  void _openPhotoViewer(List<PublicPhoto> photos, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (_) => _PhotoViewer(photos: photos, initialIndex: initialIndex),
    );
  }

  Widget _timelineCard(List<PublicEvent> events) {
    return _sectionCard(
      icon: Icons.timeline_rounded,
      color: _neu.glyphs[2],
      title: 'Linha do tempo',
      child: _timelineBody(events),
    );
  }

  Widget _timelineBody(List<PublicEvent> events) {
    if (events.isEmpty) {
      return Text(
        'Ainda sem atualizações.',
        style: TextStyle(color: _neu.inkMuted, fontSize: 14),
      );
    }
    // O backend já devolve mais recente primeiro; garantimos a ordem na UI.
    final ordered = [...events]..sort((a, b) {
        final da = DateTime.tryParse(a.createdAt ?? '');
        final db = DateTime.tryParse(b.createdAt ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ordered.length; i++)
          _TimelineRow(
            event: ordered[i],
            isLast: i == ordered.length - 1,
            relativeTime: _relative(ordered[i].createdAt),
          ),
      ],
    );
  }

  // ---- Chat com a oficina ----

  Widget _chatCard() {
    return _sectionCard(
      icon: Icons.forum_outlined,
      color: _neu.glyphs[5],
      title: 'Conversa com a oficina',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_messages.isEmpty)
            _chatEmpty()
          else
            // Lista com rolagem PRÓPRIA e altura limitada: o chat não estica a
            // página inteira; o campo de envio fica sempre visível logo abaixo.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                controller: _chatScroll,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _messages.length,
                itemBuilder: (_, i) => _bubble(_messages[i]),
              ),
            ),
          const SizedBox(height: 14),
          _composer(),
        ],
      ),
    );
  }

  Widget _chatEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: _neu.inkFaint, size: 26),
          const SizedBox(height: 8),
          Text(
            'Sem mensagens ainda.\nEnvie uma mensagem para a oficina.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _neu.inkMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _msgController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(fontSize: 14.5, color: _neu.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'Escreva uma mensagem...',
                hintStyle: TextStyle(color: _neu.inkFaint, fontSize: 14.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: _neu.navy,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _sending ? null : _send,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: _sending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _neu.onNavy),
                    )
                  : Icon(Icons.send_rounded, size: 20, color: _neu.onNavy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(PublicMessage m) {
    final isCustomer = m.sender == 'customer';
    final align =
        isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isCustomer ? _neu.navy : _neu.surfaceHi;
    final fg = isCustomer ? _neu.onNavy : _neu.ink;
    final author = isCustomer
        ? (m.authorName == null || m.authorName!.isEmpty
            ? 'Você'
            : m.authorName!)
        : (m.authorName == null || m.authorName!.isEmpty
            ? 'Oficina'
            : m.authorName!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              author,
              style: TextStyle(
                color: _neu.inkMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isCustomer ? 14 : 4),
                bottomRight: Radius.circular(isCustomer ? 4 : 14),
              ),
            ),
            child: Text(
              m.body,
              style: TextStyle(color: fg, fontSize: 14.5, height: 1.35),
            ),
          ),
          if (m.createdAt != null && m.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _relative(m.createdAt),
                  style: TextStyle(color: _neu.inkFaint, fontSize: 11),
                ),
                // Recibo de leitura nas mensagens do próprio cliente: 1 tracinho
                // = enviada; 2 azuis = a oficina já leu.
                if (isCustomer) ...[
                  const SizedBox(width: 4),
                  ReadTicks(read: m.readAt != null),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Card padrão de conteúdo: chip de ícone colorido + título + corpo.
  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip(icon: icon, color: color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: _neu.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} de ${_months[l.month - 1]}. ${l.year} • $hh:$mm';
  }

  String _relative(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays < 30) return 'há ${diff.inDays} d';
    return _formatDate(iso);
  }
}

/// Visualizador de fotos em tela cheia para o cliente: fundo preto, swipe
/// horizontal entre as fotos e pinça/duplo-toque pra dar zoom. Fecha no X.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<PublicPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.photos[i].url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54,
                        size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Botão de fechar (respeitando o notch/status bar).
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          // Contador "1 / N" quando há mais de uma foto.
          if (total > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_current + 1} / $total',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.relativeTime,
  });

  final PublicEvent event;
  final bool isLast;
  final String relativeTime;

  IconData get _icon {
    switch (event.kind) {
      case 'created':
        return Icons.flag_outlined;
      case 'status_change':
        return Icons.swap_horiz;
      case 'photo':
        return Icons.photo_camera_outlined;
      case 'note':
      default:
        return Icons.chat_bubble_outline;
    }
  }

  String _label() {
    if (event.message != null && event.message!.isNotEmpty) {
      return event.message!;
    }
    if (event.kind == 'status_change' &&
        event.statusSnapshot != null &&
        event.statusSnapshot!.isNotEmpty) {
      return 'Status: ${osStatusLabel(event.statusSnapshot!)}';
    }
    switch (event.kind) {
      case 'created':
        return 'Ordem de serviço aberta';
      case 'photo':
        return 'Nova foto adicionada';
      default:
        return 'Atualização';
    }
  }

  Color _kindColor(NeuTokens neu) {
    switch (event.kind) {
      case 'created':
        return neu.success;
      case 'status_change':
        return neu.navy;
      case 'photo':
        return neu.info;
      case 'note':
      default:
        return neu.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = _kindColor(neu);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: neu.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: neu.ink,
                      height: 1.3,
                    ),
                  ),
                  if (relativeTime.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      relativeTime,
                      style: TextStyle(color: neu.inkFaint, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma aba da navegação por seções da página pública.
class _TrackTab {
  const _TrackTab(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

/// Navegação por seções (abas em pílula, roláveis na horizontal) da página
/// pública — organiza o conteúdo para o cliente não se perder num scroll longo.
class _SectionNav extends StatelessWidget {
  const _SectionNav({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<_TrackTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selected;
          return InkWell(
            onTap: active ? null : () => onSelect(i),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? neu.navy : neu.surface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? null : neu.raised(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tabs[i].icon,
                    size: 17,
                    color: active ? neu.onNavy : neu.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    tabs[i].label,
                    style: TextStyle(
                      color: active ? neu.onNavy : neu.inkMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
