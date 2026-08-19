import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Seletor de MÊS/ANO das despesas. Devolve o mês escolhido (dia 1) ou `null`.
///
/// Existe porque a navegação era só `‹ Agosto 2026 ›`: chegar em dezembro do ano
/// passado custava treze toques, e não havia como saber onde se estava sem ler o
/// rótulo a cada clique. Aqui o ano inteiro aparece de uma vez.
///
/// Não usa o `showDatePicker` do Material de propósito: ele pede um DIA (e o
/// recorte da tela é o MÊS), abre no calendário do mês e destoa do resto da tela.
Future<DateTime?> showMonthPickerDialog(
  BuildContext context, {
  required DateTime inicial,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(inicial: inicial),
    );

/// Nomes curtos: o grid tem 3 ou 4 colunas, e "Setembro" por extenso obrigaria
/// a diminuir a fonte a ponto de atrapalhar quem tem vista cansada.
const _mesesCurtos = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

const _mesesLongos = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.inicial});

  final DateTime inicial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  /// Ano em exibição no grid — muda com as setas SEM escolher nada. Separar
  /// "navegar" de "escolher" é o que permite olhar 2025 e desistir.
  late int _ano = widget.inicial.year;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hoje = DateTime.now();
    final compacto = context.isMobile;

    return NeuDialog(
      title: 'Escolher mês',
      // Estreito de propósito: são 12 alvos curtos, e um diálogo largo espalharia
      // o grid a ponto de exigir mover o olho (e o dedo) de ponta a ponta.
      maxWidth: compacto ? 360 : 420,
      actions: [
        // Atalho para "hoje": é o destino mais pedido, e chegar nele pelo grid
        // exigiria saber em que ano se está.
        NeuButton(
          label: 'Mês atual',
          kind: NeuButtonKind.secondary,
          icon: Icons.today_outlined,
          onPressed: () =>
              Navigator.pop(context, DateTime(hoje.year, hoje.month)),
        ),
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavegadorDeAno(
            ano: _ano,
            onAnterior: () => setState(() => _ano--),
            onProximo: () => setState(() => _ano++),
          ),
          const SizedBox(height: 14),
          // LayoutBuilder e não largura fixa: o mesmo grid serve o diálogo de
          // 420px no desktop e o de 360px (menos as margens) num celular
          // estreito, sem “Dez” caindo sozinho numa linha.
          LayoutBuilder(
            builder: (context, c) {
              const espaco = 8.0;
              final colunas = compacto ? 3 : 4;
              final largura =
                  (c.maxWidth - espaco * (colunas - 1)) / colunas;
              return Wrap(
                spacing: espaco,
                runSpacing: espaco,
                children: [
                  for (var m = 1; m <= 12; m++)
                    SizedBox(
                      width: largura,
                      child: _BotaoMes(
                        curto: _mesesCurtos[m - 1],
                        longo: _mesesLongos[m - 1],
                        selecionado: _ano == widget.inicial.year &&
                            m == widget.inicial.month,
                        // "Hoje" marcado mesmo quando não é o escolhido: é a
                        // referência que diz se você está olhando passado ou
                        // futuro.
                        ehHoje: _ano == hoje.year && m == hoje.month,
                        onTap: () => Navigator.pop(context, DateTime(_ano, m)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'As contas vencidas e não pagas continuam aparecendo nos meses '
            'seguintes.',
            style: TextStyle(color: neu.inkFaint, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// `‹ 2026 ›` — navega o ano sem escolher mês.
class _NavegadorDeAno extends StatelessWidget {
  const _NavegadorDeAno({
    required this.ano,
    required this.onAnterior,
    required this.onProximo,
  });

  final int ano;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NeuIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Ano anterior',
          size: 40,
          onPressed: onAnterior,
        ),
        // Largura fixa para as setas não dançarem — mesmo cuidado do cabeçalho.
        SizedBox(
          width: 96,
          child: Text(
            '$ano',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neu.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        NeuIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Próximo ano',
          size: 40,
          onPressed: onProximo,
        ),
      ],
    );
  }
}

class _BotaoMes extends StatelessWidget {
  const _BotaoMes({
    required this.curto,
    required this.longo,
    required this.selecionado,
    required this.ehHoje,
    required this.onTap,
  });

  final String curto;
  final String longo;
  final bool selecionado;
  final bool ehHoje;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Tooltip(
      message: longo,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        child: NeuSurface(
          // Cavado quando é o mês em foco: é o mesmo vocabulário de "selecionado"
          // que os chips de filtro e o seletor de tipo já usam na tela.
          elevation: selecionado ? NeuElevation.inset : NeuElevation.raised,
          radius: NeuTokens.rField,
          // 44 de altura: alvo de toque confortável no polegar, que é como esta
          // tela é usada no balcão.
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                curto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selecionado ? neu.accent : neu.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // Ponto discreto marcando o mês corrente. Um segundo sinal além da
              // cor, para quem não distingue bem tons.
              SizedBox(
                height: 6,
                child: ehHoje
                    ? Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: neu.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
