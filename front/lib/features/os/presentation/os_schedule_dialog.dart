import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Define a janela de serviço de uma OS: quando o carro entra e quando sai.
///
/// Mora no módulo OS porque as datas são da OS — a agenda só as LÊ. Assim
/// agendar pela agenda, pela lista ou pela ficha é literalmente o mesmo
/// caminho, e não há um segundo lugar guardando data de serviço.
///
/// Antes só dava para mexer nisso abrindo a OS → Editar, no meio de um
/// formulário com cliente, veículo, responsável e relato. Reagendar um carro
/// custava seis toques e a agenda não oferecia nenhum.
///
/// Devolve `true` quando salvou.
Future<bool> showOsScheduleDialog(
  BuildContext context,
  WidgetRef ref, {
  required ServiceOrder order,
}) async {
  final ok = await showNeuDialog<bool>(
    context,
    dialog: NeuDialog(
      title: 'Agendar ${order.number}',
      maxWidth: 440,
      child: _Form(order: order),
    ),
  );
  return ok ?? false;
}

/// Escolhe QUAL OS agendar — o passo que faltava para a agenda deixar de ser
/// só leitura. Lista as OS vivas (em andamento), com as SEM data no topo:
/// agendar é justamente o que se faz com elas.
///
/// Devolve `null` se o usuário desistir.
Future<ServiceOrder?> showOsPickerParaAgendar(
  BuildContext context,
  WidgetRef ref,
) {
  return showNeuDialog<ServiceOrder>(
    context,
    dialog: const NeuDialog(
      title: 'Agendar qual OS?',
      maxWidth: 480,
      child: _OsPicker(),
    ),
  );
}

class _OsPicker extends ConsumerStatefulWidget {
  const _OsPicker();

  @override
  ConsumerState<_OsPicker> createState() => _OsPickerState();
}

class _OsPickerState extends ConsumerState<_OsPicker> {
  final _busca = TextEditingController();
  late Future<List<ServiceOrder>> _futuro = _carregar();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<List<ServiceOrder>> _carregar() async {
    final q = _busca.text.trim();
    final page = await ref.read(osRepositoryProvider).listOrders(
          q: q.isEmpty ? null : q,
          // Só OS vivas: agendar uma entregue ou cancelada não faz sentido.
          statuses: osRealStatusesOf(OsSimpleStatus.emAndamento),
          sort: 'recent',
          page: 1,
        );
    final itens = [...page.items];
    // Sem data primeiro — são as que a agenda ainda não conhece.
    itens.sort((a, b) {
      final aSem = (a.scheduledStart ?? '').isEmpty ? 0 : 1;
      final bSem = (b.scheduledStart ?? '').isEmpty ? 0 : 1;
      return aSem.compareTo(bSem);
    });
    return itens;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuTextField(
          label: 'Buscar',
          controller: _busca,
          hint: 'Nº da OS ou cliente',
          prefixIcon: Icons.search_rounded,
          onChanged: (_) => setState(() => _futuro = _carregar()),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: FutureBuilder<List<ServiceOrder>>(
            future: _futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Não foi possível carregar as OS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                );
              }
              final itens = snap.data ?? const <ServiceOrder>[];
              if (itens.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Nenhuma OS em andamento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: itens.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: neu.line),
                itemBuilder: (_, i) {
                  final o = itens[i];
                  final semData = (o.scheduledStart ?? '').isEmpty;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      o.number,
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      [
                        ?o.customerName,
                        if ((o.subjectLabel ?? '').isNotEmpty) o.subjectLabel!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                    trailing: semData
                        ? Text(
                            'Sem data',
                            style: TextStyle(
                              color: neu.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(Icons.event_outlined,
                            size: 16, color: neu.inkFaint),
                    onTap: () => Navigator.of(context).pop(o),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.order});
  final ServiceOrder order;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late DateTime? _inicio = _parse(widget.order.scheduledStart);
  late DateTime? _fim = _parse(widget.order.scheduledEnd);
  bool _salvando = false;
  String? _erro;

  static DateTime? _parse(String? iso) =>
      iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _escolher({required bool inicio}) async {
    final base = (inicio ? _inicio : _fim) ?? _inicio ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: inicio ? 'Entrada do veículo' : 'Previsão de entrega',
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _inicio = escolhida;
        // Entrada depois da entrega é sempre engano de digitação: puxa a
        // entrega junto em vez de gravar uma janela invertida.
        if (_fim != null && _fim!.isBefore(escolhida)) _fim = escolhida;
      } else {
        _fim = escolhida;
        if (_inicio != null && escolhida.isBefore(_inicio!)) _inicio = escolhida;
      }
      _erro = null;
    });
  }

  Future<void> _salvar() async {
    if (_inicio == null) {
      setState(() => _erro = 'Informe ao menos a data de entrada.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(osRepositoryProvider).updateOrder(
            widget.order.id,
            OrderPatch(
              scheduledStart: _inicio!.toUtc().toIso8601String(),
              // Sem entrega definida, manda a própria entrada: o backend aceita
              // fim nulo, mas a agenda trata janela sem fim como evento de um
              // dia só — mandar o mesmo dia deixa isso explícito no dado.
              scheduledEnd: (_fim ?? _inicio!).toUtc().toIso8601String(),
            ),
          );
      ref.invalidate(orderProvider(widget.order.id));
      ref.invalidate(orderListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((widget.order.customerName ?? '').isNotEmpty ||
            (widget.order.subjectLabel ?? '').isNotEmpty) ...[
          Text(
            [
              ?widget.order.customerName,
              if ((widget.order.subjectLabel ?? '').isNotEmpty)
                widget.order.subjectLabel!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 14),
        ],
        _CampoData(
          rotulo: 'Entrada do veículo',
          valor: _inicio == null ? null : _fmt(_inicio!),
          icone: Icons.login_rounded,
          onTap: _salvando ? null : () => _escolher(inicio: true),
        ),
        const SizedBox(height: 10),
        _CampoData(
          rotulo: 'Previsão de entrega',
          valor: _fim == null ? null : _fmt(_fim!),
          icone: Icons.logout_rounded,
          onTap: _salvando ? null : () => _escolher(inicio: false),
          // Deixar em branco é legítimo: nem toda entrada tem prazo fechado.
          dica: 'Em branco = serviço de um dia só',
        ),
        if (_erro != null) ...[
          const SizedBox(height: 10),
          Text(_erro!, style: TextStyle(color: neu.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 20),
        NeuButton(
          label: 'Salvar agendamento',
          icon: Icons.event_available_outlined,
          expanded: true,
          loading: _salvando,
          onPressed: _salvando ? null : _salvar,
        ),
      ],
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.onTap,
    this.dica,
  });

  final String rotulo;
  final String? valor;
  final IconData icone;
  final VoidCallback? onTap;
  final String? dica;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icone, size: 17, color: neu.inkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valor ?? 'Escolher data',
                    style: TextStyle(
                      color: valor == null ? neu.inkFaint : neu.ink,
                      fontSize: 14.5,
                      fontWeight:
                          valor == null ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_outlined, size: 16, color: neu.navy),
              ],
            ),
          ),
        ),
        if (dica != null) ...[
          const SizedBox(height: 4),
          Text(
            dica!,
            style: TextStyle(color: neu.inkFaint, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
