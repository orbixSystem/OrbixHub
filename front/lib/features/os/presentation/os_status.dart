import 'package:flutter/material.dart';

/// Os 7 status da OS, em ordem de fluxo.
const osStatuses = <String>[
  'aberta',
  'aguardando_aprovacao',
  'aprovada',
  'em_execucao',
  'concluida',
  'entregue',
  'cancelada',
];

/// Rótulo PT-BR por status.
String osStatusLabel(String status) {
  switch (status) {
    case 'aberta':
      return 'Aberta';
    case 'aguardando_aprovacao':
      return 'Aguardando aprovação';
    case 'aprovada':
      return 'Aprovada';
    case 'em_execucao':
      return 'Em execução';
    case 'concluida':
      return 'Concluída';
    case 'entregue':
      return 'Entregue';
    case 'cancelada':
      return 'Cancelada';
    default:
      return status;
  }
}

/// Cor **gráfica** do status: fatia da rosca, faixa do card, fundo em tint,
/// ícone sobre esse tint. É elemento NÃO textual — o padrão SysOne pede 3:1,
/// que estas cores cumprem.
///
/// **Não use como cor de texto.** Uma mesma cor não consegue servir de rótulo
/// legível sobre canvas claro *e* escuro: o verde #10B981 dá 2,5:1 com branco
/// e o âmbar #D9A13B dá 2,3:1. Para texto use [osStatusInk] /
/// [osSimpleStatusInk], que devolvem a variante do matiz com 4,5:1 no tema
/// pedido.
Color osStatusColor(String status) {
  switch (status) {
    case 'em_execucao':
      return const Color(0xFF8B5CF6); // violeta — trabalho acontecendo
    case 'aprovada':
      return const Color(0xFF5B8DEF); // azul
    case 'concluida':
      return const Color(0xFF10B981); // verde
    case 'entregue':
      return const Color(0xFF64748B); // slate — arquivada
    case 'cancelada':
      return const Color(0xFFE5484D); // vermelho
    case 'aguardando_aprovacao':
      return const Color(0xFFD9A13B); // âmbar
    case 'aberta':
    default:
      return const Color(0xFF8B90B8); // lavanda neutra
  }
}

/// O mesmo matiz de [osStatusColor], mas na luminância que dá **4,5:1 de
/// contraste com o canvas** do tema pedido (piso do padrão SysOne para texto).
///
/// No claro a variante é escura o bastante para também servir de **fundo sólido
/// sob texto branco** (≥ 5,8:1) — daí os chips sólidos usarem a versão clara em
/// ambos os temas.
Color osStatusInk(String status, Brightness brightness) {
  final claro = brightness == Brightness.light;
  switch (status) {
    case 'em_execucao':
      return claro ? const Color(0xFF7238F4) : const Color(0xFFBA9EFA);
    case 'aprovada':
      return claro ? const Color(0xFF165AE0) : const Color(0xFF89ADF3);
    case 'concluida':
      return claro ? const Color(0xFF0A7350) : const Color(0xFF11C589);
    case 'entregue':
      return claro ? const Color(0xFF58667A) : const Color(0xFFA3AEBD);
    case 'cancelada':
      return claro ? const Color(0xFFC61C22) : const Color(0xFFF09496);
    case 'aguardando_aprovacao':
      return claro ? const Color(0xFF835E19) : const Color(0xFFDAA441);
    case 'aberta':
    default:
      return claro ? const Color(0xFF5B6194) : const Color(0xFFA7ABC9);
  }
}

/// FSM no front (espelha o backend): transições válidas a partir de cada status.
/// O backend é a verdade — isto só desenha os botões plausíveis.
const Map<String, List<String>> osTransitions = {
  'aberta': ['aguardando_aprovacao', 'em_execucao', 'cancelada'],
  'aguardando_aprovacao': ['aprovada', 'aberta', 'cancelada'],
  'aprovada': ['em_execucao', 'cancelada'],
  'em_execucao': ['concluida', 'cancelada'],
  'concluida': ['entregue'],
  'entregue': <String>[],
  // Cancelada só sai por "reabertura" (→ aberta) — privilegiada (os.approve).
  'cancelada': ['aberta'],
};

/// Estados terminais (espelha o backend): a OS não aceita edição de conteúdo
/// (itens, fotos, notas, cabeçalho). `cancelada` volta a ser editável reabrindo-a;
/// `entregue` é final. O backend é a verdade — isto só desabilita os controles.
bool osIsTerminal(String status) =>
    status == 'cancelada' || status == 'entregue';

/// Chip de status em estilo tint (fundo suave + texto na cor) — mais leve que
/// o bloco sólido e legível nos dois temas.
class OsStatusChip extends StatelessWidget {
  const OsStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = osStatusColor(status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        osStatusLabel(status),
        style: TextStyle(
          // No escuro, clareia o texto para manter contraste sobre o tint.
          color: dark ? Color.lerp(color, Colors.white, .35) : color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Os 7 estados internos continuam existindo (FSM, aprovação, baixa de
/// estoque, tracking) — isto só resume para a INTERFACE. "Quanto mais simples
/// melhor", pedido do dono: o seletor de status vira 3 botões, não 7.
enum OsSimpleStatus { emAndamento, finalizada, cancelada }

/// Resume um dos 7 estados reais no rótulo simplificado.
///
/// `concluida` e `entregue` caem nos DOIS em "Finalizada" — é a mesma dupla que
/// os relatórios já tratam como faturamento (nenhum lugar fora do módulo OS
/// distingue as duas). Tudo que não é `cancelada` nem essa dupla é "Em
/// andamento": `aberta`, `aguardando_aprovacao`, `aprovada`, `em_execucao`.
OsSimpleStatus osSimpleStatusOf(String status) {
  if (status == 'cancelada') return OsSimpleStatus.cancelada;
  if (status == 'concluida' || status == 'entregue') {
    return OsSimpleStatus.finalizada;
  }
  return OsSimpleStatus.emAndamento;
}

String osSimpleStatusLabel(OsSimpleStatus s) => switch (s) {
      OsSimpleStatus.emAndamento => 'Em andamento',
      OsSimpleStatus.finalizada => 'Finalizada',
      OsSimpleStatus.cancelada => 'Cancelada',
    };

/// Paleta bem mais forte que o tint do chip — é o "cores bem visíveis" pedido
/// para os cards da lista (faixa sólida na borda, não fundo pastel).
///
/// Papel **gráfico**, como [osStatusColor]. Para texto, [osSimpleStatusInk].
Color osSimpleStatusColor(OsSimpleStatus s) => switch (s) {
      OsSimpleStatus.emAndamento => const Color(0xFF8B5CF6), // roxo — trabalho em curso
      OsSimpleStatus.finalizada => const Color(0xFF10B981), // verde — concluído
      OsSimpleStatus.cancelada => const Color(0xFFE5484D), // vermelho — cancelada
    };

/// Variante de [osSimpleStatusColor] com 4,5:1 sobre o canvas — ver
/// [osStatusInk].
Color osSimpleStatusInk(OsSimpleStatus s, Brightness brightness) =>
    osStatusInk(
      switch (s) {
        OsSimpleStatus.emAndamento => 'em_execucao',
        OsSimpleStatus.finalizada => 'concluida',
        OsSimpleStatus.cancelada => 'cancelada',
      },
      brightness,
    );

IconData osSimpleStatusIcon(OsSimpleStatus s) => switch (s) {
      OsSimpleStatus.emAndamento => Icons.autorenew_rounded,
      OsSimpleStatus.finalizada => Icons.check_circle_rounded,
      OsSimpleStatus.cancelada => Icons.cancel_rounded,
    };

/// Os status REAIS que caem no grupo simplificado — inverso de
/// [osSimpleStatusOf]. Usado para filtrar a lista pelo grupo (o backend só
/// entende status reais, então o front traduz "Em andamento" num CSV deles).
List<String> osRealStatusesOf(OsSimpleStatus s) => switch (s) {
      OsSimpleStatus.emAndamento => const [
          'aberta',
          'aguardando_aprovacao',
          'aprovada',
          'em_execucao',
        ],
      OsSimpleStatus.finalizada => const ['concluida', 'entregue'],
      OsSimpleStatus.cancelada => const ['cancelada'],
    };

/// Sequência de status REAIS (sem o atual) para ir de [atual] até [destino],
/// percorrendo `osTransitions` — o mesmo grafo que o backend valida.
///
/// `null` = sem caminho (o botão deve ficar desabilitado): por exemplo, uma OS
/// `concluida` não pode virar `cancelada` na FSM de hoje (só sai para
/// `entregue`), e uma `entregue` é terminal — não sai para lugar nenhum. Isto
/// é o que permite ao seletor de 3 botões respeitar EXATAMENTE as mesmas regras
/// que o backend já impõe, sem duplicar a validação de forma divergente.
///
/// Lista vazia = já está no destino (idempotente, nenhuma chamada necessária).
List<String>? osCaminhoAte(String atual, OsSimpleStatus destino) {
  // "Em andamento" é um caso especial, NÃO um BFS genérico até 'aberta': a
  // FSM tem transições de VOLTA de 'aguardando_aprovacao'/'aprovada' para
  // 'aberta' que fazem sentido como REGRESSÃO manual, mas NÃO como o que o
  // botão "Em andamento" deveria fazer quando a OS já está em andamento —
  // aguardando_aprovacao→aberta É um caminho válido na FSM, só que voltar não
  // é a intenção de quem toca num botão que já está selecionado. A única
  // transição de verdade que "Em andamento" representa é a REABERTURA de uma
  // OS cancelada.
  if (destino == OsSimpleStatus.emAndamento) {
    if (osSimpleStatusOf(atual) == OsSimpleStatus.emAndamento) return const [];
    if (atual == 'cancelada') return const ['aberta'];
    return null; // finalizada (concluida/entregue) não "volta" a andamento
  }

  final alvo = destino == OsSimpleStatus.finalizada ? 'entregue' : 'cancelada';
  if (atual == alvo) return const [];

  // BFS — o grafo tem 7 nós, então nem vale a pena um algoritmo mais chique.
  final visitado = <String>{atual};
  final fila = <List<String>>[
    [atual],
  ];
  while (fila.isNotEmpty) {
    final caminho = fila.removeAt(0);
    final ultimo = caminho.last;
    for (final proximo in osTransitions[ultimo] ?? const <String>[]) {
      if (proximo == alvo) return [...caminho.skip(1), proximo];
      if (visitado.add(proximo)) fila.add([...caminho, proximo]);
    }
  }
  return null;
}

/// Formata um decimal serializado ("45.90") em "R$ 45,90". Null/vazio → "R$ 0,00".
String money(String? decimal) {
  final v = double.tryParse(decimal ?? '') ?? 0;
  return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}
