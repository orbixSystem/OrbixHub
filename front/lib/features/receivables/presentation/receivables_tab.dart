import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import 'receivables_providers.dart';
import 'widgets/debtor_tile.dart';
import 'widgets/pending_settlement.dart';

/// Aba "Fiado" do Caixa — controle de contas a receber.
///
/// Responde três perguntas, nesta ordem: quanto a oficina tem na rua, quem deve,
/// e o que exatamente cada um deve. O drill-down abre os títulos separados (cada
/// OS/venda com seus itens), porque "o João me deve R$ 680" só é acionável
/// quando se sabe de quais serviços.
///
/// RECEBER não é uma operação própria: é um lançamento no caixa apontando para a
/// venda/OS, que já aceita valor parcial — a mesma porta usada pelo "Receber OS".
class ReceivablesTab extends ConsumerStatefulWidget {
  const ReceivablesTab({super.key, required this.canWrite});

  /// `cashier.write` — sem isso a aba é só leitura (não oferece receber).
  final bool canWrite;

  @override
  ConsumerState<ReceivablesTab> createState() => _ReceivablesTabState();
}

/// Quantos devedores por página. A carteira chega INTEIRA num payload (o
/// backend agrega OS + vendas em memória, porque fiado não tem tabela própria),
/// então buscar e paginar aqui não é preguiça: é onde o dado está. Busca no
/// servidor exigiria refazer aquela agregação.
const _porPagina = 20;

/// Normaliza para busca: minúsculas e sem acento. Quem procura "jose" precisa
/// achar "José" — exigir o acento certo transforma a busca em adivinhação.
String _normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    buf.write(i >= 0 ? para[i].toLowerCase() : ch);
  }
  return buf.toString();
}

class _ReceivablesTabState extends ConsumerState<ReceivablesTab> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  int _pagina = 0;

  bool get canWrite => widget.canWrite;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offline a carteira é DERIVADA do espelho local (OS + venda + recebimentos)
    // pelo `LocalFirstReceivablesRepository` — quem observa a conexão para
    // recarregar na virada é o próprio `debtorsProvider`.
    final async = ref.watch(debtorsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Erro(
        message: '$e',
        onRetry: () => ref.invalidate(debtorsProvider),
      ),
      data: (page) {
        final pendentes = page.pendingSettlement;
        if (page.items.isEmpty) {
          // Sem fiado nenhum a lista fica vazia — mas o aviso de "entregue e
          // não acertado" TEM de aparecer mesmo assim, senão a oficina que
          // esqueceu de passar 3 OS pelo caixa não vê nada em lugar algum.
          return ListView(
            children: [
              if (pendentes.count > 0) ...[
                AvisoPendenteAcerto(pendentes: pendentes),
                const SizedBox(height: 20),
              ],
              const NeuEmptyState(
                icon: Icons.handshake_outlined,
                title: 'Nenhum fiado em aberto',
                message: 'Vendas e OS com saldo a receber aparecem aqui, '
                    'agrupadas por cliente.',
              ),
            ],
          );
        }
        final termo = _normalizar(_busca.trim());
        final filtrados = termo.isEmpty
            ? page.items
            : page.items
                .where((d) => _normalizar(d.customerName).contains(termo))
                .toList();

        // O total "na rua" segue o que está À VISTA: filtrar e manter o total
        // geral faria a soma não bater com a lista, e alguém ia conferir.
        final totalVisivel = termo.isEmpty
            ? page.totalDue
            : filtrados.fold<double>(0, (a, d) => a + d.totalDue.toDouble());

        final paginas = (filtrados.length / _porPagina).ceil();
        // Filtrar pode encurtar a lista abaixo da página atual: sem este clamp
        // a tela ficaria vazia com resultados existindo.
        final paginaAtual = _pagina >= paginas ? 0 : _pagina;
        final inicio = paginaAtual * _porPagina;
        final visiveis = filtrados.skip(inicio).take(_porPagina).toList();

        return ListView(
          children: [
            _TotalNaRua(total: totalVisivel, devedores: filtrados.length),
            if (pendentes.count > 0) ...[
              const SizedBox(height: 12),
              AvisoPendenteAcerto(pendentes: pendentes),
            ],
            if (page.truncated) ...[
              const SizedBox(height: 12),
              const _AvisoTruncado(),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Quem deve',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (filtrados.length > _porPagina)
                  Text(
                    '${inicio + 1}–${inicio + visiveis.length} de '
                    '${filtrados.length}',
                    style: TextStyle(
                        color: context.neu.inkMuted, fontSize: 14),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            NeuTextField(
              label: 'Buscar cliente',
              controller: _buscaCtrl,
              hint: 'Nome do cliente',
              prefixIcon: Icons.search_rounded,
              onChanged: (v) => setState(() {
                _busca = v;
                _pagina = 0; // termo novo recomeça da primeira página
              }),
            ),
            const SizedBox(height: 12),
            if (visiveis.isEmpty)
              NeuEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Ninguém encontrado',
                message: 'Nenhum devedor com "${_busca.trim()}" no nome.',
              )
            else
              for (final d in visiveis)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DebtorTile(debtor: d, canWrite: canWrite),
                ),
            if (paginas > 1)
              _Paginacao(
                pagina: paginaAtual,
                paginas: paginas,
                onIr: (p) => setState(() => _pagina = p),
              ),
          ],
        );
      },
    );
  }
}

/// Navegação entre páginas de devedores. Só aparece quando há mais de uma —
/// controle de paginação numa lista de uma página é ruído que sugere que existe
/// mais coisa escondida.
class _Paginacao extends StatelessWidget {
  const _Paginacao({
    required this.pagina,
    required this.paginas,
    required this.onIr,
  });

  final int pagina;
  final int paginas;
  final ValueChanged<int> onIr;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // No celular os dois rótulos por extenso mais o contador não cabem lado a
    // lado: "Anterior" + "1 / 12" + "Próxima" estoura a largura e o Row corta.
    // Ali os botões viram só seta — o contador no meio já diz onde se está.
    final estreito = context.isMobile;
    final contador = Padding(
      padding: EdgeInsets.symmetric(horizontal: estreito ? 10 : 14),
      child: Text(
        '${pagina + 1} / $paginas',
        style: TextStyle(
          color: neu.ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Página anterior',
            child: NeuButton(
              label: estreito ? '' : 'Anterior',
              icon: Icons.chevron_left_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: pagina > 0 ? () => onIr(pagina - 1) : null,
            ),
          ),
          contador,
          Tooltip(
            message: 'Próxima página',
            child: NeuButton(
              label: estreito ? '' : 'Próxima',
              icon: Icons.chevron_right_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: pagina < paginas - 1 ? () => onIr(pagina + 1) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quanto a oficina tem "na rua" — o número que o dono quer ver primeiro.
class _TotalNaRua extends StatelessWidget {
  const _TotalNaRua({required this.total, required this.devedores});

  final num total;
  final int devedores;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: neu.warningTint,
              borderRadius: BorderRadius.circular(NeuTokens.rField),
            ),
            child: Icon(Icons.handshake_outlined, color: neu.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A receber',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(total),
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  devedores == 1
                      ? 'de 1 cliente'
                      : 'de $devedores clientes',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoTruncado extends StatelessWidget {
  const _AvisoTruncado();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: neu.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A carteira é grande e esta lista está parcial — há fiados '
              'não exibidos. Receba os títulos listados para revelar os '
              'demais.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
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
