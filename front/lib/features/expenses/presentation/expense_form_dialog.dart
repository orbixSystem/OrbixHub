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
Future<bool> showExpenseFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Expense? atual,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _FormDialog(atual: atual),
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
  const _FormDialog({this.atual});

  final Expense? atual;

  @override
  ConsumerState<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends ConsumerState<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _descCtrl =
      TextEditingController(text: widget.atual?.description ?? '');
  late final _valorCtrl = TextEditingController(
    text: (widget.atual?.temValor ?? false)
        ? widget.atual!.amount.toStringAsFixed(2).replaceAll('.', ',')
        : '',
  );
  late final _obsCtrl = TextEditingController(text: widget.atual?.notes ?? '');
  late final _fornecedorCtrl =
      TextEditingController(text: widget.atual?.supplierName ?? '');
  late final _docCtrl =
      TextEditingController(text: formatCnpj(widget.atual?.supplierDoc));

  late DateTime _vencimento = widget.atual?.vencimento ?? DateTime.now();
  late String? _categoriaId = widget.atual?.categoryId;
  late _Tipo _tipo = _tipoDe(widget.atual);
  int _parcelas = 2;
  bool _salvando = false;

  /// Etapa 1 = escolher o tipo. Na EDIÇÃO já começa na 2: o tipo de uma conta
  /// lançada não muda (o backend não aceita reparcelar nem transformar avulsa em
  /// fixa), e mostrar a escolha sugeriria que muda.
  late bool _escolhendoTipo = widget.atual == null;

  /// Fornecedor JÁ PREENCHIDO na conta que está sendo editada.
  ///
  /// Mantém a seção visível mesmo que a categoria não peça fornecedor — dado
  /// gravado que a tela esconde é dado que ninguém consegue corrigir nem apagar.
  late final bool _tinhaFornecedor =
      (widget.atual?.supplierName ?? widget.atual?.supplierDoc) != null;

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

    // Vazio = "valor a confirmar" (grava 0). Não é erro de preenchimento: a
    // conta de luz existe antes de a fatura chegar.
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
      title: _editando ? 'Editar despesa' : 'Nova despesa',
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
                  label: _tipo == _Tipo.parcelada ? 'Valor total *' : 'Valor',
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
                      ? 'O valor da COMPRA inteira — dividimos nas parcelas.'
                      : 'Deixe vazio se ainda não sabe — dá para preencher ao pagar.',
                  validator: (v) {
                    if (_tipo != _Tipo.parcelada) return null;
                    // Parcelar "a confirmar" não tem como: sem total não há o
                    // que dividir. O backend também recusa.
                    if (_valorDigitado <= 0) {
                      return 'Informe o valor total para parcelar.';
                    }
                    return null;
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
