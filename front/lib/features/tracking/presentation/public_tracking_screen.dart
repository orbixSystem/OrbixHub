import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
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
  static const _pollInterval = Duration(seconds: 15);

  late final TrackingRepository _repo = ref.read(trackingRepositoryProvider);
  late final bool _validToken =
      PublicTrackingScreen.tokenPattern.hasMatch(widget.token);

  bool _loading = true;
  AppException? _error;
  PublicTrack? _track;
  List<PublicMessage> _messages = const [];

  final _msgController = TextEditingController();
  final _nameController = TextEditingController();
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (_validToken) {
      _load();
      _poll = Timer.periodic(_pollInterval, (_) => _refreshQuietly());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _msgController.dispose();
    _nameController.dispose();
    super.dispose();
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
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _send() async {
    final body = _msgController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(
        widget.token,
        body,
        authorName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );
      _msgController.clear();
      final fresh = await _repo.messages(widget.token);
      if (!mounted) return;
      setState(() => _messages = fresh);
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_validToken) {
      return _centeredCard(_notFound());
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
      return _centeredCard(_notFound());
    }
    return _content(_track!);
  }

  Widget _centeredCard(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Center(child: BrandMark(size: 26)),
            const SizedBox(height: 28),
            _surface(child),
          ],
        ),
      );

  Widget _notFound() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.search_off, color: AppColors.inkMuted, size: 30),
          const SizedBox(height: 12),
          Text('Acompanhamento não encontrado',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Verifique o link recebido. Se o problema continuar, entre em '
            'contato com a oficina.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13.5),
          ),
        ],
      );

  Widget _content(PublicTrack t) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _header(t),
          const SizedBox(height: 18),
          if (t.scheduledEnd != null && t.scheduledEnd!.isNotEmpty) ...[
            _previsao(t.scheduledEnd!),
            const SizedBox(height: 18),
          ],
          if (t.photos.isNotEmpty) ...[
            _sectionTitle('Fotos'),
            const SizedBox(height: 10),
            _gallery(t.photos),
            const SizedBox(height: 18),
          ],
          _sectionTitle('Linha do tempo'),
          const SizedBox(height: 10),
          _timeline(t.timeline),
          const SizedBox(height: 22),
          _sectionTitle('Conversa com a oficina'),
          const SizedBox(height: 10),
          _chat(),
        ],
      ),
    );
  }

  Widget _header(PublicTrack t) {
    final company = t.company;
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (company.logoUrl != null && company.logoUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      company.logoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  company.name.isEmpty ? 'Oficina' : company.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.number.isEmpty ? 'Ordem de serviço' : 'OS ${t.number}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (t.subjectLabel != null &&
                        t.subjectLabel!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(t.subjectLabel!,
                          style: const TextStyle(
                              color: AppColors.inkMuted, fontSize: 13.5)),
                    ],
                  ],
                ),
              ),
              _statusChip(t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(PublicTrack t) {
    final color =
        t.status.isNotEmpty ? osStatusColor(t.status) : AppColors.brand;
    final label = t.statusLabel.isNotEmpty
        ? t.statusLabel
        : (t.status.isNotEmpty ? osStatusLabel(t.status) : 'Em andamento');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }

  Widget _previsao(String iso) {
    return _surface(
      Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Previsão de entrega',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(_formatDate(iso),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery(List<PublicPhoto> photos) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = photos[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              p.url,
              width: 170,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 170,
                height: 130,
                color: AppColors.surfaceSunken,
                child: const Icon(Icons.broken_image,
                    color: AppColors.inkFaint),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timeline(List<PublicEvent> events) {
    if (events.isEmpty) {
      return _surface(const Text('Ainda sem atualizações.',
          style: TextStyle(color: AppColors.inkMuted)));
    }
    // O backend já devolve mais recente primeiro; garantimos a ordem na UI.
    final ordered = [...events]..sort((a, b) {
        final da = DateTime.tryParse(a.createdAt ?? '');
        final db = DateTime.tryParse(b.createdAt ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < ordered.length; i++)
            _TimelineRow(
              event: ordered[i],
              isLast: i == ordered.length - 1,
              relativeTime: _relative(ordered[i].createdAt),
            ),
        ],
      ),
    );
  }

  Widget _chat() {
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sem mensagens ainda. Envie uma mensagem para a oficina.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13.5),
              ),
            )
          else
            for (final m in _messages) _bubble(m),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Seu nome (opcional)',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Escreva uma mensagem...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(PublicMessage m) {
    final isCustomer = m.sender == 'customer';
    final align =
        isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isCustomer ? AppColors.brandTint : AppColors.surfaceSunken;
    final author = isCustomer
        ? (m.authorName == null || m.authorName!.isEmpty
            ? 'Você'
            : m.authorName!)
        : (m.authorName == null || m.authorName!.isEmpty
            ? 'Oficina'
            : m.authorName!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(author,
              style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(m.body, style: const TextStyle(fontSize: 14)),
          ),
          if (m.createdAt != null && m.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_relative(m.createdAt),
                style: const TextStyle(
                    color: AppColors.inkFaint, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
      );

  Widget _surface(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

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

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 16, color: AppColors.brandDeep),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (relativeTime.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(relativeTime,
                        style: const TextStyle(
                            color: AppColors.inkFaint, fontSize: 12)),
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
