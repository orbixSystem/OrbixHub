import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// Casca padrão de um widget de métrica: cartão neumórfico com cabeçalho
/// (glyph colorido + título) e corpo. A largura é fluida — o grid adaptativo
/// do dashboard decide as colunas.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = accent ?? neu.accent;
    return NeuCard(
      padding: const EdgeInsets.all(20),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: neu.ink),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Corpo de carregamento (spinner centralizado, altura estável).
class MetricLoading extends StatelessWidget {
  const MetricLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

/// Corpo de erro com botão "Tentar novamente".
class MetricError extends StatelessWidget {
  const MetricError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: neu.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Não foi possível carregar.',
                  style: TextStyle(color: neu.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

/// Corpo vazio (sem dados no período).
class MetricEmpty extends StatelessWidget {
  const MetricEmpty({super.key, this.message = 'Sem dados no período.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(message, style: TextStyle(color: neu.inkMuted)),
      ),
    );
  }
}

/// Par rótulo→valor empilhado (KPI compacto).
class MetricStat extends StatelessWidget {
  const MetricStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: valueColor ?? neu.ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
      ],
    );
  }
}

/// Formata um valor monetário (num) em "R$ 1.625,02".
String formatMoney(num value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return 'R\$ $buf,$decPart';
}

/// Formata uma quantidade numérica para exibição, removendo o `.0` quando for
/// inteira (ex.: `5.0` → "5", `2.5` → "2,5"). Null → "—".
String formatQty(num? value) {
  if (value == null) return '—';
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString().replaceAll('.', ',');
}

/// Formata uma duração (ms) como "Xh" ou "Xd" (legível para tempo de ciclo).
/// Null → "—".
String formatCycle(num? ms) {
  if (ms == null) return '—';
  final hours = ms / (1000 * 60 * 60);
  if (hours < 24) return '${hours.toStringAsFixed(hours < 10 ? 1 : 0)}h';
  final days = hours / 24;
  return '${days.toStringAsFixed(days < 10 ? 1 : 0)}d';
}
