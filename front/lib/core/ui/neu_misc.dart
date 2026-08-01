import 'package:flutter/material.dart';

import 'neu_button.dart';
import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Estado vazio que ENSINA (usabilidade guiada): ícone grande, título curto,
/// explicação em linguagem simples e a próxima ação como botão primário.
class NeuEmptyState extends StatelessWidget {
  const NeuEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuSurface(
              elevation: NeuElevation.raised,
              radius: 40,
              child: SizedBox(
                width: 80,
                height: 80,
                child: Icon(icon, size: 36, color: neu.accent),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              NeuButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
    // Resiliente a altura apertada: dentro de um Expanded pequeno (ex.: extrato
    // do caixa aberto sem movimentos) o conteúdo natural é maior que o espaço e
    // estouraria. Com altura limitada, rola em vez de estourar; com espaço amplo
    // ou ilimitado (dentro de ListView/SingleChildScrollView), fica centrado.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight == double.infinity) {
          return Center(child: content);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

/// Seletor segmentado (filtros de status, abas simples): trilha cavada com o
/// segmento ativo extrudado em navy.
class NeuSegmented<T> extends StatelessWidget {
  const NeuSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in segments.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: entry.key == selected
                    ? null
                    : () => onChanged(entry.key),
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? neu.navy
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(NeuTokens.rChip),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: entry.key == selected ? neu.onNavy : neu.inkMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
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

/// Dialog padrão do design system (superfície neumórfica alta + título +
/// ações). Usar via [showNeuDialog].
class NeuDialog extends StatelessWidget {
  const NeuDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 480,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: NeuSurface(
          elevation: NeuElevation.raisedHigh,
          radius: NeuTokens.rPanel,
          color: neu.surface,
          glow: false,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  NeuIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fechar',
                    size: 38,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                // Wrap (não Row): com 3+ ações — ou no mobile, onde o diálogo é
                // estreito — os botões quebram de linha em vez de estourar.
                // Com espaço sobrando o resultado é idêntico a uma Row.
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre um [NeuDialog] com animação de surgimento/desaparecimento (fade +
/// scale suave), em vez de só "aparecer" na tela.
Future<T?> showNeuDialog<T>(BuildContext context, {required NeuDialog dialog}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => dialog,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Diálogo de CONFIRMAÇÃO padrão (design system) para ações irreversíveis —
/// deletar, cancelar OS, remover membro, etc. Ícone tint + mensagem clara +
/// botões "cancelar" (secundário) e a ação de confirmação (danger por padrão).
/// Retorna `true` só se o usuário confirmar. Usar SEMPRE antes de operações
/// sem volta:
///
/// ```dart
/// if (await showNeuConfirm(context,
///     title: 'Cancelar OS?',
///     message: 'A OS será cancelada e a edição bloqueada.',
///     confirmLabel: 'Cancelar OS')) {
///   // ...executa
/// }
/// ```
Future<bool> showNeuConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Voltar',
  bool danger = true,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final result = await showNeuDialog<bool>(
    context,
    dialog: NeuDialog(
      title: title,
      maxWidth: 420,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: cancelLabel,
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => NeuButton(
            label: confirmLabel,
            kind: danger ? NeuButtonKind.danger : NeuButtonKind.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
      child: Builder(
        builder: (ctx) {
          final neu = ctx.neu;
          final accent = danger ? neu.danger : neu.navy;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  return result ?? false;
}
