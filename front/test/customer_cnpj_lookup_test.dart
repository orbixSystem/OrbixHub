import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';
import 'package:orbixhub_front/features/customers/presentation/customer_form_dialog.dart';

import 'support/online_conn.dart';

/// Cliente PJ: buscar pelo CNPJ preenche o que a Receita já sabe.
///
/// A regra que estes testes protegem: a consulta NÃO sobrescreve o que o usuário
/// digitou. Se ele escreveu um nome comercial ou um telefone de contato
/// específico, preencher por cima destruiria a informação melhor. `email` quase
/// sempre vem vazio da base pública — é esperado, não erro.

class _RepoCnpj extends FakeCustomersRepository {
  _RepoCnpj({this.empresa});

  final CnpjEmpresa? empresa;
  var consultas = 0;

  @override
  Future<CnpjEmpresa> lookupCnpj(String cnpj) async {
    consultas++;
    return empresa ??
        const CnpjEmpresa(
          razaoSocial: 'OPEN KNOWLEDGE BRASIL',
          nomeFantasia: 'REDE PELO CONHECIMENTO LIVRE',
          situacao: 'ATIVA',
          telefone: '1123851939',
          logradouro: 'PAULISTA 37',
          bairro: 'BELA VISTA',
          municipio: 'SAO PAULO',
          uf: 'SP',
        );
  }
}

/// Índices dos campos do formulário (ordem de montagem): 0 nome, 1 documento,
/// 2 telefone, 3 e-mail, 4 endereço.
const _nome = 0, _documento = 1, _telefone = 2, _email = 3, _endereco = 4;

String _texto(WidgetTester t, int i) =>
    t.widget<TextFormField>(find.byType(TextFormField).at(i)).controller!.text;

Future<void> _abrirPj(WidgetTester tester, FakeCustomersRepository repo) async {
  tester.view.physicalSize = const Size(1300, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      onlineConnOverride,
      customersRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: CustomerFormDialog(documentRequired: false),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pessoa jurídica').last);
  await tester.pumpAndSettle();
}

/// O botão é SÓ ÍCONE (como o de placa), para não roubar largura da linha do
/// documento — por isso o finder é pelo ícone, não por texto.
Finder get _buscar => find.byIcon(Icons.manage_search_rounded);

NeuIconButton _botaoBuscar(WidgetTester t) =>
    t.widget<NeuIconButton>(find.ancestor(
      of: _buscar,
      matching: find.byType(NeuIconButton),
    ));

void main() {
  testWidgets('o botão de busca só aparece em Pessoa jurídica', (tester) async {
    final repo = _RepoCnpj();
    tester.view.physicalSize = const Size(1300, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        onlineConnOverride,
        customersRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: CustomerFormDialog(documentRequired: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_buscar, findsNothing, reason: 'nasce como PF');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoa jurídica').last);
    await tester.pumpAndSettle();

    expect(_buscar, findsOneWidget);
  });

  testWidgets('CNPJ incompleto deixa o Buscar desabilitado', (tester) async {
    final repo = _RepoCnpj();
    await _abrirPj(tester, repo);

    await tester.enterText(find.byType(TextFormField).at(_documento), '1913124');
    await tester.pumpAndSettle();

    expect(_botaoBuscar(tester).onPressed, isNull,
        reason: 'consultar com CNPJ parcial só gastaria requisição');
    expect(repo.consultas, 0);
  });

  testWidgets('CNPJ completo busca e preenche nome, telefone e endereço',
      (tester) async {
    final repo = _RepoCnpj();
    await _abrirPj(tester, repo);

    await tester.enterText(
        find.byType(TextFormField).at(_documento), '19131243000197');
    await tester.pumpAndSettle();
    expect(_botaoBuscar(tester).onPressed, isNotNull);

    await tester.tap(_buscar);
    await tester.pumpAndSettle();

    expect(repo.consultas, 1);
    // Nome FANTASIA tem preferência: é como o cliente é conhecido no balcão.
    expect(_texto(tester, _nome), 'REDE PELO CONHECIMENTO LIVRE');
    expect(_texto(tester, _telefone), contains('2385'));
    expect(_texto(tester, _endereco), contains('SAO PAULO'));
    // Sem e-mail na Receita: o campo fica em branco, sem erro na tela.
    expect(_texto(tester, _email), isEmpty);
  });

  testWidgets('sem nome fantasia, usa a razão social', (tester) async {
    final repo = _RepoCnpj(
      empresa: const CnpjEmpresa(razaoSocial: 'ACME LTDA', nomeFantasia: ''),
    );
    await _abrirPj(tester, repo);
    await tester.enterText(
        find.byType(TextFormField).at(_documento), '19131243000197');
    await tester.pumpAndSettle();
    await tester.tap(_buscar);
    await tester.pumpAndSettle();

    expect(_texto(tester, _nome), 'ACME LTDA');
  });

  testWidgets('NÃO sobrescreve o que o usuário já digitou', (tester) async {
    final repo = _RepoCnpj();
    await _abrirPj(tester, repo);

    await tester.enterText(find.byType(TextFormField).at(_nome), 'Meu apelido');
    await tester.enterText(
        find.byType(TextFormField).at(_telefone), '(11) 90000-0000');
    await tester.enterText(
        find.byType(TextFormField).at(_documento), '19131243000197');
    await tester.pumpAndSettle();
    await tester.tap(_buscar);
    await tester.pumpAndSettle();

    expect(_texto(tester, _nome), 'Meu apelido');
    expect(_texto(tester, _telefone), '(11) 90000-0000');
    // O que estava vazio, sim, é preenchido.
    expect(_texto(tester, _endereco), contains('SAO PAULO'));
  });

  testWidgets('situação irregular avisa, mas não impede', (tester) async {
    final repo = _RepoCnpj(
      empresa: const CnpjEmpresa(razaoSocial: 'X LTDA', situacao: 'BAIXADA'),
    );
    await _abrirPj(tester, repo);
    await tester.enterText(
        find.byType(TextFormField).at(_documento), '19131243000197');
    await tester.pumpAndSettle();
    await tester.tap(_buscar);
    await tester.pumpAndSettle();

    expect(find.textContaining('BAIXADA'), findsOneWidget);
    expect(_texto(tester, _nome), 'X LTDA', reason: 'preenche mesmo assim');
  });
}
