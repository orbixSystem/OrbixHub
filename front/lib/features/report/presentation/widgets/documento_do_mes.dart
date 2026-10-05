import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../domain/monthly_models.dart';
import 'motion.dart';

/// O mês como DOCUMENTO, não como cartão de dashboard.
///
/// Quem lê isto passou o mês com a mão no motor e senta uma vez para descobrir
/// se o trabalho virou dinheiro. O que serve a essa pessoa é uma página escrita
/// — uma frase que abre, o parágrafo que a sustenta, e no fim a assinatura de
/// quem escreveu. Um cartão com tarja em caixa alta no topo seria mais um
/// bloco de interface; aqui o conteúdo é o próprio objeto.
///
/// A medida da prosa é limitada a ~68 caracteres. Texto de relatório correndo
/// a largura inteira de um monitor não é lido, é escaneado — e este é
/// justamente o pedaço que precisa ser lido.
class DocumentoDoMes extends StatelessWidget {
  const DocumentoDoMes({super.key, required this.resumo});

  final ResumoMensal resumo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final n = resumo.narrativa;
    final texto = Theme.of(context).textTheme;

    return NeuCard(
      padding: EdgeInsets.fromLTRB(
        context.isMobile ? 20 : 30,
        context.isMobile ? 24 : 30,
        context.isMobile ? 20 : 30,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resumo.periodo.rotulo.replaceFirst('/', ' de '),
            style: TextStyle(
              color: neu.inkFaint,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // A frase do mês, em Sora e em corpo de manchete. É o único lugar da
          // tela com esse peso: a ousadia inteira do módulo está gasta aqui.
          SurgeSuave(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                n.titulo,
                style: texto.displaySmall!.copyWith(
                  color: neu.ink,
                  fontSize: context.isMobile ? 25 : 31,
                  height: 1.18,
                  letterSpacing: -0.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FioQueDesenha(cor: neu.line),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              n.leitura,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 15.5,
                height: 1.68,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Sem a data: ela já está na faixa do topo, que é onde a pergunta
          // "isto ainda vale?" é feita. O que fica aqui é a explicação —
          // quem escreveu e de onde vieram os valores.
          AssinaturaDoResumo(resumo: resumo, comData: false),
        ],
      ),
    );
  }
}

/// As ações do mês que começa.
///
/// Ficam no documento (e não numa caixa à parte) porque são a conclusão do
/// texto — é para elas que a leitura caminha. Numeradas, porque aqui a ordem
/// é real: a primeira é a que o sinal mais grave pediu.
class ParaEsteMes extends StatelessWidget {
  const ParaEsteMes({super.key, required this.itens});

  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sem título próprio: quem monta esta lista é uma seção que já se
          // apresenta. Dois "Para este mês" seguidos são ruído que o olho
          // precisa descartar antes de chegar à primeira ação.
          for (var i = 0; i < itens.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == itens.length - 1 ? 0 : 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        color: neu.accent,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: kTabular,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      itens[i],
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A assinatura, no pé da página.
///
/// Um documento diz quem o escreveu e quando — e é mais honesto no fim, depois
/// da leitura, do que num selo no topo disputando atenção com a manchete.
/// Quando o texto foi montado pelo sistema, ele assina como tal: creditar à IA
/// um texto que ela não escreveu é mentir sobre o produto.
class AssinaturaDoResumo extends StatelessWidget {
  const AssinaturaDoResumo({
    super.key,
    required this.resumo,
    this.comData = true,
  });

  final ResumoMensal resumo;

  /// Repetir a data quando ela já está em outro lugar da mesma página é pedir
  /// ao leitor que confira se as duas batem.
  final bool comData;

  static const _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  String get _quando {
    final d = DateTime.tryParse(resumo.generatedAt)?.toLocal();
    if (d == null) return '';
    final dia = d.day == 1 ? '1º' : '${d.day}';
    final hora =
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    return 'em $dia de ${_meses[d.month - 1]}, às $hora';
  }

  /// "há 2 horas", "há 3 dias" — a data absoluta diz QUANDO, esta diz se o
  /// texto ainda vale. Quem abre o relatório no dia 12 precisa saber que ele
  /// foi escrito no dia 1º sem ter de fazer a conta.
  static String tempoDecorrido(String iso, {DateTime? agora}) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diferenca = (agora ?? DateTime.now()).difference(d);
    if (diferenca.isNegative) return 'agora';
    final minutos = diferenca.inMinutes;
    if (minutos < 1) return 'agora';
    if (minutos < 60) return 'há $minutos min';
    final horas = diferenca.inHours;
    if (horas < 24) return 'há $horas ${horas == 1 ? 'hora' : 'horas'}';
    final dias = diferenca.inDays;
    if (dias < 30) return 'há $dias ${dias == 1 ? 'dia' : 'dias'}';
    final meses = dias ~/ 30;
    return 'há $meses ${meses == 1 ? 'mês' : 'meses'}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ia = resumo.escritoPorIa;
    final quando = comData ? _quando : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 8),
          child: Icon(
            ia ? Icons.auto_awesome_rounded : Icons.calculate_outlined,
            size: 14,
            color: neu.inkFaint,
          ),
        ),
        Expanded(
          child: Text(
            ia
                ? 'Escrito por inteligência artificial sobre os números '
                    'apurados pelo sistema${quando.isEmpty ? '' : ', $quando'}. '
                    'Nenhum valor vem do modelo.'
                : 'Escrito pelo próprio sistema a partir dos números do '
                    'mês${quando.isEmpty ? '' : ', $quando'}.',
            style: TextStyle(
              color: neu.inkFaint,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

/// O lugar do documento enquanto o mês não fechou.
///
/// Não é erro nem vazio: é o estado normal de um mês em andamento. Dizer isso
/// com todas as letras evita a leitura óbvia e errada — "a IA não funcionou" —
/// e aproveita para explicar quando o texto chega, que é informação que o dono
/// ainda não tem.
class DocumentoAindaNaoEscrito extends StatelessWidget {
  const DocumentoAindaNaoEscrito({
    super.key,
    required this.rotuloDoMes,
    required this.mesCorrente,
  });

  final String rotuloDoMes;

  /// O mês analisado é o que está correndo agora?
  ///
  /// Muda o que a ausência SIGNIFICA: no mês corrente o texto ainda não existe
  /// porque o mês não fechou; num mês passado ele não existe porque ninguém o
  /// gerou. Dizer "o mês ainda está em andamento" sobre setembro em outubro é
  /// falso, e quem lê para de confiar no resto da página.
  final bool mesCorrente;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotuloDoMes.replaceFirst('/', ' de '),
            style: TextStyle(
              color: neu.inkFaint,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              mesCorrente
                  ? 'O mês ainda está em andamento'
                  : 'Este mês não teve leitura escrita',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    color: neu.ink,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          FioQueDesenha(cor: neu.line),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              mesCorrente
                  ? 'A leitura escrita chega no primeiro dia do próximo mês, '
                      'com o mês fechado, e você recebe um aviso. Os números '
                      'abaixo já são de agora.'
                  : 'O texto é escrito uma vez, nos primeiros dias do mês '
                      'seguinte. Os números deste mês estão todos abaixo.',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
