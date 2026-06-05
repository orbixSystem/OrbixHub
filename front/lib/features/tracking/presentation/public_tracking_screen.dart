import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/tracking_models.dart';

/// PUBLIC deep-link screen (`/t/:token`) — no authentication. Validates the
/// token format before hitting the (currently mocked) tracking source.
class PublicTrackingScreen extends ConsumerStatefulWidget {
  const PublicTrackingScreen({super.key, required this.token});

  final String token;

  /// Well-formed opaque token: url-safe, reasonable length.
  static final tokenPattern = RegExp(r'^[A-Za-z0-9_-]{6,128}$');

  @override
  ConsumerState<PublicTrackingScreen> createState() =>
      _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends ConsumerState<PublicTrackingScreen> {
  late final Future<TrackingStatus>? _future =
      PublicTrackingScreen.tokenPattern.hasMatch(widget.token)
          ? ref.read(trackingRepositoryProvider).fetchByToken(widget.token)
          : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhamento')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _future == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Link de acompanhamento inválido.'),
                )
              : FutureBuilder<TrackingStatus>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }
                    if (snap.hasError || !snap.hasData) {
                      return const Text('Não foi possível carregar o status.');
                    }
                    return _TrackingView(status: snap.data!);
                  },
                ),
        ),
      ),
    );
  }
}

class _TrackingView extends StatelessWidget {
  const _TrackingView({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(24),
      children: [
        Text(status.vehicle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Chip(label: Text(status.statusLabel)),
        const SizedBox(height: 16),
        ...status.steps.map(
          (s) => ListTile(
            leading: Icon(
              s.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: s.done ? Colors.green : null,
            ),
            title: Text(s.label),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Prévia (dados de demonstração) — o acompanhamento real chega com o '
          'módulo de Ordens de Serviço.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
