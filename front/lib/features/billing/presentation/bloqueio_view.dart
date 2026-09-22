import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';

/// O aviso de bloqueio de escrita já foi lido nesta sessão?
///
/// Vive fora da tela porque a casca se reconstrói a cada navegação: guardado
/// num `setState`, o aviso reapareceria a cada clique no menu e o sistema
/// viraria inutilizável. Volta a `false` quando o app é aberto de novo — o
/// lembrete é diário, não permanente.
final avisoDeEscritaLidoProvider =
    NotifierProvider<AvisoDeEscritaLido, bool>(AvisoDeEscritaLido.new);

class AvisoDeEscritaLido extends Notifier<bool> {
  @override
  bool build() => false;

  void marcarLido() => state = true;
}

final _dataFmt = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');

/// A data que EXPLICA o bloqueio — quando existe uma.
///
/// `acessoAte` quer dizer "acesso pago até". Ela só explica um bloqueio se foi
/// ela que o causou, isto é, se já passou. Bloqueio posto à mão pela Orbix não
/// tem data para acabar: acaba quando alguém libera.
///
/// Por isso uma data no FUTURO não vira texto aqui. Ela dizia "O acesso vence
/// em 12 de outubro" na mesma tela que anuncia "Acesso bloqueado" — o cliente
/// lia que ainda tem três semanas e ficava esperando uma data que não ia
/// destravar nada.
String? _oQueVenceu(DateTime? d) {
  if (d == null) return null;
  final local = d.toLocal();
  if (local.isAfter(DateTime.now())) return null;
  return 'O acesso venceu em ${_dataFmt.format(local)}.';
}

/// "venceu há 3 dias" — só quando venceu mesmo. Ver [_oQueVenceu].
String? _prazo(DateTime? d) {
  if (d == null) return null;
  final dias = d.toLocal().difference(DateTime.now()).inHours ~/ 24;
  if (dias > 0) return null;
  if (dias == 0) return 'vence hoje';
  final n = -dias;
  return n == 1 ? 'venceu ontem' : 'venceu há $n dias';
}

/// Tela cheia quando o ambiente está completamente bloqueado.
///
/// Substitui a casca inteira — sem menu, sem atalho, sem "continuar". Deixar
/// navegar daria 403 em cada tela, e a pessoa passaria a tarde tentando
/// descobrir o que quebrou em vez de resolver o pagamento.
class BloqueioTotalView extends ConsumerWidget {
  const BloqueioTotalView({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final venceu = _oQueVenceu(me.assinatura?.acessoAte);

    return _Moldura(
      cor: neu.danger,
      tinta: neu.dangerTint,
      icone: Icons.lock_rounded,
      titulo: 'Acesso bloqueado',
      empresa: me.activeTenant?.name,
      texto:
          'O acesso da sua empresa ao OrbixHub está suspenso e nenhuma área do '
          'sistema está disponível no momento.',
      detalhe: venceu,
      rodape:
          'Seus dados continuam guardados e voltam exatamente como estavam '
          'assim que o acesso for liberado. Fale com a Orbix para regularizar.',
      acoes: [
        NeuButton(
          label: 'Sair',
          icon: Icons.logout_rounded,
          kind: NeuButtonKind.secondary,
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}

/// Aviso de bloqueio de escrita — com saída.
///
/// Diferente do bloqueio total, aqui o sistema ainda serve para consultar: a
/// oficina precisa saber o telefone do cliente e o que tem em estoque mesmo
/// devendo. Por isso a tela avisa e sai da frente; quem insiste em não ver o
/// problema tem a faixa fixa no topo lembrando.
class AvisoDeEscritaView extends ConsumerWidget {
  const AvisoDeEscritaView({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final venceu = _oQueVenceu(me.assinatura?.acessoAte);

    return _Moldura(
      cor: neu.warning,
      tinta: neu.warningTint,
      icone: Icons.edit_off_rounded,
      titulo: 'Sistema em modo consulta',
      empresa: me.activeTenant?.name,
      texto:
          'Seu ambiente está em modo consulta. Você continua vendo tudo — '
          'ordens, clientes, estoque, relatórios —, mas não dá para criar nem '
          'alterar nada até o pagamento ser confirmado.',
      detalhe: venceu,
      // A carência só existe depois de um VENCIMENTO. Num bloqueio posto à mão
      // não há contagem correndo, e prometer uma assusta sem informar.
      rodape: venceu == null
          ? 'Fale com a Orbix para liberar.'
          : 'Depois do prazo de tolerância o sistema é bloqueado por completo. '
                'Fale com a Orbix para liberar.',
      acoes: [
        NeuButton(
          label: 'Entendi, continuar',
          icon: Icons.arrow_forward_rounded,
          onPressed: () =>
              ref.read(avisoDeEscritaLidoProvider.notifier).marcarLido(),
        ),
      ],
    );
  }
}

/// Faixa fixa no topo enquanto se navega com escrita bloqueada.
///
/// Mesma lógica da faixa de sessão de suporte: impossível de fechar. Descobrir
/// o bloqueio só ao tentar salvar uma OS de vinte itens é o pior momento
/// possível para descobrir.
class FaixaDeBloqueio extends ConsumerWidget {
  const FaixaDeBloqueio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).meOrNull;
    if (me == null || !me.somenteLeitura) return const SizedBox.shrink();

    final neu = context.neu;
    final prazo = _prazo(me.assinatura?.acessoAte);

    // Fundo na TINTA e texto na cor forte — `neu.warning` é cor de tinta, não
    // de fundo: usado como fundo, engolia o próprio texto.
    return Material(
      color: neu.warningTint,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: neu.warning, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.edit_off_rounded, size: 18, color: neu.warning),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                prazo == null
                    ? 'Modo consulta — você pode ver tudo, mas não salvar '
                          'alterações.'
                    : 'Modo consulta — o acesso $prazo. Você pode ver tudo, '
                          'mas não salvar alterações.',
                style: TextStyle(
                  color: neu.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A moldura comum das duas telas: um cartão só, centralizado, sem nada em
/// volta que sugira que existe outro caminho.
class _Moldura extends StatelessWidget {
  const _Moldura({
    required this.cor,
    required this.tinta,
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.rodape,
    required this.acoes,
    this.empresa,
    this.detalhe,
  });

  final Color cor;
  final Color tinta;
  final IconData icone;
  final String titulo;
  final String? empresa;
  final String texto;
  final String? detalhe;
  final String rodape;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    return Scaffold(
      backgroundColor: neu.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: NeuSurface(
                radius: NeuTokens.rPanel,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // O sinal de estado vem antes do texto: quem abre o app
                    // entende a gravidade antes de ler a primeira palavra.
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: tinta,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icone, size: 42, color: cor),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (empresa != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        empresa!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: neu.inkFaint,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: neu.inkMuted,
                        fontSize: 15.5,
                        height: 1.5,
                      ),
                    ),
                    if (detalhe != null) ...[
                      const SizedBox(height: 18),
                      NeuSurface(
                        elevation: NeuElevation.flat,
                        radius: NeuTokens.rField,
                        color: tinta,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 18,
                              color: cor,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                detalhe!,
                                style: TextStyle(
                                  color: neu.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ...acoes,
                    const SizedBox(height: 20),
                    Text(
                      rodape,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: neu.inkFaint,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
