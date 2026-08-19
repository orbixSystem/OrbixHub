import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/order_form_dialog.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';

/// Conectividade fixa em ONLINE: sem isto o controller real reporta offline no
/// ambiente de teste e a consulta de placa fica (corretamente) inerte.
class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

/// Captura o draft enviado ao criar a OS, para asserções precisas sobre o que
/// o wizard monta (veículo novo, dados da consulta de placa...). Registra também
/// o que o wizard lança DEPOIS de criar a OS (template, itens, situação), que é
/// como tudo aquilo entra sem endpoint novo.
class _CapturingOsRepo extends FakeOsRepository {
  _CapturingOsRepo({super.customers, super.templates});

  OrderDraft? lastDraft;
  final List<String> appliedTemplates = [];
  final List<OrderItemDraft> addedItems = [];
  final List<String> statusChanges = [];

  /// Quando não-nulo, `addItem` falha com esta mensagem — para provar que a OS
  /// já criada não é desfeita por causa de um lançamento.
  String? failItemsWith;

  @override
  Future<ServiceOrder> createOrder(OrderDraft d) {
    lastDraft = d;
    return super.createOrder(d);
  }

  @override
  Future<ServiceOrder> applyTemplate(String orderId, String templateId) {
    appliedTemplates.add(templateId);
    return super.applyTemplate(orderId, templateId);
  }

  @override
  Future<ServiceOrder> addItem(String id, OrderItemDraft d) {
    addedItems.add(d);
    if (failItemsWith != null) {
      throw AppException(error: 'bad_request', message: failItemsWith!);
    }
    return super.addItem(id, d);
  }

  @override
  Future<ServiceOrder> changeStatus(String id, String status) {
    statusChanges.add(status);
    return super.changeStatus(id, status);
  }

  final List<OsTemplateDraft> createdTemplates = [];

  @override
  Future<OsTemplate> createTemplate(OsTemplateDraft draft) {
    createdTemplates.add(draft);
    return super.createTemplate(draft);
  }
}

/// Devolve a OS criada COM `public_token`, como o servidor faz (o fake padrão
/// nasce sem — é o retrato de uma OS criada offline, em que o link ainda não
/// existe).
class _TokenOsRepo extends _CapturingOsRepo {
  _TokenOsRepo({super.customers});

  @override
  Future<ServiceOrder> createOrder(OrderDraft d) async {
    final order = await super.createOrder(d);
    return order.copyWith(publicToken: 'tok-123');
  }
}

/// Abre o dialog num app mínimo e devolve o id resolvido pelo Navigator.pop.
Future<String?> _openDialog(
  WidgetTester tester,
  FakeOsRepository fake, {
  List<Override> extra = const [],
}) async {
  String? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        osRepositoryProvider.overrideWithValue(fake),
        ...extra,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = (await OrderFormDialog.show(context)) as String?;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

/// Localiza o campo editável cujo rótulo (Text visível) é [label]. Os campos do
/// design system (NeuTextField / _fieldShell) desenham o rótulo como um Text
/// irmão do campo, dentro do mesmo Column — subimos do rótulo até esse Column.
Finder _fieldByLabel(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(Column))
    .first;

/// Avança para o próximo passo do wizard.
Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NeuButton, 'Próximo'));
  await tester.pumpAndSettle();
}

/// Rola até o alvo e toca — o passo "Detalhes" é longo (itens, totais, fotos)
/// e boa parte dele nasce fora da janela do teste.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Rola até o campo de [label] e digita [text].
Future<void> _fill(WidgetTester tester, String label, String text) async {
  final field = _fieldByLabel(label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pump();
}

/// Escolhe um cliente existente e atravessa os passos Cliente e Veículo,
/// parando no passo Detalhes.
Future<void> _ateDetalhes(WidgetTester tester) async {
  await tester.enterText(_fieldByLabel('Cliente *'), 'João');
  await tester.pumpAndSettle();
  await tester.tap(find.text('João da Silva').last);
  await tester.pumpAndSettle();
  await _next(tester);
  await _next(tester); // veículo: este cliente não tem nenhum cadastrado
}

/// Adiciona um item avulso pelo painel que abre INLINE no passo (sem diálogo
/// sobre diálogo).
Future<void> _addItemAvulso(
  WidgetTester tester, {
  required String descricao,
  required String preco,
}) async {
  await _tap(tester, find.widgetWithText(NeuButton, 'Adicionar item'));
  await _tap(tester, find.text('Avulso'));
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição *'), descricao);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço unit. *'), preco);
  await tester.pump();
  await _tap(tester, find.widgetWithText(NeuButton, 'Adicionar'));
}

/// Seleciona o primeiro membro no dropdown "Responsável *" (obrigatório).
Future<void> _selectResponsavel(WidgetTester tester) async {
  final dd = find.text('— Selecione —');
  await tester.ensureVisible(dd);
  await tester.pumpAndSettle();
  await tester.tap(dd);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ana Mecânica').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cliente novo: nome habilita "Próximo" e cria a OS no fim',
      (tester) async {
    final fake = FakeOsRepository();
    await _openDialog(tester, fake);

    // Sem clientes não quebra: o dialog abre normalmente.
    expect(find.text('Nova ordem de serviço'), findsOneWidget);

    // "Próximo" começa desabilitado (nenhum cliente / nome).
    final nextBtn =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(nextBtn.onPressed, isNull);

    // Passo 1 — Cliente: troca para "Cliente novo" e preenche nome + telefone.
    await tester.tap(find.text('Cliente novo'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('Nome *'), 'Maria Teste');
    await tester.pump();
    await tester.enterText(_fieldByLabel('Telefone *'), '11999998888');
    await tester.pump();

    // Nome + telefone habilitam "Próximo" (telefone é obrigatório aqui, como
    // no cadastro completo do cliente).
    final enabledNext =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(enabledNext.onPressed, isNotNull);
    await _next(tester);

    // Passo 2 — Veículo (usaSubjects=true por default): campos dinâmicos da
    // config, incl. o picker de Marca e os campos Ano e Cor.
    expect(find.text('Marca (opcional)'), findsOneWidget);
    expect(find.text('Ano (opcional)'), findsOneWidget);
    expect(find.text('Cor (opcional)'), findsOneWidget);
    await tester.enterText(
        _fieldByLabel('Placa / Identificação *'), 'ABC1D23');
    await tester.enterText(_fieldByLabel('Cor (opcional)'), 'Prata');
    await tester.pump();
    await _next(tester);

    // Passo 3 — Detalhes: o relato é OPCIONAL (nem toda OS nasce de uma
    // queixa); só o responsável é obrigatório. Preenchemos os dois porque é o
    // caminho comum da oficina.
    await tester.enterText(
        _fieldByLabel('Relato do cliente (opcional)'), 'Barulho no motor');
    await tester.pump();
    await _selectResponsavel(tester);

    final createBtn =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Criar OS'));
    expect(createBtn.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
    await tester.pumpAndSettle();

    // OS criada com o nome do cliente novo.
    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(page.items.first.customerName, 'Maria Teste');
  });

  testWidgets('sem clientes cadastrados o dialog não quebra', (tester) async {
    final fake = FakeOsRepository(); // lista de clientes vazia
    await _openDialog(tester, fake);

    // Modo "existente" com busca vazia: campo presente, sem exceção.
    expect(find.text('Cliente *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente existente: preenche obrigatórios e cria', (tester) async {
    final fake = FakeOsRepository(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);

    // Passo 1 — Cliente: escolhe um cliente existente.
    await tester.enterText(_fieldByLabel('Cliente *'), 'João');
    await tester.pumpAndSettle();
    await tester.tap(find.text('João da Silva').last);
    await tester.pumpAndSettle();

    final enabledNext =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(enabledNext.onPressed, isNotNull);
    await _next(tester);

    // Passo 2 — Veículo: cliente sem veículos cadastrados; segue direto.
    await _next(tester);

    // Passo 3 — Detalhes: só o responsável é obrigatório; o relato é opcional.
    await tester.enterText(
        _fieldByLabel('Relato do cliente (opcional)'), 'Revisão geral');
    await tester.pump();
    await _selectResponsavel(tester);

    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
    await tester.pumpAndSettle();

    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(page.items.first.customerId, 'c1');
  });

  testWidgets('cliente novo: telefone é obrigatório para avançar', (
    tester,
  ) async {
    await _openDialog(tester, FakeOsRepository());

    await tester.tap(find.text('Cliente novo'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('Nome *'), 'Maria Teste');
    await tester.pump();

    // Só o nome não basta: o telefone é obrigatório aqui, como no cadastro
    // completo do cliente (e o backend também exige).
    expect(
      tester
          .widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'))
          .onPressed,
      isNull,
    );

    await tester.enterText(_fieldByLabel('Telefone *'), '11999998888');
    await tester.pump();
    expect(
      tester
          .widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('cliente existente SEM veículo pode cadastrar um na hora', (
    tester,
  ) async {
    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);

    await tester.enterText(_fieldByLabel('Cliente *'), 'João');
    await tester.pumpAndSettle();
    await tester.tap(find.text('João da Silva').last);
    await tester.pumpAndSettle();
    await _next(tester);

    // Passo do veículo: em vez de só avisar que não há nenhum, oferece cadastrar.
    expect(find.textContaining('Nenhum veículo cadastrado'), findsOneWidget);
    await tester.tap(find.widgetWithText(NeuButton, 'Cadastrar Veículo'));
    await tester.pumpAndSettle();

    await tester.enterText(
        _fieldByLabel('Placa / Identificação *'), 'ABC1D23');
    await tester.enterText(_fieldByLabel('Cor (opcional)'), 'Prata');
    await tester.pump();
    await _next(tester);

    await tester.enterText(
        _fieldByLabel('Relato do cliente (opcional)'), 'Revisão geral');
    await tester.pump();
    await _selectResponsavel(tester);
    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
    await tester.pumpAndSettle();

    // O veículo vai no MESMO pedido, junto do cliente já existente.
    final draft = fake.lastDraft!;
    expect(draft.customerId, 'c1');
    expect(draft.newSubjectIdentifier, 'ABC1D23');
    expect(draft.newSubjectAttributes?['cor'], 'Prata');
  });

  testWidgets('busca pela placa preenche os campos e guarda a consulta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo();
    await _openDialog(
      tester,
      fake,
      extra: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        customersRepositoryProvider
            .overrideWithValue(FakeCustomersRepository()),
      ],
    );

    await tester.tap(find.text('Cliente novo'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('Nome *'), 'Maria Teste');
    await tester.enterText(_fieldByLabel('Telefone *'), '11999998888');
    await tester.pump();
    await _next(tester);

    await tester.enterText(
        _fieldByLabel('Placa / Identificação *'), 'ABC1D23');
    await tester.pump();
    await tester.tap(find.byTooltip('Buscar dados do veículo pela placa'));
    await tester.pumpAndSettle();

    // Marca vem do equivalente FIPE (valor canônico), não da sigla do registro.
    expect(find.text('VW - VolksWagen'), findsWidgets);
    expect(find.text('Prata'), findsOneWidget);
    await _next(tester);

    await tester.enterText(
        _fieldByLabel('Relato do cliente (opcional)'), 'Barulho no motor');
    await tester.pump();
    await _selectResponsavel(tester);
    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
    await tester.pumpAndSettle();

    // A consulta viaja junto e fica salva no veículo (colunas exclusivas).
    final plate = fake.lastDraft!.newSubjectPlateData;
    expect(plate, isNotNull);
    expect(plate!['chassi'], '9BWKB05Z174110137');
  });

  testWidgets(
      'Detalhes preenche a OS inteira: diagnóstico, template, item, desconto e '
      'situação inicial', (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
      templates: const [
        OsTemplate(
          id: 't1',
          name: 'Revisão simples',
          items: [OsTemplateItem(kind: 'service', name: 'Troca de óleo')],
          total: '100.00',
        ),
      ],
    );
    await _openDialog(tester, fake);
    await _ateDetalhes(tester);

    await _fill(tester, 'Relato do cliente (opcional)', 'Revisão dos 10 mil');
    await _selectResponsavel(tester);
    await _fill(tester, 'Diagnóstico (opcional)', 'Correia gasta');

    // Template: o seletor abre INLINE no passo e devolve o pacote escolhido.
    await _tap(tester, find.widgetWithText(NeuButton, 'Aplicar template'));
    await _tap(tester, find.text('Revisão simples').last);

    await _addItemAvulso(tester, descricao: 'Mão de obra', preco: '100');
    await _fill(tester, 'Desconto (opcional)', '10');
    await _tap(tester, find.text('Em execução'));
    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));

    // O que cabe no POST vai no POST...
    final draft = fake.lastDraft!;
    expect(draft.diagnosis, 'Correia gasta');
    expect(draft.discount, 10);
    // ...e o resto entra pelos mesmos endpoints da tela de detalhe.
    expect(fake.appliedTemplates, ['t1']);
    expect(fake.addedItems.single.name, 'Mão de obra');
    // A OS nasce 'aberta' (FSM do backend) e o wizard faz a transição pedida.
    expect(fake.statusChanges, ['em_execucao']);

    final page = await fake.listOrders();
    expect(page.items.single.status, 'em_execucao');
  });

  testWidgets('seletores abrem NO LUGAR — nada de diálogo sobre diálogo',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);
    await _ateDetalhes(tester);

    // Só o wizard está aberto.
    expect(find.byType(Dialog), findsOneWidget);

    // Abrir o seletor de template NÃO empilha outro diálogo.
    await _tap(tester, find.widgetWithText(NeuButton, 'Aplicar template'));
    expect(find.text('Buscar template'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await _tap(tester, find.widgetWithText(NeuButton, 'Fechar'));

    // Nem o de item.
    await _tap(tester, find.widgetWithText(NeuButton, 'Adicionar item'));
    expect(find.text('Do estoque'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });

  // Uma cliente travou aqui: precisava abrir OS de uma venda para a prefeitura
  // (a placa é obrigatória lá, e só a OS tem placa) e não havia "problema
  // relatado" nenhum para escrever. Sem relato ela não conseguia criar a OS, e
  // acabou fazendo a venda em outro sistema.
  testWidgets('cria a OS SEM relato — o campo é opcional', (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);
    await _ateDetalhes(tester);
    // Nada de relato — só o responsável, que segue obrigatório.
    await _selectResponsavel(tester);
    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));

    expect((await fake.listOrders()).items, hasLength(1));
    expect(find.text('Informe o relato do cliente'), findsNothing);
  });

  testWidgets('salvar como template guarda o pacote montado, com o nome à vista',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);
    await _ateDetalhes(tester);
    await _fill(tester, 'Relato do cliente (opcional)', 'Revisão');
    await _selectResponsavel(tester);
    await _addItemAvulso(tester, descricao: 'Mão de obra', preco: '100');

    // A opção só aparece depois de haver o que salvar.
    await _tap(tester, find.byType(Checkbox));
    await _fill(tester, 'Nome do template *', 'Revisão simples');
    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));

    final template = fake.createdTemplates.single;
    expect(template.name, 'Revisão simples');
    expect(template.items.single.name, 'Mão de obra');
    // A OS foi criada do mesmo jeito.
    expect((await fake.listOrders()).items, hasLength(1));
  });

  testWidgets('dá para criar o template pelo próprio seletor de template',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);
    await _ateDetalhes(tester);
    await _fill(tester, 'Relato do cliente (opcional)', 'Revisão');
    await _selectResponsavel(tester);
    await _addItemAvulso(tester, descricao: 'Mão de obra', preco: '100');

    // Sem templates cadastrados, o seletor não é um beco sem saída: oferece
    // guardar o que já está lançado.
    await _tap(tester, find.widgetWithText(NeuButton, 'Aplicar template'));
    await _tap(tester, find.textContaining('Criar template com o item'));
    await _fill(tester, 'Nome do template *', 'Revisão simples');
    await _tap(tester, find.widgetWithText(NeuButton, 'Salvar template'));

    // Volta para o passo (o painel fechou) com a intenção marcada e o nome à
    // vista — nada é salvo antes de a OS ser criada.
    expect(fake.createdTemplates, isEmpty);
    expect(find.text('Nome do template *'), findsOneWidget);

    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));
    expect(fake.createdTemplates.single.name, 'Revisão simples');
  });

  testWidgets('lançamento que falha não desfaz a OS já criada', (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _CapturingOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    )..failItemsWith = 'Estoque indisponível';

    await _openDialog(tester, fake);
    await _ateDetalhes(tester);
    await _fill(tester, 'Relato do cliente (opcional)', 'Revisão');
    await _selectResponsavel(tester);
    await _addItemAvulso(tester, descricao: 'Mão de obra', preco: '100');
    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));

    // A OS existe, o wizard fechou e o usuário é avisado do que não entrou —
    // perder o cadastro inteiro por causa de um item seria pior.
    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(find.text('Nova ordem de serviço'), findsNothing);
    expect(find.textContaining('não foi possível lançar'), findsOneWidget);
  });

  testWidgets('criada a OS, o link do cliente vem ANTES de abrir a ficha',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _TokenOsRepo(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    // Guarda o que o `show` resolve: enquanto o passo do link está aberto o
    // wizard NÃO resolveu nada, então a lista continua vazia.
    final resolvidos = <Object?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          osRepositoryProvider.overrideWithValue(fake),
          connectivityControllerProvider.overrideWith(_OnlineConn.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    resolvidos.add(await OrderFormDialog.show(context)),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await _ateDetalhes(tester);
    await tester.enterText(
        _fieldByLabel('Relato do cliente (opcional)'), 'Revisão geral');
    await tester.pump();
    await _selectResponsavel(tester);
    await _tap(tester, find.widgetWithText(NeuButton, 'Criar OS'));

    // O link aparece com as três formas de entregá-lo, e nada foi resolvido
    // ainda — a navegação para a OS espera o "Abrir a OS".
    expect(find.textContaining('/#/t/tok-123'), findsOneWidget);
    expect(find.widgetWithText(NeuButton, 'Copiar link'), findsOneWidget);
    expect(find.widgetWithText(NeuButton, 'E-mail'), findsOneWidget);
    expect(resolvidos, isEmpty);

    await _tap(tester, find.widgetWithText(NeuButton, 'Abrir a OS'));

    // Confirmado: o wizard fecha devolvendo o id da OS (quem chamou navega).
    expect(find.text('Nova ordem de serviço'), findsNothing);
    expect(resolvidos, hasLength(1));
    expect(resolvidos.single, (await fake.listOrders()).items.first.id);
  });
}
