import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/expense_installments.dart';
import '../domain/expense_models.dart';
import 'category_form_dialog.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';

/// Formulário de uma conta a pagar. Devolve `true` quando gravou.
///
/// [atual] = EDITAR aquela conta. [modelo] = criar uma NOVA usando a conta como
/// molde (o "Duplicar" da lista). Os dois são a mesma tela, mas não a mesma
/// operação, e é por isso que são parâmetros distintos: antes o duplicar mandava
/// a conta em `atual` com o id apagado, o formulário via `atual != null`, entrava
/// em modo edição e salvava com `PATCH /expenses/` sem id — 404 na cara da
/// cliente. Quem decide criar-ou-editar não pode ser um campo esvaziado.
///
/// **[modelo] não tem chamador hoje**: o "Duplicar" foi desligado a pedido do
/// dono do produto e está comentado em `expenses_screen.dart` (procure por
/// `DUPLICAR`). O suporte aqui é mantido de propósito — está correto e testado
/// pelo analisador, e reativar a função é só descomentar de lá. Não remova isto
/// achando que é código morto sem antes conferir aquele trecho.
/// A compra parcelada a que uma conta pertence — o que o formulário precisa
/// saber para editar o TOTAL em vez do valor da parcela.
///
/// `Expense` sozinho não responde isso: ele guarda o valor DELE, e o total é a
/// soma das irmãs, que vive fora dele (no detalhe ou no resumo do grupo). Quem
/// abre o formulário já tem esse número em mãos, então ele é passado em vez de
/// buscado de novo.
typedef CompraParcelada = ({num total, int pagas});

Future<bool> showExpenseFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Expense? atual,
  Expense? modelo,
  CompraParcelada? compra,
}) async {
  assert(
    atual == null || modelo == null,
    'atual (editar) e modelo (duplicar) são excludentes.',
  );
  assert(
    !(atual?.parcelada ?? false) || compra != null,
    'editar parcela exige `compra` — sem o total, o campo de valor mostraria o '
    'valor da parcela e a edição gravaria a compra inteira com ele.',
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _FormDialog(atual: atual, modelo: modelo, compra: compra),
  );
  return ok ?? false;
}

/// Os três tipos de despesa, que antes viviam num switch escondido chamado
/// "Repete todo mês".
///
/// Virou ESCOLHA EXPLÍCITA em duas etapas porque a diferença entre eles muda o
/// que a conta significa — e o dono pediu que ficasse claro na hora do cadastro,
/// em vez de "tudo num modal numa mossoroca". Também é a distinção que o banco
/// impõe (avulsa XOR fixa XOR parcelada).
enum _Tipo {
  avulsa('Uma vez', Icons.receipt_long_outlined, 'Pagamento único: um boleto, uma nota.'),
  fixa('Todo mês', Icons.autorenew_rounded,
      'Aluguel, internet, salários. As próximas aparecem sozinhas.'),
  parcelada('Parcelada', Icons.view_week_outlined,
      'Uma compra dividida em vezes. Ex.: compressor em 6x.');

  const _Tipo(this.rotulo, this.icone, this.explicacao);

  final String rotulo;
  final IconData icone;
  final String explicacao;
}

class _FormDialog extends ConsumerStatefulWidget {
  const _FormDialog({this.atual, this.modelo, this.compra});

  /// A conta sendo EDITADA. `null` quando é criação.
  final Expense? atual;

  /// A conta usada como MOLDE numa duplicação. Preenche os campos, mas a
  /// operação continua sendo criação.
  final Expense? modelo;

  /// A compra parcelada de [atual], quando ela é uma parcela.
  final CompraParcelada? compra;

  @override
  ConsumerState<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends ConsumerState<_FormDialog> {
  final _formKey = GlobalKey<FormState>();

  /// De onde vêm os valores iniciais: a conta em edição ou o molde da cópia. Só
  /// preenchimento — quem decide criar-ou-editar é [_editando], que olha apenas
  /// `atual`.
  Expense? get _origem => widget.atual ?? widget.modelo;

  late final _descCtrl =
      TextEditingController(text: _origem?.description ?? '');
  /// Numa parcela em edição o campo abre com o TOTAL DA COMPRA, não com o valor
  /// da parcela: era o bug relatado — a compra de R$ 1.000 em 5x abria com
  /// R$ 200, e salvar reescrevia a dívida inteira com o valor de uma fatia.
  late final _valorCtrl = TextEditingController(text: _valorInicial());

  String _valorInicial() {
    final compra = widget.compra;
    if (_editando && compra != null) return _comoTexto(compra.total);
    final origem = _origem;
    if (origem?.temValor ?? false) return _comoTexto(origem!.amount);
    return '';
  }

  static String _comoTexto(num v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  /// Quantas parcelas o rateio vai dividir ao salvar: as EM ABERTO. As pagas já
  /// saíram do caixa e o servidor não mexe no valor delas.
  int get _parcelasEmAberto {
    final compra = widget.compra;
    final total = widget.atual?.installmentTotal ?? 0;
    if (compra == null) return total;
    return total - compra.pagas;
  }
  late final _obsCtrl = TextEditingController(text: _origem?.notes ?? '');
  late final _fornecedorCtrl =
      TextEditingController(text: _origem?.supplierName ?? '');
  late final _docCtrl =
      TextEditingController(text: formatCnpj(_origem?.supplierDoc));

  late DateTime _vencimento = _origem?.vencimento ?? DateTime.now();
  late String? _categoriaId = _origem?.categoryId;

  /// Tipo da conta. A cópia nasce AVULSA mesmo quando o molde é fixa ou
  /// parcelada: "Duplicar" não pode, num toque de menu, criar uma regra que
  /// repete para sempre nem uma dívida nova em 6 vezes. Além disso o valor
  /// copiado de uma parcela é o da PARCELA, e ele apareceria sob o rótulo "valor
  /// total" — número errado no campo que mais importa. Quem quiser outro tipo usa
  /// "Voltar" e escolhe, que na criação continua disponível.
  late _Tipo _tipo = widget.modelo != null ? _Tipo.avulsa : _tipoDe(widget.atual);
  int _parcelas = 2;
  bool _salvando = false;

  /// Etapa 1 = escolher o tipo. Na EDIÇÃO já começa na 2: o tipo de uma conta
  /// lançada não muda (o backend não aceita reparcelar nem transformar avulsa em
  /// fixa), e mostrar a escolha sugeriria que muda. Na DUPLICAÇÃO também começa
  /// na 2 — os dados já estão preenchidos, e a promessa do menu é "mesmos dados".
  late bool _escolhendoTipo = widget.atual == null && widget.modelo == null;

  /// Fornecedor JÁ PREENCHIDO na conta de origem.
  ///
  /// Mantém a seção visível mesmo que a categoria não peça fornecedor — dado
  /// gravado que a tela esconde é dado que ninguém consegue corrigir nem apagar.
  late final bool _tinhaFornecedor =
      (_origem?.supplierName ?? _origem?.supplierDoc) != null;

  ExpenseSupplierLookup? _consultado;
  bool _consultando = false;
  String? _erroConsulta;

  bool get _editando => widget.atual != null;

  /// Esta despesa deve pedir fornecedor?
  ///
  /// Sim quando a categoria escolhida diz que tem (`tracksSupplier`), ou quando a
  /// conta em edição já tem um gravado. Sem categoria escolhida, não pede: a
  /// pergunta ainda não tem contexto.
  bool _pedeFornecedor(List<ExpenseCategory> categorias) {
    if (_tinhaFornecedor) return true;
    final id = _categoriaId;
    if (id == null) return false;
    return categorias.where((c) => c.id == id).firstOrNull?.tracksSupplier ??
        false;
  }

  static _Tipo _tipoDe(Expense? e) {
    if (e == null) return _Tipo.avulsa;
    if (e.parcelada) return _Tipo.parcelada;
    if (e.fixa) return _Tipo.fixa;
    return _Tipo.avulsa;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valorCtrl.dispose();
    _obsCtrl.dispose();
    _fornecedorCtrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  num get _valorDigitado {
    final t = _valorCtrl.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      // Janela larga: conta atrasada de meses atrás precisa poder ser lançada, e
      // boleto de fornecedor vence bem à frente.
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: _tipo == _Tipo.parcelada ? '1º vencimento' : 'Vencimento',
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (escolhida != null) setState(() => _vencimento = escolhida);
  }

  /// Consulta o CNPJ e preenche o nome do fornecedor.
  ///
  /// Falha NÃO bloqueia o cadastro: o nome é campo de texto que a pessoa digita à
  /// mão, e travar o lançamento porque a Receita não respondeu seria péssimo.
  Future<void> _consultarCnpj() async {
    final doc = normalizeCnpj(_docCtrl.text);
    if (!isValidCnpj(doc)) {
      setState(() => _erroConsulta = 'CNPJ incompleto ou inválido.');
      return;
    }
    setState(() {
      _consultando = true;
      _erroConsulta = null;
    });
    try {
      final r = await ref.read(expensesRepositoryProvider).consultarCnpj(doc);
      if (!mounted) return;
      setState(() {
        _consultado = r;
        // Só preenche se estiver vazio: quem já digitou "Fornecedor do Zé" não
        // quer ver isso ser trocado pela razão social.
        if (_fornecedorCtrl.text.trim().isEmpty) {
          _fornecedorCtrl.text = r.nomeUsual;
        }
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _erroConsulta = e.message);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    // Garantido > 0 pelo validator acima — o campo é obrigatório.
    final valor = _valorDigitado;
    final doc = normalizeCnpj(_docCtrl.text);
    final nomeForn = _fornecedorCtrl.text.trim();

    final draft = ExpenseDraft(
      description: _descCtrl.text.trim(),
      amount: valor,
      dueDate: _iso(_vencimento),
      categoryId: _categoriaId,
      notes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      limparCategoria: _categoriaId == null,
      supplierName: nomeForn.isEmpty ? null : nomeForn,
      supplierDoc: doc.isEmpty ? null : doc,
      // Edição não mexe no tipo: alterar a regra de uma conta já gerada
      // reescreveria meses que a cliente talvez já tenha conferido, e reparcelar
      // seria apagar as irmãs e recriar outras.
      limparFornecedor: _editando && nomeForn.isEmpty && doc.isEmpty,
      recorrencia: (!_editando && _tipo == _Tipo.fixa)
          ? ExpenseRecurrenceDraft(
              frequency: 'monthly',
              dayOfMonth: _vencimento.day,
            )
          : null,
      parcelas:
          (!_editando && _tipo == _Tipo.parcelada) ? _parcelas : null,
    );

    final repo = ref.read(expensesRepositoryProvider);
    try {
      if (_editando) {
        await repo.editar(widget.atual!.id, draft);
      } else {
        await repo.criar(draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      showNeuErrorSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_escolhendoTipo) return _etapaTipo();
    return _etapaDados();
  }

  // ======================= Etapa 1: o tipo =======================
  Widget _etapaTipo() {
    final neu = context.neu;
    return NeuDialog(
      title: 'Nova despesa',
      maxWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Como essa despesa se comporta?',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final t in _Tipo.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CartaoTipo(
                tipo: t,
                selecionado: _tipo == t,
                // Toque escolhe E avança: dois toques para o que é uma decisão só
                // seria atrito puro.
                onTap: () => setState(() {
                  _tipo = t;
                  _escolhendoTipo = false;
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ======================= Etapa 2: os dados =======================
  Widget _etapaDados() {
    final categorias =
        ref.watch(despesasDoMesProvider).value?.categories ?? const [];

    return NeuDialog(
      // "Duplicar" ganha título próprio: os campos vêm preenchidos com os de
      // outra conta, e sem esse aviso a tela parece uma edição — a cliente
      // acharia que está mexendo na conta original.
      title: _editando
          ? 'Editar despesa'
          : widget.modelo != null
              ? 'Duplicar despesa'
              : 'Nova despesa',
      maxWidth: 520,
      actions: [
        // "Voltar" só na criação, e só porque houve uma etapa antes.
        if (!_editando)
          NeuButton(
            label: 'Voltar',
            kind: NeuButtonKind.secondary,
            onPressed:
                _salvando ? null : () => setState(() => _escolhendoTipo = true),
          ),
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
        ),
        NeuButton(
          label: 'Salvar',
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
            _FaixaTipo(tipo: _tipo, editando: _editando),
            const SizedBox(height: 16),
            _Secao(
              titulo: 'A conta',
              icone: Icons.description_outlined,
              children: [
                NeuTextField(
                  label: 'O que é? *',
                  controller: _descCtrl,
                  hint: 'Aluguel, conta de luz, compressor…',
                  autofocus: !_editando,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 2) return 'Descreva a despesa.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                NeuTextField(
                  // Na parcelada o rótulo muda porque o número muda de
                  // significado: é o total da dívida, e o servidor rateia.
                  label:
                      _tipo == _Tipo.parcelada ? 'Valor total *' : 'Valor *',
                  controller: _valorCtrl,
                  hint: '0,00',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [DecimalInputFormatter()],
                  onChanged: (_) {
                    // Redesenha a prévia "6x de R$ 194,44" a cada tecla.
                    if (_tipo == _Tipo.parcelada) setState(() {});
                  },
                  helper: _tipo == _Tipo.parcelada
                      ? (_editando
                          ? 'O valor da COMPRA inteira — as parcelas em aberto '
                              'são recalculadas.'
                          : 'O valor da COMPRA inteira — dividimos nas parcelas.')
                      : 'Quanto a conta vai custar.',
                  // Valor OBRIGATÓRIO em qualquer tipo, por decisão do dono do
                  // produto. Antes o campo aceitava vazio e gravava 0 ("valor a
                  // confirmar"): a conta entrava na lista sem número, não somava
                  // nos totais do mês e ainda exigia digitar o valor na hora de
                  // pagar — a previsão de gasto ficava mentindo justamente para
                  // quem abre a tela para saber quanto tem a pagar.
                  //
                  // Contas antigas gravadas com 0 continuam sendo exibidas como
                  // "a confirmar"; o backend ainda aceita 0 (ver CreateExpenseDto).
                  // A obrigatoriedade é do formulário, não do contrato da API.
                  validator: (v) {
                    if (_valorDigitado > 0) return null;
                    return _tipo == _Tipo.parcelada
                        // Sem total não há o que ratear — o backend também recusa.
                        ? 'Informe o valor total para parcelar.'
                        : 'Informe o valor da despesa.';
                  },
                ),
                const SizedBox(height: 14),
                _SeletorCategoria(
                  categorias: categorias,
                  selecionada: _categoriaId,
                  onMudar: _salvando
                      ? null
                      : (id) => setState(() => _categoriaId = id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Secao(
              titulo: _tipo == _Tipo.parcelada ? 'Parcelas e vencimento' : 'Quando',
              icone: Icons.event_outlined,
              children: [
                _CampoData(
                  rotulo: switch (_tipo) {
                    _Tipo.parcelada => '1º vencimento *',
                    _Tipo.fixa => 'Primeiro vencimento *',
                    _Tipo.avulsa => 'Vence em *',
                  },
                  valor: _vencimento,
                  onTocar: _salvando ? null : _escolherData,
                ),
                if (_tipo == _Tipo.fixa && !_editando) ...[
                  const SizedBox(height: 10),
                  _Aviso(
                    icone: Icons.autorenew_rounded,
                    texto: 'Vai repetir todo dia ${_vencimento.day} — as contas '
                        'dos próximos meses aparecem sozinhas.',
                  ),
                ],
                if (_tipo == _Tipo.parcelada && !_editando) ...[
                  const SizedBox(height: 14),
                  _CampoParcelas(
                    valor: _parcelas,
                    total: _valorDigitado,
                    primeiro: _vencimento,
                    onMudar: _salvando
                        ? null
                        : (n) => setState(() => _parcelas = n),
                  ),
                ],
                // Na EDIÇÃO não há stepper (reparcelar continua proibido: mudaria
                // o número de linhas), mas a prévia do novo rateio precisa
                // existir — quem digita 1200 no lugar de 1000 quer ver em quanto
                // fica cada parcela antes de salvar.
                if (_tipo == _Tipo.parcelada && _editando) ...[
                  const SizedBox(height: 14),
                  _PreviaRerateio(
                    total: _valorDigitado,
                    emAberto: _parcelasEmAberto,
                    pagas: widget.compra?.pagas ?? 0,
                    totalDeParcelas: widget.atual?.installmentTotal ?? 0,
                  ),
                ],
              ],
            ),
            // Fornecedor SÓ nas categorias que têm um do outro lado (peças,
            // manutenção). Em Aluguel ou Energia a pergunta não faz sentido, e
            // antes ela aparecia em toda despesa — ruído em quase todo
            // lançamento. Quem decide é a categoria (switch no cadastro dela),
            // não uma lista fixa aqui: a cliente cria as próprias categorias.
            if (_pedeFornecedor(categorias)) ...[
              const SizedBox(height: 6),
              _SecaoFornecedor(
              docCtrl: _docCtrl,
              nomeCtrl: _fornecedorCtrl,
              consultando: _consultando,
              consultado: _consultado,
              erro: _erroConsulta,
              onConsultar: _salvando ? null : _consultarCnpj,
              ),
            ],
            const SizedBox(height: 6),
            _Secao(
              titulo: 'Observação',
              icone: Icons.sticky_note_2_outlined,
              children: [
                NeuTextField(
                  label: 'Anotação',
                  controller: _obsCtrl,
                  hint: 'Opcional — nº da nota, combinado com o fornecedor…',
                  maxLines: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de escolha do tipo, na etapa 1. Grande de propósito: é uma decisão,
/// não um detalhe de formulário.
class _CartaoTipo extends StatelessWidget {
  const _CartaoTipo({
    required this.tipo,
    required this.selecionado,
    required this.onTap,
  });

  final _Tipo tipo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      borderRadius: BorderRadius.circular(NeuTokens.rCard),
      onTap: onTap,
      child: NeuSurface(
        elevation: selecionado ? NeuElevation.inset : NeuElevation.raised,
        radius: NeuTokens.rCard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: neu.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tipo.icone, size: 22, color: neu.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tipo.rotulo,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tipo.explicacao,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: neu.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Faixa que lembra QUAL tipo está sendo cadastrado, na etapa 2.
///
/// Na edição ela também explica por que não há como trocar: o tipo de uma conta
/// lançada é imutável, e um campo desabilitado sem explicação parece defeito.
class _FaixaTipo extends StatelessWidget {
  const _FaixaTipo({required this.tipo, required this.editando});

  final _Tipo tipo;
  final bool editando;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(tipo.icone, size: 18, color: neu.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              editando
                  ? '${tipo.rotulo} — o tipo não muda depois de lançada'
                  : tipo.rotulo,
              style: TextStyle(
                color: neu.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco com título — é o que quebra o "modal mossoroca" em partes legíveis.
class _Secao extends StatelessWidget {
  const _Secao({
    required this.titulo,
    required this.icone,
    required this.children,
  });

  final String titulo;
  final IconData icone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Row(
              children: [
                Icon(icone, size: 15, color: neu.inkFaint),
                const SizedBox(width: 6),
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    color: neu.inkFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Número de parcelas + a prévia do rateio.
///
/// A prévia é o ponto: "6x de R$ 194,44" responde na hora a pergunta que a pessoa
/// faria depois de salvar. Usa o MESMO rateio do servidor, então o valor mostrado
/// é o valor gravado.
class _CampoParcelas extends StatelessWidget {
  const _CampoParcelas({
    required this.valor,
    required this.total,
    required this.primeiro,
    required this.onMudar,
  });

  final int valor;
  final num total;
  final DateTime primeiro;
  final ValueChanged<int>? onMudar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final valores = ratearParcelas(total, valor);
    final datas = datasDasParcelas(primeiro, valor);
    final iguais = valores.isNotEmpty &&
        valores.every((v) => v == valores.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Em quantas vezes?',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuStepperField(
          value: valor.toDouble(),
          min: 2,
          max: maxParcelas.toDouble(),
          onChanged: onMudar == null ? (_) {} : (v) => onMudar!(v.round()),
          semanticLabel: 'Número de parcelas',
        ),
        if (total > 0) ...[
          const SizedBox(height: 12),
          NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  iguais
                      ? '${valor}x de ${formatMoney(valores.first)}'
                      // Centavos de resto vão na 1ª: dizer "6x de X" quando a
                      // primeira é diferente seria impreciso justamente no valor
                      // que vai ser cobrado primeiro.
                      : '1ª de ${formatMoney(valores.first)} + '
                          '${valor - 1}x de ${formatMoney(valores[1])}',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'De ${_dm(datas.first)} até ${_dm(datas.last)} '
                  '(${datas.last.year})',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Prévia do rateio ao EDITAR o total de uma compra parcelada.
///
/// Mostra em quanto fica cada parcela em aberto com o total digitado — usando o
/// mesmo `ratearParcelas` do servidor, então o número exibido é o que vai ser
/// gravado. Quando há parcelas pagas, diz explicitamente que elas não mudam: o
/// dinheiro já saiu e está no caixa, e reescrever o valor faria a despesa
/// divergir do extrato.
class _PreviaRerateio extends StatelessWidget {
  const _PreviaRerateio({
    required this.total,
    required this.emAberto,
    required this.pagas,
    required this.totalDeParcelas,
  });

  final num total;
  final int emAberto;
  final int pagas;
  final int totalDeParcelas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (total <= 0 || emAberto <= 0) return const SizedBox.shrink();

    // O que sobra para as em aberto = total - o já comprometido nas pagas. Não
    // dá para saber o valor exato das pagas aqui (só a contagem), então a prévia
    // só é precisa quando nada foi pago; com pagas, explica em vez de chutar.
    if (pagas > 0) {
      return NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: neu.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$pagas de $totalDeParcelas parcelas já foram pagas e não mudam '
                'de valor. O que sobrar do total será dividido entre as '
                '$emAberto em aberto.',
                style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    final valores = ratearParcelas(total, emAberto);
    final iguais = valores.every((v) => v == valores.first);
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            iguais
                ? '${emAberto}x de ${formatMoney(valores.first)}'
                // Centavos de resto vão na 1ª em aberto — dizer "5x de X" com a
                // primeira diferente seria impreciso no valor cobrado primeiro.
                : '1ª de ${formatMoney(valores.first)} + '
                    '${emAberto - 1}x de ${formatMoney(valores[1])}',
            style: TextStyle(
              color: neu.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Os vencimentos e a quantidade de parcelas não mudam.',
            style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Fornecedor: CNPJ com consulta + nome. Recolhido quando vazio.
class _SecaoFornecedor extends StatelessWidget {
  const _SecaoFornecedor({
    required this.docCtrl,
    required this.nomeCtrl,
    required this.consultando,
    required this.consultado,
    required this.erro,
    required this.onConsultar,
  });

  final TextEditingController docCtrl;
  final TextEditingController nomeCtrl;
  final bool consultando;
  final ExpenseSupplierLookup? consultado;
  final String? erro;
  final VoidCallback? onConsultar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final situacao = consultado?.situacao?.toUpperCase();
    // Boleto de empresa BAIXADA é sinal clássico de golpe — avisar aqui é o
    // momento em que a informação serve para algo.
    final alerta = situacao != null && situacao != 'ATIVA';

    return _Secao(
      titulo: 'Fornecedor',
      icone: Icons.storefront_outlined,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NeuTextField(
                label: 'CNPJ',
                controller: docCtrl,
                hint: '00.000.000/0000-00',
                keyboardType: TextInputType.number,
                inputFormatters: [CnpjInputFormatter()],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              // Alinha o botão com o campo, não com o rótulo acima dele.
              padding: const EdgeInsets.only(top: 24),
              child: consultando
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : NeuIconButton(
                      icon: Icons.search_rounded,
                      tooltip: 'Buscar na Receita',
                      onPressed: onConsultar,
                    ),
            ),
          ],
        ),
        if (erro != null) ...[
          const SizedBox(height: 8),
          Text(
            erro!,
            style: TextStyle(color: neu.danger, fontSize: 12.5),
          ),
        ],
        if (consultado != null) ...[
          const SizedBox(height: 8),
          _Aviso(
            icone: alerta
                ? Icons.warning_amber_rounded
                : Icons.verified_outlined,
            cor: alerta ? neu.danger : neu.success,
            texto: alerta
                ? '${consultado!.razaoSocial} — situação $situacao na Receita.'
                : consultado!.razaoSocial,
          ),
        ],
        const SizedBox(height: 14),
        NeuTextField(
          label: 'Nome do fornecedor',
          controller: nomeCtrl,
          hint: 'Preenchido pela consulta, editável',
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

/// Linha de aviso curta, dentro de uma seção.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, this.cor});

  final IconData icone;
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final c = cor ?? neu.info;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 15, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Campo de vencimento — abre o date picker ao toque.
class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.rotulo,
    required this.valor,
    required this.onTocar,
  });

  final String rotulo;
  final DateTime valor;
  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            rotulo,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InkWell(
          onTap: onTocar,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: neu.accent),
                const SizedBox(width: 8),
                Text(
                  '${valor.day.toString().padLeft(2, '0')}/'
                  '${valor.month.toString().padLeft(2, '0')}/${valor.year}',
                  style: TextStyle(color: neu.ink, fontSize: 15),
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_outlined, size: 17, color: neu.inkFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Categorias como chips com ícone e cor — mais rápido de reconhecer que um
/// dropdown de texto, e é o mesmo vocabulário visual da lista.
class _SeletorCategoria extends StatelessWidget {
  const _SeletorCategoria({
    required this.categorias,
    required this.selecionada,
    required this.onMudar,
  });

  final List<ExpenseCategory> categorias;
  final String? selecionada;
  final ValueChanged<String?>? onMudar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // NÃO retorna vazio quando não há categoria: era o pior caso possível —
    // tenant sem categoria nenhuma não via o seletor e portanto não tinha por
    // onde criar a primeira. Agora o "+ Nova" aparece sempre.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Categoria',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in categorias)
              _ChipCategoria(
                categoria: c,
                selecionada: c.id == selecionada,
                // Tocar na já selecionada limpa: sem isso não haveria como
                // voltar para "sem categoria".
                onTap: onMudar == null
                    ? null
                    : () => onMudar!(c.id == selecionada ? null : c.id),
              ),
            // Criar sem sair do formulário: descobrir que falta a categoria
            // acontece justamente aqui, ao lançar a conta. Mandar o usuário para
            // outra tela e voltar custaria o que ele já digitou.
            if (onMudar != null) _ChipNovaCategoria(onCriada: onMudar!),
          ],
        ),
      ],
    );
  }
}

class _ChipCategoria extends StatelessWidget {
  const _ChipCategoria({
    required this.categoria,
    required this.selecionada,
    required this.onTap,
  });

  final ExpenseCategory categoria;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = corHex(categoria.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selecionada ? cor.withValues(alpha: .18) : neu.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionada ? cor : neu.line,
            width: selecionada ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconeDaCategoria(categoria.icon), size: 15, color: cor),
            const SizedBox(width: 6),
            Text(
              categoria.name,
              style: TextStyle(
                color: selecionada ? neu.ink : neu.inkMuted,
                fontSize: 13,
                fontWeight: selecionada ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip "+ Nova" que abre o formulário de categoria e JÁ SELECIONA a criada.
///
/// Selecionar sozinho é o ponto: quem cria a categoria no meio do lançamento
/// quer usá-la naquela conta — obrigar um segundo toque para escolher o que
/// acabou de nascer seria trabalho à toa.
class _ChipNovaCategoria extends StatelessWidget {
  const _ChipNovaCategoria({required this.onCriada});

  final ValueChanged<String?> onCriada;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: () async {
        final criada = await showCategoryFormDialog(context);
        if (criada != null) onCriada(criada.id);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: neu.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: neu.inkMuted),
            const SizedBox(width: 5),
            Text(
              'Nova',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
