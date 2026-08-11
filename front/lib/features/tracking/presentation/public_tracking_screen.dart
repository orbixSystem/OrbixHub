import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Mensagem que o cliente está respondendo (citação estilo WhatsApp).
  /// `null` = sem citação. Definida por long-press numa bolha.
  PublicMessage? _replyTarget;

  /// Nome com que o cliente se identifica no chat/comentários. Salvo no cache
  /// local (SharedPreferences) do dispositivo de quem abriu o link — editável.
  String? _customerName;
  static const _nameKey = 'public_track_customer_name';

  @override
  void initState() {
    super.initState();
    if (_validToken) {
      _load();
      _loadName();
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

  /// Carrega o nome salvo no cache local. Na PRIMEIRA visita (sem nome), pede
  /// o nome logo após o primeiro frame (o cliente se identifica).
  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_nameKey)?.trim();
    if (!mounted) return;
    if (saved != null && saved.isNotEmpty) {
      setState(() => _customerName = saved);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptName(firstTime: true);
      });
    }
  }

  /// Diálogo para informar/editar o nome. Salva no cache local (por dispositivo).
  Future<void> _promptName({bool firstTime = false}) async {
    final neu = context.neu;
    final ctrl = TextEditingController(text: _customerName ?? '');
    final name = await showNeuDialog<String>(
      context,
      dialog: NeuDialog(
        title: firstTime ? 'Como podemos te chamar?' : 'Seu nome',
        maxWidth: 420,
        actions: [
          NeuButton(
            label: 'Salvar',
            icon: Icons.check_rounded,
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seu nome aparece para a oficina nas mensagens e comentários. '
              'Fica salvo só neste aparelho e você pode trocar quando quiser.',
              style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            NeuTextField(
              controller: ctrl,
              label: 'Seu nome',
              hint: 'Ex.: João Silva',
              maxLength: 80,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) =>
                  Navigator.of(context).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    if (mounted) setState(() => _customerName = trimmed);
  }

  /// Garante que há um nome antes de enviar/comentar — pede se faltar. Retorna
  /// o nome atual (ou null se o cliente não informou).
  Future<String?> _ensureName() async {
    if ((_customerName ?? '').isNotEmpty) return _customerName;
    await _promptName();
    return (_customerName ?? '').isNotEmpty ? _customerName : null;
  }

  Future<void> _send({String? photoId}) async {
    var body = _msgController.text.trim();
    // Ao citar uma foto sem escrever nada, o backend ainda exige um corpo
    // (mín. 1 caractere) — usamos um rótulo curto e claro.
    if (photoId != null && body.isEmpty) body = 'Foto';
    if (body.isEmpty || _sending) return;
    // Exige que o cliente tenha se identificado (nome no cache local).
    final name = await _ensureName();
    if (name == null) return;
    // Captura a citação antes de limpar (evita corrida com o setState final).
    final replyToId = _replyTarget?.id;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(
        widget.token,
        body,
        authorName: name,
        replyToId: replyToId,
        photoId: photoId,
      );
      _msgController.clear();
      final fresh = await _repo.messages(widget.token);
      if (!mounted) return;
      setState(() {
        _messages = fresh;
        _replyTarget = null;
      });
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

  /// Inicia uma citação (responder) a partir de uma bolha (long-press).
  void _startReply(PublicMessage m) {
    setState(() => _replyTarget = m);
  }

  /// Rótulo do autor sob a ótica do cliente: as próprias mensagens são "Você",
  /// as da oficina são "Oficina" (ou o nome informado pela oficina).
  String _senderLabel(String sender, String? name) {
    if (sender == 'customer') {
      return (name == null || name.isEmpty) ? 'Você' : name;
    }
    return (name == null || name.isEmpty) ? 'Oficina' : name;
  }

  /// Folha (bottom sheet) para o cliente citar uma foto da OS no chat. Só lista
  /// fotos com `id` (a url é resolvida no servidor pelo id — nunca confiamos na
  /// url do cliente).
  void _showPhotoPicker(List<PublicPhoto> photos) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _neu.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NeuTokens.rPanel)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enviar foto da ordem',
                style: TextStyle(
                  color: _neu.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque numa foto para enviá-la na conversa com a oficina.',
                style: TextStyle(color: _neu.inkMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in photos)
                    InkWell(
                      borderRadius: BorderRadius.circular(NeuTokens.rCard),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _send(photoId: p.id);
                      },
                      child: NeuNetworkImage(
                        url: p.url,
                        width: 96,
                        height: 96,
                        radius: NeuTokens.rCard,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onNavyMuted, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _nameChip(onNavyMuted),
        ],
      ),
    );
  }

  /// Chip com o nome do cliente, editável — mostra como ele se identifica e
  /// permite trocar o nome (salvo no cache local). Sem nome → convida a informar.
  Widget _nameChip(Color onNavyMuted) {
    final hasName = (_customerName ?? '').isNotEmpty;
    return InkWell(
      onTap: () => _promptName(),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 16, color: onNavyMuted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasName ? 'Você: ${_customerName!}' : 'Identifique-se para conversar',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 15, color: onNavyMuted),
          ],
        ),
      ),
    );
  }

  // ---- Status atual + linha de progresso ----

  Widget _statusSection(PublicTrack t) {
    // Mesmos 3 estados simplificados que a equipe vê na ficha (Em andamento/
    // Finalizada/Cancelada) — o cliente não precisa (nem deveria) enxergar os
    // 7 status internos do workflow.
    final atual =
        t.status.isNotEmpty ? osSimpleStatusOf(t.status) : OsSimpleStatus.emAndamento;
    return _sectionCard(
      icon: Icons.assignment_turned_in_outlined,
      color: _neu.glyphs[1],
      title: 'Status atual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final s in OsSimpleStatus.values) ...[
                if (s != OsSimpleStatus.values.first) const SizedBox(width: 10),
                Expanded(child: _simpleStatusBadge(s, selected: s == atual)),
              ],
            ],
          ),
          if (atual == OsSimpleStatus.cancelada) ...[
            const SizedBox(height: 14),
            _cancelledBanner(),
          ],
        ],
      ),
    );
  }

  /// Um dos 3 segmentos do status simplificado — preenchido quando é o
  /// estado atual da OS; só leitura (o cliente não tem ação aqui).
  Widget _simpleStatusBadge(OsSimpleStatus s, {required bool selected}) {
    final color = osSimpleStatusColor(s);
    final bg = selected ? color : color.withValues(alpha: .12);
    final fg = selected ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        border:
            selected ? null : Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(osSimpleStatusIcon(s), size: 20, color: fg),
          const SizedBox(height: 6),
          Text(
            osSimpleStatusLabel(s),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < photos.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 20),
              Divider(color: _neu.line, height: 1),
              const SizedBox(height: 20),
            ],
            _photoItem(photos, i),
          ],
        ],
      ),
    );
  }

  Widget _photoItem(List<PublicPhoto> photos, int i) {
    final p = photos[i];
    final hasId = p.id != null && p.id!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _openPhotoViewer(photos, i),
          child: NeuNetworkImage(
            url: p.url,
            height: 210,
            radius: NeuTokens.rCard,
          ),
        ),
        if (p.caption != null && p.caption!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            p.caption!.trim(),
            style: TextStyle(color: _neu.inkMuted, fontSize: 13.5, height: 1.4),
          ),
        ],
        if (hasId) ...[
          const SizedBox(height: 14),
          _PhotoCommentsSection(
            repo: _repo,
            token: widget.token,
            photoId: p.id!,
            senderLabel: _senderLabel,
            relativeTime: _relative,
            ensureName: _ensureName,
          ),
        ],
      ],
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
    // Fotos citáveis: só as que têm id (a url é resolvida no servidor pelo id).
    final citablePhotos = (_track?.photos ?? const <PublicPhoto>[])
        .where((p) => p.id != null && p.id!.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyTarget != null) ...[
          _replyPreviewBar(_replyTarget!),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (citablePhotos.isNotEmpty) ...[
              _roundButton(
                icon: Icons.add_photo_alternate_outlined,
                bg: _neu.surfaceHi,
                fg: _neu.navy,
                tooltip: 'Enviar foto da ordem',
                onTap: _sending ? null : () => _showPhotoPicker(citablePhotos),
              ),
              const SizedBox(width: 8),
            ],
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
            _roundButton(
              icon: Icons.send_rounded,
              bg: _neu.navy,
              fg: _neu.onNavy,
              tooltip: 'Enviar',
              loading: _sending,
              onTap: _sending ? null : () => _send(),
            ),
          ],
        ),
      ],
    );
  }

  /// Botão circular do composer (foto / enviar). Alvo de toque ≥ 46px.
  Widget _roundButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required String tooltip,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }

  /// Barra de citação acima do composer: barra colorida + autor + trecho + X.
  Widget _replyPreviewBar(PublicMessage m) {
    final label = _senderLabel(m.sender, m.authorName);
    final hasBody = m.body.trim().isNotEmpty;
    final snippet = hasBody
        ? m.body.trim()
        : (m.photoUrl != null && m.photoUrl!.isNotEmpty ? 'Foto' : '');
    return Container(
      decoration: BoxDecoration(
        color: _neu.surfaceHi,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        border: Border(left: BorderSide(color: _neu.navy, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18, color: _neu.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Respondendo a $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _neu.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _neu.inkMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: _neu.inkMuted),
            tooltip: 'Cancelar resposta',
            onPressed: () => setState(() => _replyTarget = null),
          ),
        ],
      ),
    );
  }

  /// Bloco de citação DENTRO da bolha (mostra a mensagem respondida).
  Widget _quoteBlock(PublicQuote q, {required bool onNavyBg}) {
    final label = _senderLabel(q.sender, q.authorName);
    final barColor = onNavyBg ? _neu.onNavy : _neu.navy;
    final panelBg =
        onNavyBg ? Colors.white.withValues(alpha: .16) : _neu.base;
    final titleColor = onNavyBg ? _neu.onNavy : _neu.navy;
    final bodyColor = onNavyBg ? _neu.onNavyMuted : _neu.inkMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (q.body.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              q.body.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 12.5, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bubble(PublicMessage m) {
    final isCustomer = m.sender == 'customer';
    final align =
        isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isCustomer ? _neu.navy : _neu.surfaceHi;
    final fg = isCustomer ? _neu.onNavy : _neu.ink;
    final author = _senderLabel(m.sender, m.authorName);
    final hasPhoto = m.photoUrl != null && m.photoUrl!.isNotEmpty;
    final hasBody = m.body.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _neu.inkMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Long-press = responder (citar) esta mensagem, estilo WhatsApp.
          GestureDetector(
            onLongPress: () => _startReply(m),
            child: Container(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.replyTo != null)
                    _quoteBlock(m.replyTo!, onNavyBg: isCustomer),
                  if (hasPhoto) ...[
                    GestureDetector(
                      onTap: () => _openPhotoViewer(
                        [PublicPhoto(url: m.photoUrl!)],
                        0,
                      ),
                      child: NeuNetworkImage(
                        url: m.photoUrl,
                        width: 210,
                        height: 158,
                        radius: 10,
                      ),
                    ),
                    if (hasBody) const SizedBox(height: 8),
                  ],
                  if (hasBody)
                    Text(
                      m.body,
                      style: TextStyle(color: fg, fontSize: 14.5, height: 1.35),
                    ),
                ],
              ),
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

/// Thread de comentários de UMA foto da OS (lado cliente). Carrega os
/// comentários existentes e permite ao cliente comentar. Fica sob o tema claro
/// fixo da página pública, então lê os tokens via `context.neu`.
class _PhotoCommentsSection extends StatefulWidget {
  const _PhotoCommentsSection({
    required this.repo,
    required this.token,
    required this.photoId,
    required this.senderLabel,
    required this.relativeTime,
    required this.ensureName,
  });

  final TrackingRepository repo;
  final String token;
  final String photoId;

  /// Reaproveita a lógica de rótulo/tempo da tela para manter consistência.
  final String Function(String sender, String? name) senderLabel;
  final String Function(String? iso) relativeTime;

  /// Garante o nome do cliente (pede se faltar). Retorna null se não informado.
  final Future<String?> Function() ensureName;

  @override
  State<_PhotoCommentsSection> createState() => _PhotoCommentsSectionState();
}

class _PhotoCommentsSectionState extends State<_PhotoCommentsSection> {
  late Future<List<PublicPhotoComment>> _future = _fetch();
  final _controller = TextEditingController();
  bool _sending = false;

  Future<List<PublicPhotoComment>> _fetch() =>
      widget.repo.photoComments(widget.token, widget.photoId);

  void _reload() => setState(() => _future = _fetch());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    // Exige que o cliente tenha se identificado antes de comentar.
    final name = await widget.ensureName();
    if (name == null) return;
    setState(() => _sending = true);
    try {
      await widget.repo
          .addPhotoComment(widget.token, widget.photoId, body, authorName: name);
      _controller.clear();
      _reload();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.mode_comment_outlined, size: 15, color: neu.inkMuted),
            const SizedBox(width: 6),
            Text(
              'Comentários',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<PublicPhotoComment>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: neu.inkFaint,
                    ),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return _hint(neu, 'Não foi possível carregar os comentários.');
            }
            final comments = snap.data ?? const <PublicPhotoComment>[];
            if (comments.isEmpty) {
              return _hint(neu, 'Ainda sem comentários nesta foto.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in comments) _commentRow(neu, c),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _commentComposer(neu),
      ],
    );
  }

  Widget _hint(NeuTokens neu, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(color: neu.inkFaint, fontSize: 13, height: 1.35),
        ),
      );

  Widget _commentRow(NeuTokens neu, PublicPhotoComment c) {
    final isCustomer = c.authorKind == 'customer';
    final author = widget.senderLabel(
      isCustomer ? 'customer' : 'staff',
      c.authorName,
    );
    final when = widget.relativeTime(c.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isCustomer ? neu.navy : neu.accent).withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCustomer ? Icons.person_outline : Icons.storefront_outlined,
              size: 16,
              color: isCustomer ? neu.navy : neu.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: TextStyle(color: neu.inkFaint, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.body,
                  style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentComposer(NeuTokens neu) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _add(),
              style: TextStyle(fontSize: 13.5, color: neu.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'Comentar esta foto...',
                hintStyle: TextStyle(color: neu.inkFaint, fontSize: 13.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: neu.navy,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _sending ? null : _add,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: neu.onNavy,
                      ),
                    )
                  : Icon(Icons.send_rounded, size: 18, color: neu.onNavy),
            ),
          ),
        ),
      ],
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
