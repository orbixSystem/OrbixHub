import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ox_badge.dart';
import '../../../core/widgets/ox_button.dart';
import '../../../core/widgets/ox_card.dart';
import '../../os/presentation/os_status.dart';

/// Vitrine do design system OrbixHub.
/// Acessível em /design (debug only). Serve para validar tokens, componentes
/// e estados antes de usar nas telas reais.
class DesignSystemScreen extends StatefulWidget {
  const DesignSystemScreen({super.key});

  @override
  State<DesignSystemScreen> createState() => _DesignSystemScreenState();
}

class _DesignSystemScreenState extends State<DesignSystemScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('OrbixHub — Design System'),
          const SizedBox(height: 4),
          Text(
            'Tokens, componentes e estados.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // ── Paleta ──────────────────────────────────────────────────────
          _section('Paleta de cores'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _swatch('brand', AppColors.brand),
              _swatch('brandBright', AppColors.brandBright),
              _swatch('brandDeep', AppColors.brandDeep),
              _swatch('brandTint', AppColors.brandTint, dark: false),
              _swatch('graphite', AppColors.graphite),
              _swatch('graphiteHi', AppColors.graphiteHi),
              _swatch('graphiteLine', AppColors.graphiteLine),
              _swatch('canvas', AppColors.canvas, dark: false),
              _swatch('surface', AppColors.surface, dark: false),
              _swatch('surfaceSunken', AppColors.surfaceSunken, dark: false),
              _swatch('line', AppColors.line, dark: false),
              _swatch('ink', AppColors.ink),
              _swatch('inkMuted', AppColors.inkMuted),
              _swatch('inkFaint', AppColors.inkFaint, dark: false),
              _swatch('success', AppColors.success),
              _swatch('successTint', AppColors.successTint, dark: false),
              _swatch('danger', AppColors.danger),
              _swatch('dangerTint', AppColors.dangerTint, dark: false),
              _swatch('warning', AppColors.warning),
              _swatch('warningTint', AppColors.warningTint, dark: false),
              _swatch('info', AppColors.info),
            ],
          ),
          const SizedBox(height: 32),

          // ── Tipografia ───────────────────────────────────────────────────
          _section('Tipografia'),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display — Sora 34 Bold',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Headline M — Sora 28 Bold',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Headline S — Sora 23 Bold',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Title L — Sora 19 SemiBold',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Title M — Manrope 15 Bold',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Body M — Manrope 14',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('Body S — Manrope 12',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  'Label — Manrope 14 Bold tracking 0.2',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Botões ───────────────────────────────────────────────────────
          _section('OxButton'),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Primário'),
                const SizedBox(height: 8),
                OxButton(label: 'Salvar OS', onPressed: () {}),
                const SizedBox(height: 12),
                _label('Primário com ícone'),
                const SizedBox(height: 8),
                OxButton(
                  label: 'Nova OS',
                  onPressed: () {},
                  icon: Icons.add,
                ),
                const SizedBox(height: 12),
                _label('Loading'),
                const SizedBox(height: 8),
                OxButton(
                  label: 'Salvando…',
                  onPressed: null,
                  loading: true,
                ),
                const SizedBox(height: 12),
                _label('Desabilitado'),
                const SizedBox(height: 8),
                OxButton(label: 'Salvar', onPressed: null),
                const SizedBox(height: 12),
                _label('Secundário'),
                const SizedBox(height: 8),
                OxButton(
                  label: 'Cancelar',
                  onPressed: () {},
                  variant: OxButtonVariant.secondary,
                ),
                const SizedBox(height: 12),
                _label('Loading simulado (tap para testar)'),
                const SizedBox(height: 8),
                OxButton(
                  label: _loading ? 'Processando…' : 'Tap para simular loading',
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await Future.delayed(const Duration(seconds: 2));
                          if (mounted) setState(() => _loading = false);
                        },
                  loading: _loading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Badges / Status ──────────────────────────────────────────────
          _section('OxBadge — Status de OS'),
          OxCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: osStatuses
                  .map((s) => OsStatusChip(status: s))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _section('OxBadge — Genérico'),
          OxCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                OxBadge(label: 'Ativo', color: AppColors.success, background: AppColors.successTint),
                OxBadge(label: 'Inativo', color: AppColors.inkMuted, background: AppColors.surfaceSunken),
                OxBadge(label: 'Pendente', color: AppColors.warning, background: AppColors.warningTint),
                OxBadge(label: 'Erro', color: AppColors.danger, background: AppColors.dangerTint),
                OxBadge(label: 'Info', color: AppColors.info, background: AppColors.infoTint),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Cards ────────────────────────────────────────────────────────
          _section('OxCard'),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card estático',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Borda fina + duas sombras (1px nítida + 12px difusa). '
                  'Pousa no canvas sem usar elevation.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OxCard(
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Card tapped!'))),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.touch_app, color: AppColors.brand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Card clicável',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Ripple + InkWell sobre o background.',
                          style: TextStyle(
                              color: AppColors.inkMuted, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkFaint),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Inputs ───────────────────────────────────────────────────────
          _section('Inputs'),
          OxCard(
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Campo padrão'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: 'Com valor preenchido',
                  decoration: const InputDecoration(labelText: 'Preenchido'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Com ícone e hint',
                    hintText: 'ex.: buscar cliente',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Com erro',
                    errorText: 'Campo obrigatório',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Ícone de status (KPI card demo) ─────────────────────────────
          _section('Metric Card (atualizado)'),
          Row(
            children: [
              Expanded(
                child: OxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brandTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.build_outlined,
                                color: AppColors.brand, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('OS abertas',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('12',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: AppColors.brand)),
                      Text('esta semana',
                          style: TextStyle(
                              color: AppColors.inkMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.successTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('Concluídas',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('8',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: AppColors.success)),
                      Text('esta semana',
                          style: TextStyle(
                              color: AppColors.inkMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _heading(String text) => Text(
        text,
        style: Theme.of(context).textTheme.headlineSmall,
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkFaint,
                letterSpacing: 0.8,
              ).copyWith(
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(height: 1)),
          ],
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkFaint,
          letterSpacing: 0.4,
        ),
      );

  Widget _swatch(String name, Color color, {bool dark = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.line),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(
            name,
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
