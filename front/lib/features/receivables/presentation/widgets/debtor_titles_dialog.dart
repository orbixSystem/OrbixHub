import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../cashier/domain/cashier_models.dart';
import '../../../cashier/domain/local_payment.dart';
import '../../../cashier/presentation/cashier_providers.dart';
import '../../../os/presentation/os_detail_dialog.dart';
import '../../../sale/presentation/sale_detail_dialog.dart';
import '../../domain/receivables_models.dart';
import '../combinar_prazo_dialog.dart';
import '../editar_parcela_dialog.dart';
import '../receivables_providers.dart';
import '../receive_title_dialog.dart';

/// Títulos em aberto de um cliente — cada OS/venda com seus itens e o botão de
/// receber. É onde se responde "de quais serviços é essa dívida".
Future<void> showDebtorTitlesDialog(
  BuildContext context, {
  required String? customerId,
  required String customerName,
  required bool canWrite,
}) {
  // Espaço é o que esta tela mais precisa: cada título traz saldo, ações e um
  // cronograma de parcelas. Em 560px fixos tudo virava coluna estreita com
  // rótulo quebrando. Cresce com a janela e para em 900 (linha longa demais
  // custa leitura), sem nunca passar da largura disponível no celular.
  final larguraTela = MediaQuery.sizeOf(context).width;
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: customerName,
      maxWidth: (larguraTela - 96).clamp(360.0, 900.0),
      child: _DebtorTitles(
        customerId: customerId,
        // Sem cadastro, o NOME é a chave do devedor — é ele que separa
        // "Macarrão" de "rapaz da Hilux" na carteira. Com cadastro ele é
        // irrelevante (o id manda), e passar não atrapalha.
        apelido: customerId == null ? customerName : null,
        canWrite: canWrite,
      ),
    ),
  );
}

class _DebtorTitles extends ConsumerWidget {
  const _DebtorTitles({
    required this.customerId,
    required this.apelido,
    required this.canWrite,
  });

  final String? customerId;

  /// Apelido da venda de balcão. Só importa quando não há cliente cadastrado —
  /// é a chave que separa "Macarrão" de "rapaz da Hilux" na carteira.
  final String? apelido;
  final bool canWrite;

  DebtorKey get _chave => (customerId: customerId, apelido: apelido);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(debtorTitlesProvider(_chave));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Erro(
        message: '$e',
        onRetry: () => ref.invalidate(debtorTitlesProvider(_chave)),
      ),
      data: (detail) {
        if (detail.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nada em aberto para este cliente.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Total em aberto',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
                const Spacer(),
                Text(
                  formatMoney(detail.totalDue),
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Mais antigo primeiro: é a ordem em que se cobra.
            for (final t in detail.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TitleCard(
                  title: t,
                  canWrite: canWrite,
                  customerId: customerId,
                  apelido: apelido,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Um título em aberto: quanto deve, o caminho para o detalhe e UMA ação —
/// receber. Parcelar não é um segundo botão concorrendo aqui: é uma opção
/// dentro do recebimento (recebeu parte, programa o resto). Quando já existe
/// plano, o cronograma vira INFORMAÇÃO e o botão passa a quitar a próxima
/// parcela — um alvo só, sempre no mesmo lugar.
class _TitleCard extends ConsumerWidget {
  const _TitleCard({
    required this.title,
    required this.canWrite,
    required this.customerId,
    required this.apelido,
  });

  final ReceivableTitle title;
  final bool canWrite;
  final String? customerId;

  /// Apelido do devedor anônimo — parte da chave do cache, ver [DebtorKey].
  final String? apelido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final parcial = title.status == 'parcial';
    final rotulo = title.origin == 'os' ? title.number : 'Venda ${title.number}';
    // Plano de parcelas do título (vazio = não parcelado).
    final parcelas = ref
            .watch(installmentsProvider(
                (saleKind: title.origin, saleId: title.id)))
            .value ??
        const <Installment>[];
    // Cobra-se da mais antiga para a mais nova — não faz sentido quitar a 3ª
    // deixando a 1ª vencida para trás.
    final pendentes = parcelas.where((p) => p.paidAt == null).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final proxima = pendentes.isEmpty ? null : pendentes.first;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho INTEIRO clicável — abre o detalhe de verdade (a tela da
          // OS, com PDF, ou o diálogo da venda, com itens e recebimentos).
          // Antes só a venda tinha esse caminho; a OS parava aqui, obrigando a
          // sair do Fiado e procurar na lista de OS por conta própria. Os itens
          // saíram do card por isso: quem quer o detalhamento agora abre o
          // detalhe de verdade, em vez de uma cópia resumida dele aqui.
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NeuTokens.rField),
            ),
            onTap: () => _abrirDetalhe(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    title.origin == 'os'
                        ? Icons.build_outlined
                        : Icons.shopping_cart_outlined,
                    size: 16,
                    color: neu.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // PARCELADO vem antes de tudo: é a informação que muda o
                  // que o operador vai fazer aqui (cobrar uma parcela, não o
                  // saldo). Antes só se descobria rolando até o cronograma.
                  if (parcelas.isNotEmpty) ...[
                    NeuStatusChip(
                      label: 'Parcelado ${parcelas.length}x',
                      color: neu.navy,
                      tint: neu.accentTint,
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (parcial) ...[
                    NeuStatusChip(
                      label: 'Parcial',
                      color: neu.warning,
                      tint: neu.warningTint,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Ver detalhes',
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: neu.navy),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: neu.line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deve ${formatMoney(title.balance)}',
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (parcial)
                      Text(
                        'de ${formatMoney(title.total)} · já pagou '
                        '${formatMoney(title.paid)}',
                        style: TextStyle(color: neu.inkMuted, fontSize: 12),
                      ),
                    if (canWrite && title.balance > 0) ...[
                      const SizedBox(height: 10),
                      // Wrap, não Row: são dois botões de rótulo longo
                      // ("Alterar prazo" + "Receber parcela") num diálogo
                      // estreito — em Row eles estouravam a linha.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          // Combinar/alterar prazo é AÇÃO PRÓPRIA. Antes só
                          // dava para combinar na hora de fiar: depois, a única
                          // saída era abrir "Receber", zerar o valor e clicar
                          // em "Deixar fiado" — o que ninguém descobre.
                          // Secundário porque o ato comum aqui é receber.
                          NeuButton(
                            label: parcelas.isEmpty
                                ? 'Combinar prazo'
                                : 'Alterar prazo',
                            icon: Icons.event_outlined,
                            kind: NeuButtonKind.secondary,
                            onPressed: () =>
                                _combinarPrazo(context, ref, parcelas),
                          ),
                          NeuButton(
                            label:
                                proxima == null ? 'Receber' : 'Receber parcela',
                            icon: Icons.payments_outlined,
                            onPressed: () =>
                                _receber(context, ref, proxima, pendentes),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                // Cronograma como INFORMAÇÃO (o que vence e quando). Receber é
                // sempre pelo botão acima — uma fileira de botões, um por
                // parcela, era o que fazia esta tela parecer cheia de cliques.
                if (parcelas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ScheduleList(
                    parcelas: parcelas,
                    saldoDoTitulo: title.balance.toDouble(),
                    canWrite: canWrite,
                    onEditar: (p, ordem, outras) async {
                      final gravou = await showEditarParcelaDialog(
                        context,
                        parcela: p,
                        ordem: ordem,
                        total: parcelas.length,
                        saldoDoTitulo: title.balance.toDouble(),
                        outrasEmAberto: outras,
                      );
                      if (gravou) _refresh(ref);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Combina o prazo (ou corrige o que estava combinado) sem passar pelo
  /// recebimento — quem só quer marcar "paga dia 30" não está recebendo nada.
  Future<void> _combinarPrazo(
    BuildContext context,
    WidgetRef ref,
    List<Installment> parcelas,
  ) async {
    final gravou = await showCombinarPrazoDialog(
      context,
      titulo: title,
      parcelasAtuais: parcelas,
    );
    if (gravou) _refresh(ref);
  }

  /// Abre o detalhe de VERDADE do título, sem tirar o operador do Fiado: os
  /// dois origins abrem em MODAL (a OS ganhou o seu, espelhando o da venda) —
  /// navegar para a tela da OS fazia perder a lista de cobrança.
  void _abrirDetalhe(BuildContext context) {
    if (title.origin == 'os') {
      showOsDetailDialog(context, orderId: title.id);
    } else {
      showSaleDetailDialog(context, saleId: title.id);
    }
  }

  /// Recebimento: lançamento no caixa apontando para a venda/OS. Reusa o mesmo
  /// diálogo do "Receber OS" — aceita parcial, oferece parcelar o que sobrar e,
  /// quando há plano, quita a parcela [proxima].
  Future<void> _receber(
    BuildContext context,
    WidgetRef ref,
    Installment? proxima,
    List<Installment> pendentes,
  ) async {
    // ESPERA a config do caixa em vez de ler o valor corrente.
    //
    // `cashierControllerProvider` é `autoDispose`: aberto de dentro do diálogo
    // de títulos, ninguém o observa, então `ref.read(...).value` vem `null`
    // enquanto ele carrega — e o código antigo desistia calado ali. Para o
    // operador o botão "Receber" simplesmente não fazia nada, sem erro nem
    // spinner. Falhar em silêncio é pior que falhar: ninguém sabe o que
    // tentar em seguida.
    final CashierConfig config;
    try {
      config = (await ref.read(cashierControllerProvider.future)).config;
    } on Object catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, 'Não foi possível abrir o caixa: $e');
      }
      return;
    }
    if (!context.mounted) return;
    await showReceiveTitleDialog(
      context,
      ref,
      config: config,
      title: title,
      parcela: proxima,
      // Todas as em aberto: com mais de uma, o diálogo deixa marcar quais
      // quitar (da mais antiga para a frente) em vez de só a próxima.
      parcelasEmAberto: pendentes,
    );
    if (!context.mounted) return;
    _refresh(ref);
  }

  /// O saldo/plano mudou: recarrega o cronograma, os títulos do cliente e a
  /// carteira — as três lentes derivam do mesmo espelho de lançamentos.
  void _refresh(WidgetRef ref) {
    ref.invalidate(installmentsProvider((saleKind: title.origin, saleId: title.id)));
    ref.invalidate(debtorTitlesProvider(
      (customerId: customerId, apelido: apelido),
    ));
    ref.invalidate(debtorsProvider);
  }
}

/// Cronograma das parcelas: o que vence, quando e o que já foi pago.
///
/// Nasce FECHADO. Um título de 12 parcelas abria 12 linhas dentro do card, e o
/// diálogo do cliente virava uma rolagem sem fim antes de mostrar o segundo
/// título. O cabeçalho já responde o que se pergunta no dia a dia ("parcelado
/// em quantas, quantas já foram, qual a próxima"); a lista completa é para
/// quando alguém quer conferir, e aí ela abre.
///
/// Receber continua sendo pelo botão único do card — que já mira a parcela mais
/// antiga em aberto. Um botão por linha aqui multiplicava os alvos de uma
/// decisão que na prática é sempre a mesma. O lápis é exceção: mudar o VALOR de
/// uma parcela é por parcela, não há como ser em outro lugar.
class _ScheduleList extends StatefulWidget {
  const _ScheduleList({
    required this.parcelas,
    required this.saldoDoTitulo,
    required this.canWrite,
    required this.onEditar,
  });

  final List<Installment> parcelas;

  /// Quanto o título ainda deve — o cronograma deveria somar isto.
  final double saldoDoTitulo;
  final bool canWrite;

  /// (parcela, ordem 1-based, soma das OUTRAS em aberto).
  final void Function(Installment p, int ordem, double outrasEmAberto) onEditar;

  @override
  State<_ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<_ScheduleList> {
  bool _aberto = false;

  /// Altura máxima da lista aberta. Acima disso ela ROLA por dentro, em vez de
  /// empurrar o card e o diálogo — é o que impede um plano de 60 parcelas de
  /// esticar a tela até o botão de receber sair de vista.
  static const double _alturaMaxima = 240;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ordenadas = [...widget.parcelas]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final pagas = ordenadas.where((p) => p.paidAt != null).length;
    final emAberto = ordenadas.where((p) => p.paidAt == null).toList();
    final somaEmAberto =
        emAberto.fold<double>(0, (a, p) => a + p.valor);
    // As parcelas em aberto deveriam somar exatamente o que o cliente deve.
    // Deixar de fechar é legítimo (alguém corrigiu um valor de propósito), mas
    // nunca deve ser invisível.
    final diferenca = round2Money(somaEmAberto - widget.saldoDoTitulo);
    final fecha = diferenca.abs() <= paymentEps;
    final proxima = emAberto.isEmpty ? null : emAberto.first;

    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho inteiro clicável: é o próprio controle de abrir/fechar.
          InkWell(
            onTap: () => setState(() => _aberto = !_aberto),
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: neu.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Parcelado em ${ordenadas.length}x',
                      style: TextStyle(
                        color: neu.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$pagas de ${ordenadas.length} pagas',
                    style: TextStyle(color: neu.inkFaint, fontSize: 12),
                  ),
                  Icon(
                    _aberto
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: neu.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          // Fechado, ainda responde o que importa agora: qual é a próxima.
          if (!_aberto && proxima != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Próxima: ${_rotuloVencimento(proxima)} · '
                '${formatMoney(proxima.valor)}',
                style: TextStyle(
                  color: proxima.status == InstallmentStatus.vencida
                      ? neu.danger
                      : neu.inkFaint,
                  fontSize: 12,
                  fontWeight: proxima.status == InstallmentStatus.vencida
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
          if (!fecha)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: neu.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'As parcelas em aberto somam '
                      '${formatMoney(somaEmAberto)} e o saldo é '
                      '${formatMoney(widget.saldoDoTitulo)}.',
                      style: TextStyle(
                        color: neu.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_aberto) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _alturaMaxima),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < ordenadas.length; i++)
                        _LinhaCronograma(
                          parcela: ordenadas[i],
                          ordem: i + 1,
                          // Editar só o que ainda não virou dinheiro no caixa.
                          onEditar: widget.canWrite &&
                                  ordenadas[i].paidAt == null
                              ? () => widget.onEditar(
                                    ordenadas[i],
                                    i + 1,
                                    round2Money(
                                      somaEmAberto - ordenadas[i].valor,
                                    ),
                                  )
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma linha do cronograma. O lápis aparece só para parcela em aberto de quem
/// pode escrever — o valor de uma parcela paga já virou lançamento no caixa.
class _LinhaCronograma extends StatelessWidget {
  const _LinhaCronograma({
    required this.parcela,
    required this.ordem,
    required this.onEditar,
  });

  final Installment parcela;
  final int ordem;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final vencida = parcela.status == InstallmentStatus.vencida;
    final paga = parcela.paidAt != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _StatusDot(status: parcela.status),
          const SizedBox(width: 8),
          Text(
            '$ordemª',
            style: TextStyle(color: neu.inkFaint, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _rotuloVencimento(parcela),
              style: TextStyle(
                color: vencida ? neu.danger : neu.inkMuted,
                fontSize: 12.5,
                fontWeight: vencida ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            formatMoney(parcela.valor),
            style: TextStyle(
              color: paga ? neu.inkFaint : neu.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              decoration: paga ? TextDecoration.lineThrough : null,
            ),
          ),
          if (onEditar != null)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: neu.inkMuted,
                tooltip: 'Corrigir o valor desta parcela',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: onEditar,
              ),
            )
          else
            // Mantém o alinhamento das colunas de valor com as linhas que têm
            // lápis — sem isto a parcela paga aparece deslocada.
            const SizedBox(width: 34),
        ],
      ),
    );
  }
}

/// "Vencida", "Vence hoje", "Paga" ou a data — o estado vem antes do número,
/// porque é ele que decide se alguém precisa agir.
String _rotuloVencimento(Installment p) {
  if (p.paidAt != null) return 'Paga';
  final d = DateTime.tryParse(p.dueDate);
  final data = d == null
      ? p.dueDate
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
  if (p.status == InstallmentStatus.vencida) return 'Vencida · $data';
  if (p.venceHoje) return 'Vence hoje';
  return data;
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final InstallmentStatus status;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = switch (status) {
      InstallmentStatus.paga => neu.success,
      InstallmentStatus.vencida => neu.danger,
      InstallmentStatus.pendente => neu.warning,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: neu.danger, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
