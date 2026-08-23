import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../domain/support_models.dart';

/// Suporte: os chamados do ambiente, e a conversa de cada um.
///
/// Dois níveis na mesma seção — lista e conversa. O cliente costuma ter mais de
/// um assunto ao mesmo tempo, e numa thread única ninguém sabe qual pergunta a
/// resposta responde, nem dá para encerrar um assunto sem encerrar os outros.
class SupportSection extends ConsumerStatefulWidget {
  const SupportSection({super.key});

  @override
  ConsumerState<SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends ConsumerState<SupportSection> {
  /// Chamado aberto na tela. Nulo = mostrando a lista.
  SupportTicket? _aberto;
  bool _novo = false;
  final RealtimeChat _rt = RealtimeChat();

  @override
  void initState() {
    super.initState();
    // Resposta da Orbix aparece na hora, sem recarregar nem sair da tela — é
    // uma conversa, e conversa que só atualiza no F5 não é conversa.
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken != null) {
      _rt.connectStaff(
        accessToken: accessToken,
        onMessage: (_) {},
        onSupportChanged: (_) {
          if (!mounted) return;
          // Recarrega do servidor em vez de aplicar o payload: o evento traz só
          // "o que mudou", e a leitura (que zera o contador) acontece lá.
          ref.invalidate(supportTicketsProvider);
          ref.invalidate(supportUnreadProvider);
          final aberto = _aberto;
          if (aberto != null) ref.invalidate(supportThreadProvider(aberto.id));
        },
      );
    }
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_novo) {
      return _NovoChamado(
        onCancelar: () => setState(() => _novo = false),
        onCriado: (t) => setState(() {
          _novo = false;
          _aberto = t;
        }),
      );
    }
    final aberto = _aberto;
    if (aberto != null) {
      return _Conversa(
        ticket: aberto,
        onVoltar: () => setState(() => _aberto = null),
      );
    }
    return _Lista(
      onAbrirNovo: () => setState(() => _novo = true),
      onAbrir: (t) => setState(() => _aberto = t),
    );
  }
}

// ------------------------------------------------------------------ lista

class _Lista extends ConsumerWidget {
  const _Lista({required this.onAbrirNovo, required this.onAbrir});

  final VoidCallback onAbrirNovo;
  final void Function(SupportTicket) onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(supportTicketsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Abra um chamado para falar com a equipe da Orbix. Respondemos por '
          'aqui e pelo e-mail cadastrado da empresa.',
          style: TextStyle(color: neu.inkMuted, height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: NeuButton(
            key: const Key('support-novo'),
            icon: Icons.add_rounded,
            label: 'Novo chamado',
            onPressed: onAbrirNovo,
          ),
        ),
        const SizedBox(height: 16),
        // A lista rola dentro da própria área: o convite e o "Novo chamado"
        // ficam parados no topo, sempre alcançáveis por mais longo que o
        // histórico fique.
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => NeuEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Não foi possível carregar',
              message: e is AppException
                  ? e.message
                  : 'Tente de novo em instantes.',
            ),
            data: (tickets) => tickets.isEmpty
                ? const NeuEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'Nenhum chamado ainda',
                    message:
                        'Quando precisar de ajuda, abra um chamado — quanto '
                        'mais específico, mais rápido a gente resolve.',
                  )
                : SingleChildScrollView(
                    child: _ListaSeparada(tickets: tickets, onAbrir: onAbrir),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Em aberto primeiro, resolvidos depois e recolhidos.
///
/// O que precisa de atenção some no meio do histórico quando tudo é uma lista
/// só — e o histórico cresce para sempre, enquanto o que está aberto é sempre
/// pouco.
class _ListaSeparada extends StatefulWidget {
  const _ListaSeparada({required this.tickets, required this.onAbrir});

  final List<SupportTicket> tickets;
  final void Function(SupportTicket) onAbrir;

  @override
  State<_ListaSeparada> createState() => _ListaSeparadaState();
}

class _ListaSeparadaState extends State<_ListaSeparada> {
  bool _mostrarResolvidos = false;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final abertos = widget.tickets
        .where((t) => !t.resolvido)
        .toList(growable: false);
    final resolvidos = widget.tickets
        .where((t) => t.resolvido)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (abertos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Nenhum chamado em aberto.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
          ),
        for (final t in abertos) ...[
          _TicketTile(ticket: t, onTap: () => widget.onAbrir(t)),
          const SizedBox(height: 8),
        ],
        if (resolvidos.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('support-ver-resolvidos'),
              onPressed: () =>
                  setState(() => _mostrarResolvidos = !_mostrarResolvidos),
              icon: Icon(
                _mostrarResolvidos
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: Text(
                '${resolvidos.length} '
                '${resolvidos.length == 1 ? 'resolvido' : 'resolvidos'}',
                style: const TextStyle(fontSize: 14),
              ),
              style: TextButton.styleFrom(
                foregroundColor: neu.inkMuted,
                minimumSize: const Size(64, 44),
              ),
            ),
          ),
          if (_mostrarResolvidos)
            for (final t in resolvidos) ...[
              _TicketTile(ticket: t, onTap: () => widget.onAbrir(t)),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Material(
      color: neu.surfaceHi,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: InkWell(
        key: Key('support-ticket-${ticket.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_situacao(ticket)} · ${_data(ticket.lastMessageAt)}',
                      style: TextStyle(fontSize: 12.5, color: neu.inkMuted),
                    ),
                  ],
                ),
              ),
              // Ponto de não lida: some sozinho quando o chamado é aberto — a
              // leitura acontece no servidor, então o número nunca mente.
              if (ticket.naoLidas > 0)
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    // Mesmo par do badge do sino: cor de alerta com texto
                    // branco lê bem nos dois temas.
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    ticket.naoLidas > 99 ? '99+' : '${ticket.naoLidas}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: neu.inkFaint),
            ],
          ),
        ),
      ),
    );
  }

  static String _situacao(SupportTicket t) {
    if (t.reaberturaPedida) return 'Reabertura pedida';
    return t.resolvido ? 'Resolvido' : 'Aberto';
  }

  static String _data(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)} às ${dd(l.hour)}:${dd(l.minute)}';
  }
}

// ------------------------------------------------------------ novo chamado

class _NovoChamado extends ConsumerStatefulWidget {
  const _NovoChamado({required this.onCancelar, required this.onCriado});

  final VoidCallback onCancelar;
  final void Function(SupportTicket) onCriado;

  @override
  ConsumerState<_NovoChamado> createState() => _NovoChamadoState();
}

class _NovoChamadoState extends ConsumerState<_NovoChamado> {
  final _assunto = TextEditingController();
  final _corpo = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _assunto.dispose();
    _corpo.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    final a = _assunto.text.trim();
    final b = _corpo.text.trim();
    if (a.isEmpty || b.isEmpty || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final t = await ref.read(supportRepositoryProvider).abrir(a, b);
      ref.invalidate(supportTicketsProvider);
      ref.invalidate(supportUnreadProvider);
      if (mounted) {
        showNeuSuccessOn(
          ScaffoldMessenger.of(context),
          'Chamado aberto. Respondemos por aqui e pelo e-mail da empresa.',
        );
        widget.onCriado(t);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Voltar(label: 'Novo chamado', onVoltar: widget.onCancelar),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_erro != null) ...[
                  Text(
                    _erro!,
                    style: TextStyle(color: neu.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                NeuTextField(
                  key: const Key('support-assunto'),
                  controller: _assunto,
                  label: 'Assunto',
                  hint: 'Ex.: A nota fiscal não está saindo',
                  maxLength: 120,
                ),
                const SizedBox(height: 12),
                NeuTextField(
                  key: const Key('support-campo'),
                  controller: _corpo,
                  label: 'Sua mensagem',
                  hint: 'Descreva o problema ou a dúvida',
                  maxLines: 5,
                  maxLength: 4000,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: NeuButton(
                    key: const Key('support-enviar'),
                    icon: Icons.send_rounded,
                    label: 'Abrir chamado',
                    loading: _enviando,
                    onPressed: _enviando ? null : _abrir,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- conversa

class _Conversa extends ConsumerStatefulWidget {
  const _Conversa({required this.ticket, required this.onVoltar});

  final SupportTicket ticket;
  final VoidCallback onVoltar;

  @override
  ConsumerState<_Conversa> createState() => _ConversaState();
}

class _ConversaState extends ConsumerState<_Conversa> {
  final _campo = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;
  String? _erro;

  /// Id da última mensagem já mostrada. É o gatilho da rolagem: só rola quando
  /// o FIM da conversa mudou, e não a cada rebuild (senão a tela brigaria com
  /// quem estivesse lendo).
  String? _ultimaMostrada;

  @override
  void dispose() {
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Leva a conversa até a última mensagem.
  ///
  /// Chat que chega mensagem nova e não desce é chat que faz o usuário rolar
  /// atrás do que acabou de chegar — e no suporte a resposta é exatamente o que
  /// ele está esperando. A primeira carga entra já no fim (sem animação, para
  /// não parecer que a tela "pulou"); as seguintes deslizam.
  void _irParaOFim(List<SupportMessage> msgs) {
    final ultima = msgs.isEmpty ? null : msgs.last.id;
    if (ultima == _ultimaMostrada) return;
    final primeiraCarga = _ultimaMostrada == null;
    _ultimaMostrada = ultima;
    // Depois do frame: antes de pintar, `maxScrollExtent` ainda é o da lista
    // ANTIGA e a rolagem pararia uma mensagem antes do fim.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _colar(animar: !primeiraCarga),
    );
  }

  /// Cola no fim da conversa — e confere depois de chegar lá.
  ///
  /// A lista é preguiçosa: enquanto os balões que faltam não foram medidos,
  /// `maxScrollExtent` é uma ESTIMATIVA (média × quantidade). Rolar até ela
  /// para alguns pixels antes do fim real, e a última mensagem fica cortada
  /// embaixo. O segundo passe, já com tudo medido, fecha essa diferença.
  void _colar({required bool animar, int passe = 0}) {
    if (!mounted || !_scroll.hasClients) return;
    final fim = _scroll.position.maxScrollExtent;
    if ((fim - _scroll.position.pixels).abs() < 1) return;
    if (passe >= 3) return;
    if (!animar) {
      _scroll.jumpTo(fim);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _colar(animar: false, passe: passe + 1),
      );
      return;
    }
    _scroll
        .animateTo(
          fim,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        )
        .then((_) => _colar(animar: false, passe: passe + 1));
  }

  /// Envia. Num chamado FECHADO o mesmo campo vira pedido de reabertura — o
  /// texto é o mesmo trabalho para quem escreve, e o servidor é quem decide o
  /// que isso significa.
  Future<void> _responder() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      if (widget.ticket.resolvido) {
        await repo.solicitarReabertura(widget.ticket.id, texto);
      } else {
        await repo.responder(widget.ticket.id, texto);
      }
      _campo.clear();
      ref.invalidate(supportThreadProvider(widget.ticket.id));
      ref.invalidate(supportTicketsProvider);
    } on AppException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final async = ref.watch(supportThreadProvider(widget.ticket.id));
    final fechado = widget.ticket.resolvido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Voltar(label: widget.ticket.subject, onVoltar: widget.onVoltar),
        const SizedBox(height: 14),
        // A conversa ocupa a altura que sobra e rola sozinha; o campo de
        // resposta fica ancorado embaixo, como em qualquer chat.
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => NeuEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Não foi possível carregar',
              message: e is AppException
                  ? e.message
                  : 'Tente de novo em instantes.',
            ),
            data: (msgs) {
              _irParaOFim(msgs);
              return ListView.separated(
                controller: _scroll,
                padding: EdgeInsets.zero,
                itemCount: msgs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _Balao(msg: msgs[i]),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (_erro != null) ...[
          Text(_erro!, style: TextStyle(color: neu.danger, fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (widget.ticket.reaberturaPedida) ...[
          _Faixa(
            icone: Icons.hourglass_top_rounded,
            texto:
                'Você pediu para reabrir este chamado. A equipe da Orbix '
                'vai retomar a conversa.',
          ),
          const SizedBox(height: 14),
        ],
        NeuTextField(
          key: const Key('support-campo'),
          controller: _campo,
          label: fechado ? 'Pedir reabertura' : 'Responder',
          hint: fechado
              ? 'Conte o que voltou a acontecer'
              : 'Escreva sua resposta',
          maxLines: 3,
          maxLength: 4000,
        ),
        if (fechado) ...[
          const SizedBox(height: 6),
          Text(
            'Este chamado foi encerrado. Ao enviar, a equipe da Orbix recebe '
            'seu pedido de reabertura.',
            style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.4),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: NeuButton(
            key: const Key('support-enviar'),
            icon: fechado ? Icons.lock_open_rounded : Icons.send_rounded,
            label: fechado ? 'Pedir reabertura' : 'Enviar',
            loading: _enviando,
            onPressed: _enviando ? null : _responder,
          ),
        ),
      ],
    );
  }
}

class _Voltar extends StatelessWidget {
  const _Voltar({required this.label, required this.onVoltar});

  final String label;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        IconButton(
          key: const Key('support-voltar'),
          icon: Icon(Icons.arrow_back_rounded, color: neu.ink),
          onPressed: onVoltar,
          tooltip: 'Voltar aos chamados',
        ),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.ink,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Balão de uma mensagem.
///
/// As cores vêm do TEMA (`neu.navy` / `neu.surfaceHi`), como no chat da OS, e
/// não de uma constante estática: a primeira versão usava `AppColors.brandTint`,
/// que é do tema claro — no escuro pintava fundo claro com texto claro e o
/// texto sumia.
class _Balao extends StatelessWidget {
  const _Balao({required this.msg});

  final SupportMessage msg;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final daOrbix = msg.fromOrbix;
    final bg = daOrbix ? neu.surfaceHi : neu.navy;
    final fg = daOrbix ? neu.ink : neu.onNavy;
    final meta = daOrbix ? neu.inkMuted : neu.onNavy.withValues(alpha: 0.8);

    return Align(
      alignment: daOrbix ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(daOrbix ? 4 : 16),
              bottomRight: Radius.circular(daOrbix ? 16 : 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                daOrbix ? 'Suporte Orbix' : (msg.authorName ?? 'Você'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: meta,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg.body,
                style: TextStyle(color: fg, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _quando(msg.createdAt),
                style: TextStyle(fontSize: 12, color: meta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _quando(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)} às ${dd(l.hour)}:${dd(l.minute)}';
  }
}

/// Faixa informativa dentro da conversa (fundo suave, sem virar alerta).
class _Faixa extends StatelessWidget {
  const _Faixa({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: neu.surfaceHi,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: neu.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: neu.ink, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
