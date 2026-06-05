import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 26)),
                  const SizedBox(height: 28),
                  if (_future == null)
                    _card(const Text('Link de acompanhamento inválido.'))
                  else
                    FutureBuilder<TrackingStatus>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return _card(const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(),
                            ),
                          ));
                        }
                        if (snap.hasError || !snap.hasData) {
                          return _card(
                              const Text('Não foi possível carregar o status.'));
                        }
                        return _TrackingCard(status: snap.data!);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Acompanhamento do serviço',
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(status.vehicle,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.statusLabel,
                style: const TextStyle(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          for (var i = 0; i < status.steps.length; i++)
            _TimelineRow(
              step: status.steps[i],
              isLast: i == status.steps.length - 1,
            ),
          const SizedBox(height: 8),
          const Text(
            'Prévia (dados de demonstração) — o acompanhamento real chega com o '
            'módulo de Ordens de Serviço.',
            style: TextStyle(
                color: AppColors.inkFaint,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});
  final TrackingStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : AppColors.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? AppColors.success : AppColors.line,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppColors.success : AppColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 18),
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                color: done ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
