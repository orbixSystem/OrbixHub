import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import 'barra_de_filtros.dart';

/// O controle de período da barra de filtros.
///
/// Um chip que abre duas coisas na mesma folha: a coluna de atalhos — "hoje",
/// "últimos 7 dias", "este mês" — e, atrás de "Personalizado", dois
/// calendários para o resto. São alternativas excludentes, e por isso moram no
/// mesmo lugar: separá-las em dois controles faria o usuário escolher um
/// período em cada um e ficar sem saber qual vale.
///
/// O atalho aplica e fecha na hora; o intervalo só vale no "Aplicar". A
/// diferença não é estética: escolher um intervalo são dois cliques, e aplicar
/// no primeiro recarregaria a página inteira com um período pela metade.
class FiltroDePeriodo extends ConsumerStatefulWidget {
  const FiltroDePeriodo({super.key});

  @override
  ConsumerState<FiltroDePeriodo> createState() => _FiltroDePeriodoState();
}

class _FiltroDePeriodoState extends ConsumerState<FiltroDePeriodo> {
  /// Ancoragem por `LayerLink`, e não por coordenadas calculadas.
  ///
  /// Converter a posição do chip para a do overlay parecia simples e estava
  /// errado: o shell tem o próprio Navigator, o diálogo abre no da raiz, e a
  /// folha aparecia deslocada pela largura exata da barra lateral — sobre o
  /// menu, longe do que foi tocado. O link liga os dois pontos sem aritmética
  /// e ainda acompanha a rolagem.
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final periodo = ref.watch(periodoSelecionadoProvider);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (_) => _Folha(
          link: _link,
          atual: periodo,
          // O personalizado abre semeado com o período que já está valendo:
          // um calendário sem nenhuma data escolhida ainda assim DESTACA um
          // dia (é como o widget funciona), e o usuário via o dia 4 marcado
          // ao lado de "escolha as duas datas".
          vigente: periodo.intervalo(),
          aoFechar: _portal.hide,
          aoEscolher: (escolha) {
            final n = ref.read(periodoSelecionadoProvider.notifier);
            if (escolha.ehPersonalizado) {
              n.usarIntervalo(escolha.de!, escolha.ate!);
            } else {
              n.usarPreset(escolha.preset);
            }
            _portal.hide();
          },
        ),
        child: ChipDeFiltro(
          // O período SEMPRE tem valor — não existe relatório sem "quando" —,
          // e por isso o chip aparece sempre aceso e sem o X de limpar.
          ativo: true,
          icone: Icons.calendar_month_rounded,
          texto: rotuloDoPeriodo(periodo),
          larguraMinima: 170,
          aoTocar: _portal.toggle,
        ),
      ),
    );
  }
}

/// Como o período se chama no chip e em qualquer lugar que precise dizê-lo.
String rotuloDoPeriodo(PeriodoDoRelatorio p) {
  if (p.ehPersonalizado) {
    return '${_dia(p.de!)} – ${_dia(p.ate!)}';
  }
  return switch (p.preset) {
    PresetDePeriodo.hoje => 'Hoje',
    PresetDePeriodo.ontem => 'Ontem',
    PresetDePeriodo.ultimos7 => 'Últimos 7 dias',
    PresetDePeriodo.ultimos30 => 'Últimos 30 dias',
    PresetDePeriodo.esteMes => 'Este mês',
    PresetDePeriodo.mesPassado => 'Mês passado',
    PresetDePeriodo.esteAno => 'Este ano',
    PresetDePeriodo.personalizado => 'Personalizado',
  };
}

String _dia(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _atalhos = [
  PresetDePeriodo.hoje,
  PresetDePeriodo.ontem,
  PresetDePeriodo.ultimos7,
  PresetDePeriodo.ultimos30,
  PresetDePeriodo.esteMes,
  PresetDePeriodo.mesPassado,
  PresetDePeriodo.esteAno,
];

/// A folha que abre sob o chip.
class _Folha extends StatefulWidget {
  const _Folha({
    required this.link,
    required this.atual,
    required this.vigente,
    required this.aoEscolher,
    required this.aoFechar,
  });

  final LayerLink link;
  final PeriodoDoRelatorio atual;

  /// O intervalo que o período atual representa — a semente do personalizado.
  final ReportRange vigente;
  final ValueChanged<PeriodoDoRelatorio> aoEscolher;
  final VoidCallback aoFechar;

  @override
  State<_Folha> createState() => _FolhaState();
}

class _FolhaState extends State<_Folha> {
  late bool _personalizado = widget.atual.ehPersonalizado;
  late DateTime _de = widget.atual.de ?? _soData(widget.vigente.from);
  late DateTime _ate = widget.atual.ate ?? _soData(widget.vigente.to);

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final tela = MediaQuery.sizeOf(context);
    // Cada calendário precisa de ~300px para caber o cabeçalho "setembro de
    // 2026" junto das setas de mês. Com menos, o nome do mês some e sobram
    // duas grades de números sem dizer de quando são.
    final largura = _personalizado ? 860.0 : 232.0;

    return Stack(
      children: [
        // Tocar fora fecha. Sem esta camada, a folha só sairia da tela
        // escolhendo alguma coisa — e desistir vira uma escolha acidental.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.aoFechar,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: largura,
                  maxHeight: tela.height * 0.74,
                ),
                child: NeuCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 232,
                            child: _Atalhos(
                              personalizado: _personalizado,
                              atual: widget.atual,
                              aoEscolher: (p) => widget.aoEscolher(
                                PeriodoDoRelatorio(preset: p),
                              ),
                              aoPersonalizar: () =>
                                  setState(() => _personalizado = true),
                            ),
                          ),
                          if (_personalizado) ...[
                            Container(
                              width: 1 / MediaQuery.devicePixelRatioOf(context),
                              color: neu.line,
                            ),
                            Expanded(
                              child: _Calendarios(
                                de: _de,
                                ate: _ate,
                                aoMudar: (de, ate) => setState(() {
                                  _de = de;
                                  // O fim nunca fica antes do início: o
                                  // calendário da direita já impede, mas
                                  // mover o início para depois do fim
                                  // deixaria um intervalo invertido.
                                  _ate = ate.isBefore(de) ? de : ate;
                                }),
                                aoAplicar: () => widget.aoEscolher(
                                  PeriodoDoRelatorio(
                                    preset: PresetDePeriodo.personalizado,
                                    de: _de,
                                    ate: _ate,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Atalhos extends StatelessWidget {
  const _Atalhos({
    required this.personalizado,
    required this.atual,
    required this.aoEscolher,
    required this.aoPersonalizar,
  });

  final bool personalizado;
  final PeriodoDoRelatorio atual;
  final ValueChanged<PresetDePeriodo> aoEscolher;
  final VoidCallback aoPersonalizar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Text(
              'Período',
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final p in _atalhos)
            _Linha(
              rotulo: rotuloDoPeriodo(PeriodoDoRelatorio(preset: p)),
              marcada: !personalizado && atual.preset == p,
              aoTocar: () => aoEscolher(p),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Divider(height: 1, color: neu.line),
          ),
          _Linha(
            rotulo: 'Personalizado',
            marcada: personalizado,
            aoTocar: aoPersonalizar,
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.rotulo,
    required this.marcada,
    required this.aoTocar,
  });

  final String rotulo;
  final bool marcada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: marcada ? neu.navy.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(NeuTokens.rChip),
        ),
        child: Row(
          children: [
            Icon(
              marcada
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: marcada ? neu.navy : neu.inkFaint,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                rotulo,
                style: TextStyle(
                  color: marcada ? neu.navy : neu.ink,
                  fontSize: 13.5,
                  fontWeight: marcada ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os dois calendários do personalizado: início e fim, cada um com o próprio
/// mês.
///
/// Independentes de propósito. Num seletor de faixa único, mudar o mês de um
/// lado arrasta o outro, e escolher "15 de agosto a 3 de setembro" vira uma
/// briga com o componente.
class _Calendarios extends StatelessWidget {
  const _Calendarios({
    required this.de,
    required this.ate,
    required this.aoMudar,
    required this.aoAplicar,
  });

  final DateTime de;
  final DateTime ate;
  final void Function(DateTime de, DateTime ate) aoMudar;
  final VoidCallback aoAplicar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hoje = DateTime.now();
    final primeiro = DateTime(hoje.year - 5, 1, 1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _UmCalendario(
                  titulo: 'Início',
                  valor: de,
                  primeiro: primeiro,
                  ultimo: hoje,
                  aoEscolher: (d) => aoMudar(d, ate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _UmCalendario(
                  titulo: 'Fim',
                  valor: ate,
                  primeiro: de,
                  ultimo: hoje,
                  aoEscolher: (d) => aoMudar(de, d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_dia(de)} até ${_dia(ate)}',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
              NeuButton(label: 'Aplicar', onPressed: aoAplicar),
            ],
          ),
        ],
      ),
    );
  }
}

/// Só a data, sem hora — o calendário não entende o fim do dia.
DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

class _UmCalendario extends StatelessWidget {
  const _UmCalendario({
    required this.titulo,
    required this.valor,
    required this.primeiro,
    required this.ultimo,
    required this.aoEscolher,
  });

  final String titulo;
  final DateTime valor;
  final DateTime primeiro;
  final DateTime ultimo;
  final ValueChanged<DateTime> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: neu.inkFaint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 290,
          child: CalendarDatePicker(
            initialDate: _dentro(valor),
            firstDate: primeiro,
            lastDate: ultimo.isBefore(primeiro) ? primeiro : ultimo,
            onDateChanged: aoEscolher,
          ),
        ),
      ],
    );
  }

  /// A data inicial do calendário tem de estar DENTRO dos limites, senão o
  /// widget estoura em asserção — e isso acontece sempre que o usuário escolhe
  /// o fim antes do início.
  DateTime _dentro(DateTime d) {
    if (d.isBefore(primeiro)) return primeiro;
    if (d.isAfter(ultimo)) return ultimo.isBefore(primeiro) ? primeiro : ultimo;
    return d;
  }
}
