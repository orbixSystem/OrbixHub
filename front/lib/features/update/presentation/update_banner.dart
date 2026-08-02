import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../data/update_installer.dart';
import '../domain/update_models.dart';
import 'update_controller.dart';

/// Aviso de versão nova no topo do app. Discreto e adiável — a oficina está no
/// meio do trabalho. Some sozinho quando o app já está em dia, e não aparece
/// quando a atualização é obrigatória (nesse caso a tela inteira é bloqueada).
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _adiado = false;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final async = ref.watch(updateStatusProvider);
    final data = async.asData?.value;
    if (_adiado ||
        data == null ||
        data.status != UpdateStatus.disponivel) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: NeuSurface(
        elevation: NeuElevation.flat,
        radius: NeuTokens.rField,
        color: neu.infoTint,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, size: 20, color: neu.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Versão ${data.update.version} disponível.',
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _adiado = true),
              child: const Text('Depois'),
            ),
            const SizedBox(width: 4),
            NeuButton(
              label: 'Atualizar',
              icon: Icons.download_rounded,
              onPressed: () => showUpdateDialog(context, data.update),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tela cheia que substitui o app quando a versão instalada é velha demais
/// para o servidor atual. Sem "depois": seguir usando daria erro a cada ação.
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({super.key, required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Scaffold(
      backgroundColor: neu.base,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_alt_rounded,
                    size: 56, color: neu.accent),
                const SizedBox(height: 18),
                Text(
                  'Atualize para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta versão do aplicativo não é mais compatível com o '
                  'sistema. A atualização leva menos de um minuto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
                const SizedBox(height: 22),
                NeuButton(
                  label: 'Atualizar agora',
                  icon: Icons.download_rounded,
                  onPressed: () => showUpdateDialog(context, update),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo que baixa, confere o arquivo e abre a instalação.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: 'Atualizar o OrbixHub',
      maxWidth: 420,
      child: _UpdateProgressBody(update: update),
    ),
  );
}

class _UpdateProgressBody extends ConsumerStatefulWidget {
  const _UpdateProgressBody({required this.update});

  final AppUpdate update;

  @override
  ConsumerState<_UpdateProgressBody> createState() => _UpdateProgressBodyState();
}

class _UpdateProgressBodyState extends ConsumerState<_UpdateProgressBody> {
  double? _progress;
  bool _running = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = 0;
    });
    try {
      await ref.read(updateInstallerProvider).downloadAndInstall(
            url: widget.update.url!,
            platform: widget.update.platform ?? updatePlatform() ?? 'android',
            version: widget.update.version!,
            expectedSha256: widget.update.sha256,
            onProgress: (f) {
              if (mounted) setState(() => _progress = f);
            },
          );
      // Android: o sistema assume daqui (tela de instalação). Windows não
      // chega aqui — o app é encerrado para o instalador substituir os arquivos.
      if (mounted) Navigator.of(context).maybePop();
    } on UpdateFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _running = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Falha ao atualizar: $e';
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final u = widget.update;
    final mb = u.sizeBytes == null
        ? null
        : (u.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Versão ${u.version}${mb == null ? '' : ' · $mb MB'}',
          style: TextStyle(
            color: neu.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if ((u.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            u.notes!.trim(),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neu.inkMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        if (_running) ...[
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text(
            _progress == null
                ? 'Baixando…'
                : 'Baixando… ${(_progress! * 100).round()}%',
            style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
          ),
        ] else
          NeuButton(
            label: 'Baixar e instalar',
            icon: Icons.download_rounded,
            onPressed: _start,
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: neu.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
