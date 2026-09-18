import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/receivables_models.dart';
import 'debtor_titles_dialog.dart';

/// Um devedor: nome, quanto deve, quantos títulos e desde quando. Toque abre os
/// títulos separados.
class DebtorTile extends ConsumerWidget {
  const DebtorTile({super.key, required this.debtor, required this.canWrite});

  final Debtor debtor;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final dias = _diasDesde(debtor.oldestAt);
    return NeuCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: () => showDebtorTitlesDialog(
          context,
          customerId: debtor.customerId,
          customerName: debtor.customerName,
          canWrite: canWrite,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.customerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Wrap, não Row: com telefone + selo de vencimento + "Sem
                    // cadastro" tudo junto, um nome longo em tela estreita
                    // estourava a largura (RenderFlex overflow). Aqui o que
                    // não couber cai pra próxima linha em vez de sumir.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Devedor SEM cadastro fica marcado. Sem isto, um
                        // apelido digitado no balcão igual ao nome de um
                        // cliente real produz duas linhas visualmente
                        // IDÊNTICAS, com valores diferentes, e ninguém sabe
                        // qual é qual — cada uma cobra uma dívida de outra
                        // pessoa. Os títulos já estão separados corretamente;
                        // o que faltava era a tela dizer isso.
                        if (debtor.customerId == null)
                          NeuStatusChip(
                            label: 'Sem cadastro',
                            color: neu.inkMuted,
                            tint: neu.inkMuted.withValues(alpha: .14),
                            icon: Icons.person_off_outlined,
                          ),
                        if ((debtor.phone ?? '').isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 14, color: neu.inkMuted),
                              const SizedBox(width: 4),
                              Text(debtor.phone!,
                                  style: TextStyle(
                                      color: neu.inkMuted, fontSize: 12)),
                            ],
                          ),
                        // Sem prazo combinado é um ESTADO, não dado faltando:
                        // dizer isso deixa claro por que este devedor não
                        // aparece em atraso (ninguém combinou data).
                        if (debtor.nextDueAt == null)
                          NeuStatusChip(
                            label: 'Sem prazo',
                            color: neu.inkMuted,
                            tint: neu.inkMuted.withValues(alpha: .14),
                            icon: Icons.event_busy_outlined,
                          )
                        else
                          NeuStatusChip(
                            label: debtor.overdue
                                ? 'Vencido em ${_dataCurta(debtor.nextDueAt!)}'
                                : 'Vence em ${_dataCurta(debtor.nextDueAt!)}',
                            color: debtor.overdue ? neu.danger : neu.warning,
                            tint: debtor.overdue
                                ? neu.dangerTint
                                : neu.warningTint,
                            icon: debtor.overdue
                                ? Icons.error_outline
                                : Icons.event_outlined,
                          ),
                        Text(
                          [
                            debtor.titleCount == 1
                                ? '1 título'
                                : '${debtor.titleCount} títulos',
                            ?dias,
                          ].join(' · '),
                          style: TextStyle(color: neu.inkMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(debtor.totalDue),
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: neu.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// "dd/mm" a partir de um ISO — o vencimento não precisa do ano na lista, só
/// no drill-down (que já mostra o título inteiro).
String _dataCurta(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}';
}

/// "há N dias" a partir do título mais antigo. Sem vencimento no modelo, esta é
/// a única noção de tempo honesta — não é atraso, é idade da dívida.
String? _diasDesde(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final dias = DateTime.now().difference(d).inDays;
  if (dias <= 0) return 'de hoje';
  if (dias == 1) return 'há 1 dia';
  return 'há $dias dias';
}
