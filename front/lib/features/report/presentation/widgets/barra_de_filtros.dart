import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import 'motion.dart';

/// A linha de filtros das abas de Relatórios.
///
/// Uma só, compartilhada: o mesmo componente, o mesmo estado e o mesmo lugar
/// na página em todas as abas. Antes cada relatório trazia os próprios campos
/// soltos acima da tabela, e a mesma pergunta ("de que período é isto?") era
/// respondida por um controle diferente em cada aba — quando era respondida.
///
/// O formato é o de chips: o rótulo some quando há escolha e o valor ocupa o
/// lugar dele, de modo que a barra parada mostra o recorte inteiro numa linha.
/// Uma fileira de campos com rótulo fixo gasta o dobro da altura para dizer a
/// mesma coisa, e numa página que já é densa isso custa a primeira dobra.
class BarraDeFiltros extends StatelessWidget {
  const BarraDeFiltros({
    super.key,
    required this.filtros,
    required this.ativos,
    required this.aoLimpar,
  });

  /// Os chips, na ordem. Grupos são separados por [DivisorDeFiltros].
  final List<Widget> filtros;

  /// Quantos filtros estão aplicados — o badge e o "Limpar" dependem disto.
  final int ativos;

  final VoidCallback aoLimpar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 15, color: neu.navy),
              const SizedBox(width: 8),
              Text(
                'Filtros',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (ativos > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: neu.navy.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$ativos ${ativos == 1 ? 'ativo' : 'ativos'}',
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // O "Limpar" só existe quando há o que limpar: um botão
              // permanentemente inerte ensina a ignorar aquele canto da tela.
              if (ativos > 0)
                TextButton.icon(
                  onPressed: aoLimpar,
                  icon: Icon(Icons.close_rounded, size: 14, color: neu.navy),
                  label: Text(
                    'Limpar filtros',
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: filtros),
        ],
      ),
    );
  }
}

/// O fio vertical que separa grupos de filtros.
class DivisorDeFiltros extends StatelessWidget {
  const DivisorDeFiltros({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1 / MediaQuery.devicePixelRatioOf(context),
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: context.neu.line,
    );
  }
}

/// Uma opção de um filtro.
typedef OpcaoDeFiltro = ({String valor, String rotulo});

/// Chip de escolha única.
///
/// `null` significa "todos" — e é o X que devolve a esse estado. A lista NÃO
/// traz um item "Todos": ele seria indistinguível de uma escolha real na hora
/// de contar quantos filtros estão ativos.
class FiltroDeOpcao extends StatelessWidget {
  const FiltroDeOpcao({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.aoMudar,
    this.icone,
    this.larguraMinima = 0,
    this.permiteLimpar = true,
  });

  final String rotulo;
  final String? valor;
  final List<OpcaoDeFiltro> opcoes;
  final ValueChanged<String?> aoMudar;
  final IconData? icone;
  final double larguraMinima;

  /// Mostra o X de limpar.
  ///
  /// Falso para o mês: não existe relatório sem período, e um X ali ofereceria
  /// um estado "sem mês" que a tela não sabe desenhar.
  final bool permiteLimpar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final selecionado = valor == null
        ? null
        : opcoes
            .where((o) => o.valor == valor)
            .map((o) => o.rotulo)
            .firstOrNull;
    final ativo = valor != null;

    return ChipDeFiltro(
      ativo: ativo,
      larguraMinima: larguraMinima,
      icone: icone,
      texto: selecionado ?? rotulo,
      aoLimpar: ativo && permiteLimpar ? () => aoMudar(null) : null,
      aoTocar: () async {
        final escolha = await showMenu<String?>(
          context: context,
          position: _posicaoDoMenu(context),
          color: neu.surfaceHi,
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
          items: [
            for (final o in opcoes)
              PopupMenuItem<String?>(
                value: o.valor,
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.rotulo,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 13.5,
                          fontWeight: o.valor == valor
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (o.valor == valor)
                      Icon(Icons.check_rounded, size: 16, color: neu.navy),
                  ],
                ),
              ),
          ],
        );
        if (escolha != null) aoMudar(escolha);
      },
    );
  }
}

/// Chip de busca por texto.
///
/// Abre um campo em vez de um menu: a pergunta aqui é aberta ("qual peça?"),
/// e uma lista de opções não teria como oferecê-la.
class FiltroDeBusca extends StatefulWidget {
  const FiltroDeBusca({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final String? valor;
  final ValueChanged<String?> aoMudar;

  @override
  State<FiltroDeBusca> createState() => _FiltroDeBuscaState();
}

class _FiltroDeBuscaState extends State<FiltroDeBusca> {
  bool _aberto = false;
  late final TextEditingController _controle =
      TextEditingController(text: widget.valor ?? '');

  @override
  void didUpdateWidget(FiltroDeBusca old) {
    super.didUpdateWidget(old);
    // O "Limpar filtros" da barra zera o estado; o campo precisa acompanhar,
    // senão o texto continua escrito num filtro que já não vale.
    if (widget.valor != old.valor && (widget.valor ?? '') != _controle.text) {
      _controle.text = widget.valor ?? '';
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ativo = (widget.valor ?? '').isNotEmpty;

    if (!_aberto && !ativo) {
      return ChipDeFiltro(
        ativo: false,
        icone: Icons.search_rounded,
        texto: widget.rotulo,
        // Sem a seta de menu: este chip abre um campo de texto, e a seta
        // prometeria uma lista de opções que não existe.
        mostraSeta: false,
        aoTocar: () => setState(() => _aberto = true),
      );
    }

    return SizedBox(
      width: 230,
      height: 34,
      child: TextField(
        controller: _controle,
        autofocus: _aberto,
        style: TextStyle(color: neu.ink, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: neu.surfaceHi,
          hintText: widget.rotulo,
          hintStyle: TextStyle(color: neu.inkFaint, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 15, color: neu.inkFaint),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded, size: 15, color: neu.inkFaint),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () {
              _controle.clear();
              widget.aoMudar(null);
              setState(() => _aberto = false);
            },
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
            borderSide: BorderSide(color: neu.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
            borderSide: BorderSide(
              color: ativo ? neu.navy.withValues(alpha: 0.45) : neu.line,
            ),
          ),
        ),
        onSubmitted: (v) =>
            widget.aoMudar(v.trim().isEmpty ? null : v.trim()),
        onChanged: (v) => widget.aoMudar(v.trim().isEmpty ? null : v.trim()),
      ),
    );
  }
}

/// O gatilho visual de todos os filtros — um só, para que a barra pareça uma
/// barra e não uma coleção de controles que foram sendo adicionados.
class ChipDeFiltro extends StatelessWidget {
  const ChipDeFiltro({
    super.key,
    required this.ativo,
    required this.texto,
    required this.aoTocar,
    this.icone,
    this.aoLimpar,
    this.larguraMinima = 0,
    this.mostraSeta = true,
  });

  final bool ativo;
  final String texto;
  final VoidCallback aoTocar;
  final IconData? icone;
  final VoidCallback? aoLimpar;
  final double larguraMinima;
  final bool mostraSeta;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        child: Container(
          height: 34,
          constraints: BoxConstraints(minWidth: larguraMinima),
          padding: EdgeInsets.fromLTRB(12, 0, aoLimpar == null ? 10 : 4, 0),
          decoration: BoxDecoration(
            color: neu.surfaceHi,
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
            border: Border.all(
              color: ativo ? neu.navy.withValues(alpha: 0.45) : neu.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(
                  icone,
                  size: 14,
                  color: ativo ? neu.navy : neu.inkFaint,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ativo ? neu.ink : neu.inkMuted,
                    fontSize: 13,
                    fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                    fontFeatures: kTabular,
                  ),
                ),
              ),
              if (aoLimpar != null)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 14, color: neu.inkFaint),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: 'Limpar',
                  onPressed: aoLimpar,
                )
              else if (mostraSeta)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 15,
                    color: neu.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O menu abre ANCORADO no chip, não no canto da tela: um popover que aparece
/// longe do que foi tocado obriga o olho a reencontrar o contexto.
RelativeRect _posicaoDoMenu(BuildContext context) {
  final caixa = context.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (caixa == null || overlay == null) {
    return const RelativeRect.fromLTRB(0, 0, 0, 0);
  }
  final topo = caixa.localToGlobal(
    caixa.size.bottomLeft(Offset.zero),
    ancestor: overlay,
  );
  return RelativeRect.fromLTRB(
    topo.dx,
    topo.dy + 4,
    overlay.size.width - topo.dx - 260,
    0,
  );
}
