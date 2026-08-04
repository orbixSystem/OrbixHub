import '../../../core/ui/ui.dart';

/// Tutoriais por tela — o CONTEÚDO, separado da mecânica (`CoachMark`).
///
/// Por que num registro central e não espalhado nas telas:
///  - o shell conhece a rota atual, então um único ponto de disparo cobre todas
///    as telas (nada de repetir `addPostFrameCallback` em cada uma);
///  - os passos não dependem de `GlobalKey`, e por isso valem IGUAL em desktop e
///    mobile. Amarrar cada passo a um elemento faria o tutorial sumir pela metade
///    no celular, onde a sidebar é drawer e colunas de tabela não existem;
///  - o texto fica todo junto, o que é o que permite revisá-lo como se revisa
///    documentação — e não caçar strings em dez arquivos.
///
/// O que faz um tutorial VÁLIDO aqui: explicar a DECISÃO que a tela pede e o que
/// o sistema faz por baixo, não narrar botões. "Clique em Novo para criar" não
/// ensina nada; "o valor recebido decide se a venda é fiado" ensina.
///
/// `id` é a chave do "já visto" (SharedPreferences). NÃO mude um id sem querer
/// remostrar o tutorial a quem já o viu.
class ScreenTutorial {
  const ScreenTutorial({
    required this.id,
    required this.titulo,
    required this.steps,
  });

  final String id;

  /// Nome da tela, para o botão "rever tutorial".
  final String titulo;
  final List<CoachStep> steps;
}

/// Tutorial da rota, ou `null` se ela não tem um.
///
/// Casa por PADRÃO de rota (`:id` casa um segmento qualquer), na ordem do mapa —
/// do mais específico para o mais genérico. Prefixo puro não servia: `/m/customers`
/// (a lista) e `/m/customers/abc` (o detalhe) precisam de tutoriais DIFERENTES, e
/// por prefixo os dois cairiam no mesmo.
///
/// O padrão sem correspondência exata cai no ancestral: `/m/os/123/qualquer`
/// ainda recebe o tutorial da OS em vez de ficar sem ajuda.
ScreenTutorial? tutorialForRoute(String location) {
  final partes = _segmentos(location);
  for (final entry in _porRota.entries) {
    if (_casa(_segmentos(entry.key), partes)) return entry.value;
  }
  // Nenhum padrão exato: tenta o ancestral mais próximo (sub-rota desconhecida
  // ainda merece a ajuda da sua área).
  for (var corte = partes.length - 1; corte > 0; corte--) {
    final ancestral = '/${partes.take(corte).join('/')}';
    for (final entry in _porRota.entries) {
      if (_casa(_segmentos(entry.key), _segmentos(ancestral))) {
        return entry.value;
      }
    }
  }
  return null;
}

List<String> _segmentos(String path) =>
    path.split('/').where((p) => p.isNotEmpty).toList();

/// `padrao` casa `alvo`? Segmento `:algo` aceita qualquer valor.
bool _casa(List<String> padrao, List<String> alvo) {
  if (padrao.length != alvo.length) return false;
  for (var i = 0; i < padrao.length; i++) {
    if (padrao[i].startsWith(':')) continue;
    if (padrao[i] != alvo[i]) return false;
  }
  return true;
}

/// Todos os tutoriais (para uma futura tela de "central de ajuda").
List<ScreenTutorial> get todosOsTutoriais => _porRota.values.toSet().toList();

/// Ordem importa: padrões mais ESPECÍFICOS primeiro (o primeiro que casa vence).
/// As chaves espelham `app_router.dart` — o teste `screen_tutorials_test` compara
/// com a lista real de rotas do shell.
final Map<String, ScreenTutorial> _porRota = {
  // Módulos contratáveis vivem em `/m/<chave>` (ver `gatedNavItems`); as telas
  // de núcleo têm caminho próprio em PT-BR. Chaves conferidas contra o menu real
  // — o teste `screen_tutorials_test` falha se alguma tela ficar sem tutorial.
  // --- sub-telas (antes das listas, senão a lista venceria) ---
  '/m/customers/:id/veiculo/:subjectId': _veiculo,
  '/m/customers/:id': _clienteDetalhe,
  '/m/os/templates': _templates,
  '/m/os/:id': _osDetalhe,
  '/m/invoice/config': _fiscalConfig,
  '/m/invoice/:id': _notaDetalhe,
  '/agenda/horarios': _horarios,
  '/mensagens/:id': _conversa,
  // --- telas de lista / raiz ---
  '/m/cashier': _caixa,
  '/m/os': _os,
  '/m/customers': _clientes,
  '/m/inventory': _estoque,
  '/m/report': _relatorios,
  '/m/invoice': _fiscal,
  '/agenda': _agenda,
  '/mensagens': _mensagens,
  '/equipe': _equipe,
  // A rota é `/billing` — "Planos" só está ESCONDIDO do menu. Registrar como
  // `/planos` (como eu havia feito) fazia este tutorial nunca disparar, e o teste
  // derivado do menu não pegava justamente porque o item não está no menu.
  '/billing': _planos,
  '/configuracoes': _config,
  '/': _inicio,
};

/// Início. Antes o dashboard era dono do próprio tutorial, com `GlobalKey`s
/// locais e um botão de rever só dele. Trazer para cá padroniza: um disparo, um
/// botão (no chrome global) e o mesmo formato das outras telas.
const _inicio = ScreenTutorial(
  // Id novo: o antigo (`dashboard`) já está marcado como visto para quem usou o
  // app, e este tutorial mudou de conteúdo — vale mostrar de novo.
  id: 'tut_inicio_v1',
  titulo: 'Início',
  steps: [
    CoachStep(
      title: 'Este é o seu painel',
      text: 'Ele mostra o dia da oficina: o que está em andamento, o que entrou '
          'de dinheiro e o que precisa de atenção. Os números respeitam o seu '
          'cargo — quem não vê o caixa também não vê faturamento aqui.',
    ),
    CoachStep(
      targetName: 'shell.criar',
      title: 'O botão "+" cria de qualquer tela',
      text: 'Ordem de serviço, venda, despesa, cliente e produto saem dali sem '
          'você precisar navegar até o módulo. O que aparece depende dos módulos '
          'do seu plano e das suas permissões.',
    ),
    CoachStep(
      title: 'Funciona sem internet',
      text: 'Se a conexão cair, você continua lançando: fica tudo guardado no '
          'aparelho e sobe sozinho quando a rede voltar. Uma faixa avisa quando '
          'você está offline, e o sino de pendências mostra o que falta enviar.',
    ),
    CoachStep(
      title: 'A ajuda fica sempre no mesmo lugar',
      text: 'O "?" no topo, ao lado do sino, reabre o tutorial da tela em que '
          'você está — em qualquer tela do sistema.',
    ),
  ],
);

const _fiscal = ScreenTutorial(
  id: 'tut_fiscal_v1',
  titulo: 'Nota fiscal',
  steps: [
    CoachStep(
      title: 'A nota nasce de uma venda ou OS',
      text: 'Você não digita uma nota do zero: emite a partir do que já foi '
          'registrado, e os itens e valores vêm de lá. Isso é o que impede a nota '
          'de divergir do que foi cobrado.',
    ),
    CoachStep(
      title: 'Emitir exige conexão',
      text: 'A emissão fala com o órgão emissor na hora, então não funciona '
          'offline. O resto do sistema continua funcionando — só a nota espera a '
          'internet voltar.',
    ),
    CoachStep(
      title: 'Depois de emitida, o valor não muda',
      text: 'Com nota emitida o app recusa alterar itens ou total: a nota '
          'declarada passaria a divergir. Para corrigir, cancele e refaça.',
    ),
  ],
);


// ============================ SUB-TELAS ============================
// Tutoriais próprios porque cada uma pede uma decisão diferente da sua lista.

const _clienteDetalhe = ScreenTutorial(
  id: 'tut_cliente_detalhe_v1',
  titulo: 'Ficha do cliente',
  steps: [
    CoachStep(
      title: 'Tudo sobre este cliente num lugar',
      text: 'Dados de contato, os veículos dele e o histórico. É a tela para '
          'responder "quem é essa pessoa e o que já fizemos para ela".',
    ),
    CoachStep(
      title: 'O histórico soma OS e vendas',
      text: 'Ordem de serviço E venda de balcão, em ordem cronológica. Filtrar '
          'por veículo mostra só as OS daquele carro — venda de balcão não '
          'pertence a um veículo, então ela sai do filtro.',
    ),
    CoachStep(
      title: 'Cada item do histórico abre o documento',
      text: 'Toque numa linha para abrir a OS (com itens e linha do tempo) ou a '
          'venda (com o que foi vendido e o que já foi recebido).',
    ),
    CoachStep(
      title: 'Arquivar não apaga',
      text: 'O cliente sai das listas mas continua nas OS e vendas antigas. É o '
          'que permite consultar um serviço de dois anos atrás sem manter o '
          'cadastro ativo.',
    ),
  ],
);

const _veiculo = ScreenTutorial(
  id: 'tut_veiculo_v1',
  titulo: 'Veículo',
  steps: [
    CoachStep(
      title: 'O histórico é do CARRO, não do dono',
      text: 'Aqui ficam só as ordens de serviço deste veículo. É o que responde '
          '"quando trocamos a correia dele?" mesmo que a família tenha três '
          'carros na mesma ficha.',
    ),
    CoachStep(
      title: 'A placa busca os dados',
      text: 'A lupa ao lado da placa traz marca, modelo e ano. Essa consulta tem '
          'cota mensal, então ela só dispara quando você pede — nunca sozinha a '
          'cada tecla.',
    ),
    CoachStep(
      title: 'Campos extras dependem do seu ramo',
      text: 'Os campos do veículo são configuráveis em Configurações › Clientes: '
          'o sistema serve oficina, mas também petshop ou clínica — e cada ramo '
          'chama esse cadastro de outra coisa.',
    ),
    CoachStep(
      title: 'A foto ajuda na identificação',
      text: 'Útil para não confundir dois carros iguais no pátio. Enviar foto '
          'exige conexão; o resto da ficha funciona offline.',
    ),
  ],
);

const _osDetalhe = ScreenTutorial(
  id: 'tut_os_detalhe_v1',
  titulo: 'Ordem de serviço',
  steps: [
    CoachStep(
      title: 'Esta é a OS por dentro',
      text: 'Itens (o orçamento), fotos, linha do tempo e pagamento. Tudo que '
          'aconteceu com este trabalho está aqui.',
    ),
    CoachStep(
      title: 'Itens mudam o total na hora',
      text: 'Adicionar ou remover recalcula o total no SERVIDOR — a tela nunca '
          'inventa valor. Peça do estoque baixa quando a OS avança e volta se '
          'você cancelar.',
    ),
    CoachStep(
      title: 'A linha do tempo é a prova',
      text: 'Cada mudança de status e cada observação ficam registradas com '
          'autor e hora. É o que sustenta a conversa com o cliente quando ele '
          'pergunta o que foi feito.',
    ),
    CoachStep(
      title: 'Pagamento vem do Caixa',
      text: 'A tag muda sozinha conforme o caixa recebe, inclusive parcial. O '
          'que faltar aparece no Fiado no nome do cliente — a OS não guarda '
          'valor pago.',
    ),
    CoachStep(
      title: 'Link público e PDF',
      text: 'O link mostra o andamento ao cliente sem login. O PDF é a OS '
          'impressa, com os dados da sua empresa (preenchidos em Configurações).',
    ),
  ],
);

const _templates = ScreenTutorial(
  id: 'tut_os_templates_v1',
  titulo: 'Modelos de OS',
  steps: [
    CoachStep(
      title: 'Modelo é um pacote de itens',
      text: 'Serviços que você repete — revisão, troca de óleo — viram um modelo '
          'com os itens já dentro. Aplicar no lugar de digitar tudo de novo.',
    ),
    CoachStep(
      title: 'Aplicar SOMA à OS',
      text: 'O modelo acrescenta os itens; não substitui o que já está lá. Dá '
          'para aplicar dois modelos e ajustar quantidades depois.',
    ),
    CoachStep(
      title: 'Preço vem do cadastro na hora de aplicar',
      text: 'O modelo guarda quais itens, não quanto custam. Assim um reajuste no '
          'estoque não deixa modelos antigos cobrando preço velho.',
    ),
  ],
);

const _notaDetalhe = ScreenTutorial(
  id: 'tut_nota_detalhe_v1',
  titulo: 'Nota fiscal',
  steps: [
    CoachStep(
      title: 'A nota espelha a venda ou OS',
      text: 'Itens e valores vêm do documento de origem, não são digitados aqui '
          '— é o que impede a nota de divergir do que foi cobrado.',
    ),
    CoachStep(
      title: 'O status é do órgão emissor',
      text: 'Processando, autorizada ou rejeitada: quem decide é o órgão, não o '
          'app. Rejeição mostra o motivo para você corrigir a origem e emitir de '
          'novo.',
    ),
    CoachStep(
      title: 'Emitida trava o valor',
      text: 'Depois de autorizada, o app recusa alterar itens ou total da origem: '
          'a nota declarada passaria a divergir. Para corrigir, cancele e refaça.',
    ),
  ],
);

const _fiscalConfig = ScreenTutorial(
  id: 'tut_fiscal_config_v1',
  titulo: 'Configuração fiscal',
  steps: [
    CoachStep(
      title: 'Sem isto a emissão não funciona',
      text: 'Dados da empresa, regime e série são o que o órgão exige para '
          'aceitar a nota. Errar aqui aparece como rejeição na emissão.',
    ),
    CoachStep(
      title: 'Certificado é dado sensível',
      text: 'Ele fica guardado no servidor, nunca no aparelho, e é usado só para '
          'assinar a nota. Por isso esta tela exige conexão e permissão de gestão.',
    ),
  ],
);

const _horarios = ScreenTutorial(
  id: 'tut_horarios_v1',
  titulo: 'Horários',
  steps: [
    CoachStep(
      title: 'Isto define a capacidade da agenda',
      text: 'Os horários daqui são o que a Agenda considera aberto. Se um dia '
          'aparece fechado sem motivo, o ajuste é nesta tela.',
    ),
    CoachStep(
      title: 'Dia fechado não recebe agendamento',
      text: 'Deixe o dia sem intervalo para bloqueá-lo. É assim que domingo e '
          'feriado saem da agenda sem você precisar recusar um por um.',
    ),
  ],
);

const _conversa = ScreenTutorial(
  id: 'tut_conversa_v1',
  titulo: 'Conversa',
  steps: [
    CoachStep(
      title: 'Uma conversa por ordem de serviço',
      text: 'O fio é da OS, então a dúvida sobre um carro não se mistura com a '
          'de outro — e quem assumir o atendimento depois lê o contexto inteiro.',
    ),
    CoachStep(
      title: 'O cliente responde pelo link',
      text: 'Ele usa o link público de acompanhamento, sem instalar nada nem '
          'criar senha. As mensagens chegam aqui em tempo real.',
    ),
    CoachStep(
      title: 'Ler funciona offline; enviar, não',
      text: 'O histórico fica no aparelho para consulta sem internet. Enviar '
          'mensagem precisa de conexão — ela não é enfileirada.',
    ),
  ],
);

const _caixa = ScreenTutorial(
  id: 'tut_caixa_v2',
  titulo: 'Caixa',
  steps: [
    CoachStep(
      targetName: 'caixa.abas',
      title: 'Três abas, três perguntas',
      text: '"Caixa do dia" é onde você opera. "Histórico" responde o que '
          'aconteceu num período, com filtros. "Fiado" mostra quem está devendo. '
          'No celular elas ficam aqui do mesmo jeito — só mais estreitas.',
    ),
    CoachStep(
      targetName: 'caixa.acoes',
      title: 'As três ações do dia',
      text: '"Venda avulsa" abre o balcão completo (itens, desconto, '
          'recebimento). "Receber OS" recebe de uma ordem já aberta, inclusive '
          'parcial. "Despesa / sangria" registra saída. No desktop ficam em até '
          'três colunas; no celular, duas — os mesmos botões.',
    ),
    CoachStep(
      targetName: 'caixa.ultimos',
      title: 'Últimos lançamentos: confirmação, não extrato',
      text: 'São as 5 últimas linhas, só para você confirmar que o que acabou de '
          'lançar entrou. O extrato completo do período é a aba Histórico — '
          '"Ver tudo" leva até lá. Linha de VENDA abre o detalhe dela (toque nela); '
          'despesa e sangria abrem o menu de ações nos três pontinhos.',
    ),
    CoachStep(
      title: 'O valor recebido decide se é fiado',
      text: 'Na venda avulsa você digita quanto o cliente entregou. Igual ao '
          'total = paga. MENOS que o total = o resto vira fiado, e o app pede '
          'confirmação antes. Mais que o total, em dinheiro = troco, e o caixa '
          'registra só o total (o troco não é receita).',
    ),
    CoachStep(
      title: 'Fiado se resolve na aba Fiado',
      text: 'Toda venda ou OS com saldo aberto aparece lá sozinha, agrupada por '
          'cliente, com quanto cada um deve e de quais serviços. Receber é '
          'lançar o valor ali — aceita parcial quantas vezes precisar.',
    ),
    CoachStep(
      title: 'Corrigir não apaga',
      text: 'Descrição e categoria você edita direto. Mudar o VALOR estorna o '
          'lançamento errado e cria o certo: os dois ficam no histórico, o '
          'estornado riscado. É o que faz o caixa fechar e o que impede alguém '
          'de reescrever dinheiro sem deixar rastro.',
    ),
    CoachStep(
      title: 'Abrir e fechar caixa é opcional',
      text: 'Essa cerimônia serve para conferir dinheiro na GAVETA. Se você '
          'recebe por Pix e cartão, ou opera sozinho, deixe desligada em '
          'Configurações › Caixa: aí o dia vira por data, à meia-noite, sozinho.',
    ),
  ],
);

const _os = ScreenTutorial(
  id: 'tut_os_v2',
  titulo: 'Ordens de serviço',
  steps: [
    CoachStep(
      targetName: 'os.filtros',
      title: 'Achar a OS certa',
      text: 'A busca aceita número OU nome do cliente. Os chips filtram por '
          'situação (aberta, em execução, concluída) e a ordenação muda o topo da '
          'lista. No celular a busca fica em cima e os chips embaixo; no desktop, '
          'na mesma linha — os mesmos filtros.',
    ),
    CoachStep(
      targetName: 'os.lista',
      title: 'Cada linha é um trabalho',
      text: 'Mostra número, cliente, veículo, situação e a tag de pagamento — '
          'que vem do CAIXA, não da OS (é por isso que ela muda sozinha quando '
          'você recebe). Toque para abrir e ver itens, fotos e a linha do tempo.',
    ),
    CoachStep(
      title: 'Abrir agora, completar depois',
      text: 'Cliente e veículo são opcionais no começo: dá para registrar o '
          'serviço com o carro já no elevador e completar o cadastro depois, sem '
          'travar o atendimento.',
    ),
    CoachStep(
      title: 'Itens do estoque baixam sozinhos',
      text: 'Peça vinculada ao estoque sai do saldo quando a OS avança, e volta '
          'se você cancelar. Serviço (mão de obra) entra só pelo preço. Não dê '
          'baixa manual: seria descontar duas vezes.',
    ),
    CoachStep(
      title: 'O status é o histórico',
      text: 'Cada mudança entra na linha do tempo com autor e hora. É isso que '
          'responde "desde quando esse carro está aqui?" sem depender da memória '
          'de ninguém.',
    ),
    CoachStep(
      title: 'O cliente acompanha por link',
      text: 'Cada OS tem um link público que mostra o andamento sem login e sem '
          'expor seus dados internos. Mandar o link substitui o "e o meu carro?" '
          'no telefone.',
    ),
    CoachStep(
      title: 'Receber é no Caixa',
      text: 'A OS não guarda quanto foi pago — quem sabe isso é o caixa. Use '
          '"Receber OS" lá; aceita valor parcial, e o que faltar aparece no Fiado '
          'no nome do cliente.',
    ),
  ],
);

const _clientes = ScreenTutorial(
  id: 'tut_clientes_v2',
  titulo: 'Clientes',
  steps: [
    CoachStep(
      targetName: 'clientes.filtros',
      title: 'Buscar por nome, documento ou telefone',
      text: 'A busca varre os três — útil quando o cliente liga e você só tem o '
          'número dele. Também dá para ver os arquivados, que saem da lista mas '
          'continuam no histórico. No celular a busca fica acima dos filtros.',
    ),
    CoachStep(
      targetName: 'clientes.lista',
      title: 'Cada linha é um cliente',
      text: 'Toque para abrir a ficha: dados, veículos e o histórico completo — '
          'ordens de serviço E vendas de balcão, em ordem cronológica.',
    ),
    CoachStep(
      title: 'Cliente e veículo são coisas diferentes',
      text: 'O cliente é a pessoa ou empresa; o veículo pertence a ele. Um '
          'cliente pode ter vários, e o histórico de cada carro fica separado — '
          'útil quando a família traz dois no mesmo mês.',
    ),
    CoachStep(
      title: 'CNPJ preenche sozinho',
      text: 'Escolha "Pessoa jurídica" e toque na lupa ao lado do documento: o '
          'app busca razão social, telefone e endereço na Receita. O que você já '
          'digitou não é sobrescrito. E-mail quase nunca vem — é normal.',
    ),
    CoachStep(
      title: 'A placa também busca',
      text: 'No cadastro do veículo, a lupa ao lado da placa traz marca, modelo '
          'e ano. Essa consulta tem cota mensal, então ela só dispara quando '
          'você pede — nunca a cada tecla.',
    ),
    CoachStep(
      title: 'O histórico mostra tudo do cliente',
      text: 'Ordens de serviço E vendas de balcão, em ordem cronológica. Filtrar '
          'por veículo mostra só as OS daquele carro, porque venda de balcão não '
          'pertence a um veículo.',
    ),
    CoachStep(
      title: 'Nada é apagado',
      text: 'Cliente sai da lista por arquivamento, não por exclusão: o '
          'histórico dele continua válido nas OS e vendas antigas. É o que '
          'permite consultar um serviço de dois anos atrás.',
    ),
  ],
);

const _estoque = ScreenTutorial(
  id: 'tut_estoque_v2',
  titulo: 'Estoque',
  steps: [
    CoachStep(
      targetName: 'estoque.filtros',
      title: 'Buscar e filtrar o catálogo',
      text: 'A busca aceita nome e código. Os filtros separam produto de serviço '
          'e mostram o que está ACABANDO (abaixo do estoque mínimo) — é por onde '
          'se monta a lista de compras.',
    ),
    CoachStep(
      targetName: 'estoque.lista',
      title: 'Cada linha é um item do catálogo',
      text: 'Mostra saldo atual e preço de venda. Toque para abrir e ver o '
          'DIÁRIO do item: cada entrada, saída e ajuste, com a origem. É por ele '
          'que se descobre por que o saldo não fecha.',
    ),
    CoachStep(
      title: 'Produto tem saldo; serviço não',
      text: 'Só produto controla quantidade. Serviço (mão de obra) entra em OS e '
          'venda pelo preço, sem estoque — por isso ele nunca aparece como '
          '"acabando".',
    ),
    CoachStep(
      title: 'A baixa é automática',
      text: 'Peça usada em OS ou vendida no balcão sai do saldo sozinha, e '
          'volta se a OS for cancelada ou a venda estornada. Você não precisa '
          'dar baixa na mão — e não deve, para não descontar duas vezes.',
    ),
    CoachStep(
      title: 'Todo movimento fica registrado',
      text: 'Entrada, saída e ajuste ficam no diário do item, com origem. É por '
          'ele que se descobre por que o saldo não fecha, em vez de adivinhar.',
    ),
    CoachStep(
      title: 'Estoque mínimo avisa antes de faltar',
      text: 'Defina o mínimo e o item aparece em "acabando" quando cruzar a '
          'linha. Serve para comprar antes do cliente ficar esperando peça.',
    ),
    CoachStep(
      title: 'Código de barras acelera o cadastro',
      text: 'Informe o EAN e o app tenta trazer o nome do produto de um catálogo '
          'compartilhado. Cadastrar cem peças digitando tudo é o que faz o '
          'estoque nunca sair do papel.',
    ),
  ],
);

const _relatorios = ScreenTutorial(
  id: 'tut_relatorios_v1',
  titulo: 'Relatórios',
  steps: [
    CoachStep(
      title: 'Escolha o período primeiro',
      text: 'Todo número aqui é de um intervalo. Trocar o período muda tudo — se '
          'um valor parecer errado, confira a data antes de desconfiar do dado.',
    ),
    CoachStep(
      title: 'Faturamento não é dinheiro em caixa',
      text: 'Faturamento é o que foi vendido; caixa é o que entrou. Venda em '
          'fiado soma no faturamento e não no caixa — e é justamente essa '
          'diferença que mostra quanto você tem na rua.',
    ),
    CoachStep(
      title: 'Exportar para levar adiante',
      text: 'Qualquer relatório sai em CSV (para planilha) ou PDF (para '
          'imprimir/enviar ao contador), com o mesmo recorte que está na tela.',
    ),
  ],
);

const _agenda = ScreenTutorial(
  id: 'tut_agenda_v1',
  titulo: 'Agenda',
  steps: [
    CoachStep(
      title: 'A agenda é a capacidade do dia',
      text: 'Ela mostra o que está marcado e quanto ainda cabe, para você não '
          'prometer um horário que a oficina não tem.',
    ),
    CoachStep(
      title: 'Atribuir define quem faz',
      text: 'Cada item pode ir para um mecânico. Sem responsável, o serviço '
          'aparece como não atribuído — é a fila que ninguém pegou ainda.',
    ),
    CoachStep(
      title: 'Horário de funcionamento manda',
      text: 'A agenda respeita os horários configurados. Se um dia parece '
          'fechado sem motivo, o ajuste está em Configurações.',
    ),
  ],
);

const _mensagens = ScreenTutorial(
  id: 'tut_mensagens_v1',
  titulo: 'Mensagens',
  steps: [
    CoachStep(
      title: 'Conversa por ordem de serviço',
      text: 'Cada OS tem seu próprio fio, então a dúvida sobre um carro não se '
          'mistura com a de outro. O cliente responde pelo link público, sem '
          'instalar nada.',
    ),
    CoachStep(
      title: 'Chega na hora',
      text: 'As mensagens aparecem em tempo real e o sino avisa. O histórico '
          'também fica disponível offline para leitura — enviar, porém, precisa '
          'de conexão.',
    ),
  ],
);

const _equipe = ScreenTutorial(
  id: 'tut_equipe_v1',
  titulo: 'Equipe',
  steps: [
    CoachStep(
      title: 'O cargo define o que a pessoa vê',
      text: 'Mecânico não vê caixa nem relatório; atendente lança recebimento '
          'mas não despesa; gerente e dono veem gestão. Menos permissão é menos '
          'chance de erro caro.',
    ),
    CoachStep(
      title: 'Convite em vez de senha compartilhada',
      text: 'Você convida por e-mail e a pessoa cria a própria senha. Assim cada '
          'ação no sistema tem autor de verdade — e é isso que faz o histórico '
          'valer algo.',
    ),
    CoachStep(
      title: 'Desligar é imediato',
      text: 'Ao remover alguém, o acesso cai na hora, mesmo se ela estiver com o '
          'app aberto. O que ela já registrou continua no histórico.',
    ),
  ],
);

const _planos = ScreenTutorial(
  id: 'tut_planos_v1',
  titulo: 'Planos',
  steps: [
    CoachStep(
      title: 'O plano liga os módulos',
      text: 'Cada plano habilita um conjunto de módulos. Trocar de plano muda o '
          'que aparece no menu na hora — nada de reinstalar ou pedir liberação.',
    ),
    CoachStep(
      title: 'Atraso não apaga nada',
      text: 'Com pagamento em atraso o sistema passa a somente leitura: você '
          'continua consultando tudo, só não registra. Nenhum dado é perdido, e '
          'volta ao normal quando regularizar.',
    ),
  ],
);

const _config = ScreenTutorial(
  id: 'tut_config_v1',
  titulo: 'Configurações',
  steps: [
    CoachStep(
      title: 'Dados da empresa saem nos documentos',
      text: 'Nome, CNPJ, endereço e logo aparecem na OS impressa e nos '
          'relatórios. Preencher aqui é o que faz o documento parecer seu.',
    ),
    CoachStep(
      title: 'Cada módulo traz suas preferências',
      text: 'As seções abaixo mudam conforme os módulos do seu plano. Em Caixa, '
          'por exemplo, é onde se liga a conferência de gaveta (abrir/fechar).',
    ),
    CoachStep(
      title: 'Aparência é por empresa',
      text: 'A paleta escolhida vale para todos os usuários da oficina, não só '
          'para você — é a identidade do sistema para a equipe.',
    ),
  ],
);
