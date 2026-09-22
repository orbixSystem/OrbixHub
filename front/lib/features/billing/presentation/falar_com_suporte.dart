import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../support/domain/support_models.dart';

/// "Falar com o suporte" — e, se já existe conversa, ELA, não uma nova.
///
/// Bloqueado, o cliente não alcança a tela de suporte: a casca inteira deu
/// lugar ao aviso. Então esta é a única porta — e uma porta que só sabe ABRIR
/// chamado é uma porta ruim. Quem volta para saber se responderam abre outro
/// chamado, e o suporte acaba com cinco threads sobre o mesmo bloqueio,
/// nenhuma carregando o histórico da anterior.
///
/// Por isso a primeira coisa que ela faz é procurar um chamado em aberto. Se
/// existe, mostra a conversa e responde DENTRO dela; chamado novo só quando não
/// há nenhum.
///
/// Funciona com o acesso cortado porque o `SupportController` está
/// deliberadamente sem `@RequiresModule` — pedir ajuda não pode depender de
/// estar em dia.
class FalarComSuporte extends ConsumerStatefulWidget {
  const FalarComSuporte({super.key, required this.assunto});

  /// Assunto do chamado NOVO, quando não há nenhum em aberto.
  final String assunto;

  @override
  ConsumerState<FalarComSuporte> createState() => _FalarComSuporteState();
}

class _FalarComSuporteState extends ConsumerState<FalarComSuporte> {
  final _texto = TextEditingController();
  bool _aberto = false;
  bool _carregando = false;
  bool _enviando = false;
  String? _erro;

  /// O chamado em aberto, se houver. `null` = o envio abre um novo.
  SupportTicket? _chamado;
  List<SupportMessage> _mensagens = const [];

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _abrirPainel() async {
    setState(() {
      _aberto = true;
      _carregando = true;
      _erro = null;
    });
    await _carregarConversa();
  }

  Future<void> _carregarConversa() async {
    try {
      final repo = ref.read(supportRepositoryProvider);
      final tickets = await repo.tickets();
      // O mais recente que ainda não foi resolvido. Chamado fechado não aceita
      // mensagem — continuar nele daria erro em vez de ajuda.
      final abertos = tickets.where((t) => !t.resolvido).toList();
      final alvo = abertos.isEmpty ? null : abertos.first;

      final msgs =
          alvo == null ? <SupportMessage>[] : await repo.mensagens(alvo.id);

      if (!mounted) return;
      setState(() {
        _chamado = alvo;
        _mensagens = msgs;
        _carregando = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      // Não conseguir LER a conversa não pode impedir de escrever: cai para o
      // caminho de chamado novo, que é melhor do que uma tela morta.
      setState(() {
        _chamado = null;
        _mensagens = const [];
        _carregando = false;
        _erro = 'Não consegui carregar a conversa ($e).';
      });
    }
  }

  Future<void> _enviar() async {
    final corpo = _texto.text.trim();
    if (corpo.isEmpty) {
      setState(() => _erro = 'Escreva sua mensagem para enviar.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      final chamado = _chamado;
      if (chamado == null) {
        await repo.abrir(widget.assunto, corpo);
      } else {
        await repo.responder(chamado.id, corpo);
      }
      _texto.clear();
      await _carregarConversa();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _erro = 'Não consegui enviar agora. Tente de novo. ($e)');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    if (!_aberto) {
      return NeuButton(
        label: 'Falar com o suporte',
        icon: Icons.support_agent_rounded,
        kind: NeuButtonKind.secondary,
        onPressed: _abrirPainel,
      );
    }

    if (_carregando) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: neu.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Abrindo sua conversa com a Orbix…',
              style: TextStyle(color: neu.inkMuted, fontSize: 13.5),
            ),
          ],
        ),
      );
    }

    final chamado = _chamado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chamado != null) ...[
          Text(
            'Chamado: ${chamado.subject}',
            style: TextStyle(
              color: neu.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Altura limitada: a conversa não pode empurrar o campo de escrever
          // para fora da tela num celular.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final m in _mensagens) _Balao(mensagem: m)],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        NeuTextField(
          controller: _texto,
          label: chamado == null ? 'Sua dúvida' : 'Responder',
          hint: 'Conte o que aconteceu — respondemos por aqui e por e-mail.',
          maxLines: 3,
        ),
        if (_erro != null) ...[
          const SizedBox(height: 8),
          Text(
            _erro!,
            style: TextStyle(
              color: neu.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        NeuButton(
          label: chamado == null ? 'Enviar' : 'Responder',
          icon: Icons.send_rounded,
          loading: _enviando,
          onPressed: _enviando ? null : _enviar,
        ),
      ],
    );
  }
}

/// Uma fala da conversa. A da Orbix vem destacada — é a que a pessoa abriu a
/// tela para ler.
class _Balao extends StatelessWidget {
  const _Balao({required this.mensagem});

  final SupportMessage mensagem;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final daOrbix = mensagem.fromOrbix;

    return Align(
      alignment: daOrbix ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: daOrbix ? neu.accentTint : neu.surface,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          border: Border.all(color: daOrbix ? neu.accent : neu.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              daOrbix ? (mensagem.authorName ?? 'Orbix') : 'Você',
              style: TextStyle(
                color: daOrbix ? neu.accent : neu.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              mensagem.body,
              style: TextStyle(color: neu.ink, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
