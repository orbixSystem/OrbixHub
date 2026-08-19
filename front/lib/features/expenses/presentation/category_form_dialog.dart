import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../domain/expense_models.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';

/// Paleta oferecida para a categoria.
///
/// Lista curta de propósito: cor de categoria serve para RECONHECER a conta de
/// relance, e trinta tons parecidos atrapalham isso mais do que ajudam. São hex
/// `#RRGGBB` porque é o formato que o backend valida.
const _paleta = <String>[
  '#F97316', // laranja
  '#EAB308', // amarelo
  '#38BDF8', // azul claro
  '#8B5CF6', // violeta
  '#06B6D4', // ciano
  '#22C55E', // verde
  '#EF4444', // vermelho
  '#EC4899', // rosa
  '#6B7280', // cinza (default do servidor)
];

/// Cria uma categoria de despesa. Devolve a categoria criada, ou `null` se o
/// usuário desistiu.
Future<ExpenseCategory?> showCategoryFormDialog(BuildContext context) =>
    showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => const _CategoryFormDialog(),
    );

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog();

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _icone = 'outros';
  String _cor = '#6B7280';

  /// Esta categoria tem fornecedor do outro lado?
  ///
  /// Começa DESLIGADO: a maioria das despesas de oficina (aluguel, luz, imposto,
  /// salário) não tem fornecedor, e o campo aparecia em todas — era ruído em
  /// quase todo lançamento.
  bool _temFornecedor = false;
  bool _salvando = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final criada = await ref.read(expensesRepositoryProvider).criarCategoria(
            name: _nameCtrl.text.trim(),
            icon: _icone,
            color: _cor,
            tracksSupplier: _temFornecedor,
          );
      // Invalida a listagem do mês: ela é quem carrega as categorias que viram
      // chips no formulário de despesa.
      ref.invalidate(despesasDoMesProvider);
      if (!mounted) return;
      Navigator.pop(context, criada);
    } on AppException catch (e) {
      // Nome repetido volta 409 do servidor — mostrar a mensagem dele é melhor
      // que traduzir: ela já diz qual nome colidiu.
      if (!mounted) return;
      setState(() => _salvando = false);
      showNeuErrorOn(messenger, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuDialog(
      title: 'Nova categoria',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context),
        ),
        NeuButton(
          label: 'Criar',
          loading: _salvando,
          onPressed: _salvando ? null : _salvar,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeuTextField(
              label: 'Nome *',
              controller: _nameCtrl,
              hint: 'Contador, Seguro, Software…',
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              // Mesmo mínimo do backend (2): validar aqui evita uma ida ao
              // servidor para receber a mesma recusa.
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Informe um nome.' : null,
              onFieldSubmitted: (_) => _salvando ? null : _salvar(),
            ),
            const SizedBox(height: 16),
            _Rotulo(texto: 'Ícone'),
            const SizedBox(height: 8),
            // Só as chaves que o backend aceita (derivadas do mapa de ícones) —
            // uma chave inventada seria recusada na API.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chave in chavesDeIcone)
                  _OpcaoIcone(
                    chave: chave,
                    cor: corHex(_cor),
                    selecionado: chave == _icone,
                    onTap: _salvando
                        ? null
                        : () => setState(() => _icone = chave),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Rotulo(texto: 'Cor'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _paleta)
                  _OpcaoCor(
                    hex: hex,
                    selecionada: hex == _cor,
                    onTap: _salvando ? null : () => setState(() => _cor = hex),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // O switch que decide se o cadastro de despesa vai pedir fornecedor
            // nesta categoria. Fica aqui, junto do nome, porque é característica
            // da categoria — e não uma regra escondida no código do formulário.
            // O Material transparente NÃO é decoração: ListTile pinta fundo e
            // splash no Material mais próximo, e aqui o ancestral seria o do
            // Dialog — com o NeuSurface (DecoratedBox colorido) no meio. Isso
            // dispara assert do framework e engoliria o splash. Dar um Material
            // próprio ao tile resolve os dois. `transparency` para não repintar
            // fundo por cima da superfície neu.
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                value: _temFornecedor,
                onChanged: _salvando
                    ? null
                    : (v) => setState(() => _temFornecedor = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Tem fornecedor',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _temFornecedor
                      ? 'O cadastro vai pedir CNPJ e nome do fornecedor.'
                      : 'Para contas sem fornecedor (aluguel, imposto, salário).',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Prévia: mostra o chip exatamente como ele vai aparecer na lista de
            // despesas, para a escolha de ícone+cor não ser às cegas.
            Row(
              children: [
                Text(
                  'Prévia: ',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
                _Previa(
                  nome: _nameCtrl.text.trim().isEmpty
                      ? 'Categoria'
                      : _nameCtrl.text.trim(),
                  icone: _icone,
                  cor: _cor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          texto,
          style: TextStyle(
            color: context.neu.inkMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _OpcaoIcone extends StatelessWidget {
  const _OpcaoIcone({
    required this.chave,
    required this.cor,
    required this.selecionado,
    required this.onTap,
  });

  final String chave;
  final Color cor;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Tooltip(
      message: chave,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selecionado ? cor.withValues(alpha: .18) : neu.base,
            border: Border.all(
              color: selecionado ? cor : neu.line,
              width: selecionado ? 1.6 : 1,
            ),
          ),
          child: Icon(
            iconeDaCategoria(chave),
            size: 20,
            color: selecionado ? cor : neu.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _OpcaoCor extends StatelessWidget {
  const _OpcaoCor({
    required this.hex,
    required this.selecionada,
    required this.onTap,
  });

  final String hex;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = corHex(hex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cor,
          border: Border.all(
            color: selecionada ? context.neu.ink : Colors.transparent,
            width: 2.4,
          ),
        ),
        // Confirmação por ÍCONE, não só pela borda: quem não distingue bem cor
        // precisa de outro sinal de qual está escolhida.
        child: selecionada
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _Previa extends StatelessWidget {
  const _Previa({required this.nome, required this.icone, required this.cor});

  final String nome;
  final String icone;
  final String cor;

  @override
  Widget build(BuildContext context) {
    final c = corHex(cor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconeDaCategoria(icone), size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            nome,
            style: TextStyle(
              color: context.neu.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
