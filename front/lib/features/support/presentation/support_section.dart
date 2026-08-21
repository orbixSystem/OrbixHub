import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../domain/support_models.dart';

/// Conversa do ambiente com o suporte da Orbix.
///
/// Deliberadamente sóbria: uma lista e um campo. Não é chat em tempo real nem
/// central de ajuda — é o caminho mais curto entre "estou com um problema" e
/// alguém do outro lado saber disso.
class SupportSection extends ConsumerStatefulWidget {
  const SupportSection({super.key});

  @override
  ConsumerState<SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends ConsumerState<SupportSection> {
  final _campo = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(supportRepositoryProvider).enviar(texto);
      _campo.clear();
      // Invalida a thread para a mensagem recém-enviada aparecer.
      ref.invalidate(supportThreadProvider);
      if (mounted) {
        showNeuSuccessOn(
          ScaffoldMessenger.of(context),
          'Mensagem enviada. Respondemos por aqui e pelo seu e-mail.',
        );
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final async = ref.watch(supportThreadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva para a equipe da Orbix. Respondemos por aqui e pelo e-mail '
          'cadastrado da empresa.',
          style: TextStyle(color: neu.inkMuted, height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: 16),

        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => NeuEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Não foi possível carregar',
            message: e is AppException ? e.message : 'Tente de novo em instantes.',
          ),
          data: (msgs) => msgs.isEmpty
              ? NeuEmptyState(
                  icon: Icons.support_agent_outlined,
                  title: 'Nenhuma conversa ainda',
                  message: 'Conte o que está acontecendo — quanto mais '
                      'específico, mais rápido a gente resolve.',
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: msgs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _Balao(msg: msgs[i]),
                  ),
                ),
        ),

        const SizedBox(height: 16),
        if (_erro != null) ...[
          Text(_erro!, style: TextStyle(color: neu.danger, fontSize: 13)),
          const SizedBox(height: 8),
        ],
        NeuTextField(
          key: const Key('support-campo'),
          controller: _campo,
          label: 'Sua mensagem',
          hint: 'Descreva o problema ou a dúvida',
          maxLines: 4,
          maxLength: 4000,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: NeuButton(
            key: const Key('support-enviar'),
            icon: Icons.send_rounded,
            label: 'Enviar',
            loading: _enviando,
            onPressed: _enviando ? null : _enviar,
          ),
        ),
      ],
    );
  }
}

/// Balão de uma mensagem. O lado e a cor dizem quem falou — sem rótulo, que a
/// essa altura seria ruído.
class _Balao extends StatelessWidget {
  const _Balao({required this.msg});

  final SupportMessage msg;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final daOrbix = msg.fromOrbix;
    return Align(
      alignment: daOrbix ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: daOrbix ? neu.surfaceHi : AppColors.brandTint,
            borderRadius: BorderRadius.circular(NeuTokens.rField),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                daOrbix ? 'Suporte Orbix' : (msg.authorName ?? 'Você'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: neu.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg.body,
                style: TextStyle(color: neu.ink, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _quando(msg.createdAt),
                style: TextStyle(fontSize: 12, color: neu.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _quando(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)} às ${dd(l.hour)}:${dd(l.minute)}';
  }
}
