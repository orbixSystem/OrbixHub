import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Vitrine DEV do design system neumórfico (`/dev/ui`, gated por kDevTools).
/// Mostra todos os componentes com estados — referência viva durante a
/// migração tela-a-tela e teste rápido de contraste claro/escuro.
class UiShowcaseScreen extends StatefulWidget {
  const UiShowcaseScreen({super.key});

  @override
  State<UiShowcaseScreen> createState() => _UiShowcaseScreenState();
}

class _UiShowcaseScreenState extends State<UiShowcaseScreen> {
  int _page = 3;
  String _segment = 'todas';

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Scaffold(
      backgroundColor: neu.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                NeuIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 16),
                Text(
                  'Design System — Showcase',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${context.screenSize.name} · ${MediaQuery.sizeOf(context).width.round()}px',
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _section('Botões'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                NeuButton(
                  label: 'Ação principal',
                  icon: Icons.add_rounded,
                  onPressed: () {},
                ),
                NeuButton(
                  label: 'Secundário',
                  kind: NeuButtonKind.secondary,
                  onPressed: () {},
                ),
                NeuButton(
                  label: 'Excluir',
                  kind: NeuButtonKind.danger,
                  icon: Icons.delete_outline_rounded,
                  onPressed: () {},
                ),
                const NeuButton(label: 'Desabilitado'),
                NeuButton(label: 'Carregando', loading: true, onPressed: () {}),
                NeuIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filtros',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
            _section('Glyphs & chips'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, icon) in const [
                  Icons.build_rounded,
                  Icons.group_rounded,
                  Icons.inventory_2_rounded,
                  Icons.receipt_long_rounded,
                  Icons.bar_chart_rounded,
                  Icons.chat_bubble_rounded,
                ].indexed)
                  NeuIconChip.glyph(context, icon: icon, index: i),
                NeuStatusChip(
                  label: 'Em execução',
                  color: neu.info,
                  tint: neu.infoTint,
                  icon: Icons.play_arrow_rounded,
                ),
                NeuStatusChip(
                  label: 'Concluída',
                  color: neu.success,
                  tint: neu.successTint,
                  icon: Icons.check_rounded,
                ),
                NeuStatusChip(
                  label: 'Cancelada',
                  color: neu.danger,
                  tint: neu.dangerTint,
                ),
                const NeuBadge(count: 3),
                const NeuBadge(count: 120),
              ],
            ),
            const SizedBox(height: 28),
            _section('Campos'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NeuSearchBar(hint: 'Buscar cliente, placa, OS…'),
                  const SizedBox(height: 14),
                  const NeuTextField(
                    label: 'Nome do cliente',
                    hint: 'Ex.: João da Silva',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  const NeuTextField(
                    label: 'E-mail',
                    hint: 'voce@oficina.com',
                    errorText: 'E-mail inválido',
                    prefixIcon: Icons.mail_outline_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _section('Segmentado'),
            Align(
              alignment: Alignment.centerLeft,
              child: NeuSegmented<String>(
                segments: const {
                  'todas': 'Todas',
                  'abertas': 'Abertas',
                  'concluidas': 'Concluídas',
                },
                selected: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            const SizedBox(height: 28),
            _section('Lista + paginação'),
            for (var i = 0; i < 3; i++) ...[
              NeuListTile(
                leading: NeuIconChip.glyph(
                  context,
                  icon: Icons.directions_car_rounded,
                  index: i,
                ),
                title: Text('OS-000${i + 1} · VW Gol 1.0'),
                subtitle: const Text('João da Silva · aberta há 2 dias'),
                trailing: NeuStatusChip(
                  label: 'Em execução',
                  color: neu.info,
                  tint: neu.infoTint,
                ),
                onTap: () {},
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            NeuPageControls(
              page: _page,
              pageSize: 20,
              total: 187,
              onPage: (p) => setState(() => _page = p),
            ),
            const SizedBox(height: 12),
            const NeuListFooter(loading: false, hasMore: false, total: 187),
            const SizedBox(height: 28),
            _section('Painel navy + cards'),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 320,
                  child: NeuPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Faturamento do mês',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          r'R$ 12.480,00',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '+18% vs. mês anterior',
                          style: TextStyle(
                            color: neu.success,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: NeuCard(
                    onTap: () {},
                    child: Row(
                      children: [
                        NeuIconChip.glyph(
                          context,
                          icon: Icons.build_rounded,
                          index: 1,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OS abertas',
                                style: TextStyle(
                                  color: neu.inkMuted,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '12',
                                style: TextStyle(
                                  color: neu.ink,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _section('Estado vazio + dialog'),
            NeuCard(
              child: NeuEmptyState(
                icon: Icons.group_outlined,
                title: 'Nenhum cliente ainda',
                message:
                    'Cadastre seu primeiro cliente para começar a criar ordens de serviço.',
                actionLabel: 'Cadastrar cliente',
                onAction: () => showNeuDialog(
                  context,
                  dialog: NeuDialog(
                    title: 'Novo cliente',
                    actions: [
                      NeuButton(
                        label: 'Cancelar',
                        kind: NeuButtonKind.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      NeuButton(label: 'Salvar', onPressed: () {}),
                    ],
                    child: const Column(
                      children: [
                        NeuTextField(label: 'Nome', hint: 'Ex.: João da Silva'),
                        SizedBox(height: 12),
                        NeuTextField(label: 'Telefone', hint: '(11) 99999-0000'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: neu.inkFaint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
