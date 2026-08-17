import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Conteúdo (sem moldura) do seletor de templates de OS: busca no servidor com
/// paginação (`listTemplatesPage`) e devolve o [OsTemplate] escolhido pelo
/// callback [onSelected].
///
/// É um PAINEL para poder ser embutido **inline** no wizard "Nova OS" (que já é
/// um diálogo) e, na tela de detalhe, dentro de um [TemplatePickerDialog].
///
/// Quando [onCriarTemplate] é fornecido, o painel também oferece salvar os itens
/// já lançados como um template novo — pedindo o NOME num campo visível (nada é
/// salvo sem você ler o nome). O painel só COLETA o nome: quem chamou decide o
/// que fazer com ele, porque no wizard o template nasce junto com a OS e na tela
/// de detalhe ele é criado na hora.
class TemplatePickerPanel extends ConsumerStatefulWidget {
  const TemplatePickerPanel({
    super.key,
    required this.onSelected,
    required this.onCancel,
    this.onCriarTemplate,
    this.qtdItensParaSalvar = 0,
    this.maxAltura = 280,
  });

  final ValueChanged<OsTemplate> onSelected;
  final VoidCallback onCancel;

  /// Recebe o nome escolhido para o template novo. Null = sem opção de criar.
  final ValueChanged<String>? onCriarTemplate;

  /// Quantos itens seriam salvos no template novo (0 = ainda não há o que salvar).
  final int qtdItensParaSalvar;

  final double maxAltura;

  @override
  ConsumerState<TemplatePickerPanel> createState() =>
      _TemplatePickerPanelState();
}

class _TemplatePickerPanelState extends ConsumerState<TemplatePickerPanel> {
  static const _pageSize = 20;

  final _query = TextEditingController();
  final _novoNome = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<OsTemplate> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Formulário de "criar template" aberto (inline, no lugar da lista).
  bool _criando = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _novoNome.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 120) _loadMore();
  }

  /// Digitar refaz a busca do zero (com folga para não disparar por letra).
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  String? get _termo =>
      _query.text.trim().isEmpty ? null : _query.text.trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(osRepositoryProvider).listTemplatesPage(
            query: _termo,
            page: 1,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final page = await ref.read(osRepositoryProvider).listTemplatesPage(
            query: _termo,
            page: next,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = next;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } on AppException {
      // Falha ao paginar não derruba o que já está na tela.
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _abrirCriacao() {
    setState(() {
      _criando = true;
      if (_novoNome.text.trim().isEmpty) _novoNome.text = _termo ?? '';
    });
  }

  void _confirmarCriacao() {
    final nome = _novoNome.text.trim();
    if (nome.isEmpty) return;
    widget.onCriarTemplate!(nome);
  }

  @override
  Widget build(BuildContext context) {
    if (_criando) return _formularioNovo();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuTextField(
          label: 'Buscar template',
          controller: _query,
          hint: 'Nome do pacote de serviço…',
          prefixIcon: Icons.search_rounded,
          onChanged: (_) => _onQueryChanged(),
        ),
        const SizedBox(height: 14),
        _lista(),
        if (widget.onCriarTemplate != null) ...[
          const SizedBox(height: 12),
          _linhaCriar(),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: NeuButton(
            label: 'Fechar',
            kind: NeuButtonKind.secondary,
            onPressed: widget.onCancel,
          ),
        ),
      ],
    );
  }

  Widget _lista() {
    final neu = context.neu;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          _error!,
          style: TextStyle(
            color: neu.danger,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(Icons.checklist_rtl_rounded, size: 32, color: neu.inkFaint),
            const SizedBox(height: 10),
            Text(
              _termo == null
                  ? 'Nenhum template cadastrado ainda.'
                  : 'Nenhum template com esse nome.',
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Template é um pacote de peças e serviços que você monta uma vez '
              'e reaproveita em toda OS parecida.',
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxAltura),
      child: ListView.separated(
        controller: _scroll,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          return _TemplateTile(
            template: _items[i],
            onTap: () => widget.onSelected(_items[i]),
          );
        },
      ),
    );
  }

  /// Chamada para transformar o que já está lançado num template. Sem itens
  /// lançados não há o que salvar — em vez de sumir, a linha explica o caminho.
  Widget _linhaCriar() {
    final neu = context.neu;
    final temItens = widget.qtdItensParaSalvar > 0;
    final texto = temItens
        ? 'Criar template com ${widget.qtdItensParaSalvar == 1 ? "o item lançado" : "os ${widget.qtdItensParaSalvar} itens lançados"}'
        : 'Para criar um template, lance as peças e serviços aqui e depois '
            'salve o conjunto';
    return InkWell(
      onTap: temItens ? _abrirCriacao : null,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
        elevation: temItens ? NeuElevation.raised : NeuElevation.flat,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.playlist_add_rounded,
              size: 20,
              color: temItens ? neu.navy : neu.inkFaint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  color: temItens ? neu.navy : neu.inkFaint,
                  fontSize: 13.5,
                  fontWeight: temItens ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formulário do template novo: um campo de nome e o que será salvo. Fica no
  /// lugar da lista (mesmo painel) — não abre outra janela.
  Widget _formularioNovo() {
    final neu = context.neu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuTextField(
          label: 'Nome do template *',
          controller: _novoNome,
          hint: 'ex.: Revisão simples',
          prefixIcon: Icons.checklist_rounded,
          autofocus: true,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          widget.qtdItensParaSalvar == 1
              ? 'O item lançado nesta OS será salvo neste template.'
              : 'Os ${widget.qtdItensParaSalvar} itens lançados nesta OS serão '
                  'salvos neste template.',
          style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NeuButton(
              label: 'Voltar',
              kind: NeuButtonKind.secondary,
              icon: Icons.arrow_back_rounded,
              onPressed: () => setState(() => _criando = false),
            ),
            const SizedBox(width: 10),
            NeuButton(
              label: 'Salvar template',
              icon: Icons.check_rounded,
              onPressed:
                  _novoNome.text.trim().isEmpty ? null : _confirmarCriacao,
            ),
          ],
        ),
      ],
    );
  }
}

/// Moldura de diálogo em volta do [TemplatePickerPanel] — usada pela tela de
/// detalhe da OS, onde o painel abre a partir de uma TELA.
class TemplatePickerDialog extends StatelessWidget {
  const TemplatePickerDialog({
    super.key,
    this.qtdItensParaSalvar = 0,
    this.onCriarTemplate,
  });

  final int qtdItensParaSalvar;
  final ValueChanged<String>? onCriarTemplate;

  /// Abre o seletor. Resolve para o template escolhido, ou null se fechado.
  /// [onCriarTemplate] recebe o nome digitado quando o usuário pede para salvar
  /// os itens atuais como template (o diálogo fecha em seguida).
  static Future<OsTemplate?> show(
    BuildContext context, {
    int qtdItensParaSalvar = 0,
    ValueChanged<String>? onCriarTemplate,
  }) {
    return showDialog<OsTemplate>(
      context: context,
      builder: (_) => TemplatePickerDialog(
        qtdItensParaSalvar: qtdItensParaSalvar,
        onCriarTemplate: onCriarTemplate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: 'Aplicar template',
      maxWidth: context.isMobile ? 560 : 520,
      child: TemplatePickerPanel(
        qtdItensParaSalvar: qtdItensParaSalvar,
        maxAltura: 340,
        onCancel: () => Navigator.of(context).pop(),
        onSelected: (template) => Navigator.of(context).pop(template),
        onCriarTemplate: onCriarTemplate == null
            ? null
            : (nome) {
                Navigator.of(context).pop();
                onCriarTemplate!(nome);
              },
      ),
    );
  }
}

/// Um template na lista: nome, descrição, quantos itens traz e quanto soma
/// (preço corrente do estoque, calculado pelo backend).
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final OsTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final itens = template.items.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded, size: 20, color: neu.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      itens == 1 ? '1 item' : '$itens itens',
                      if (template.description?.trim().isNotEmpty ?? false)
                        template.description!.trim(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money(template.total),
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
