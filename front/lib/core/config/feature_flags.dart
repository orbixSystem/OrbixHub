/// Feature flags de PRODUTO (build-time), separadas da config de ambiente.
///
/// Reversível por design: virar para `true` reativa a feature no front, sem
/// mexer no backend nem em `me.modules` (o módulo continua existindo no back).
library;

/// Avisos de cobrança desligados no FRONT enquanto o fluxo de pagamento não
/// existe de ponta a ponta.
///
/// Com `false`, some o banner "Pagamento pendente — regularize a assinatura"
/// do painel. Cobrar uma regularização que o usuário não tem como fazer só
/// assusta. O backend continua marcando a assinatura como `past_due` e o
/// `ModuleAccessGuard` segue valendo — isto é retirada de AVISO, não de regra.
const bool kBillingNoticesEnabled = false;

/// Nota Fiscal **desligada** — anunciada como "Em breve" em todos os pontos.
///
/// O default é `false` em QUALQUER build, inclusive em debug. Já foi
/// `!kReleaseMode` (ligada para nós, desligada para o cliente) e isso custou
/// caro na prática: o estado que o cliente vê não aparecia enquanto
/// desenvolvíamos, então não havia como conferir os pontos de "Em breve" sem
/// gerar um release — e a impressão era de que nada tinha sido feito. O que se
/// sobe é o que se vê.
///
/// Para trabalhar NA NF (ou revisar as telas fiscais), suba com
/// `--dart-define=INVOICE_ENABLED=true`.
///
/// Com `false`, os pontos de NF continuam VISÍVEIS, mas inertes e marcados
/// **"Em breve"**: item "Notas Fiscais" no menu, botão "Emitir nota fiscal" na
/// OS, a opção de emitir nota na venda e a seção fiscal em Configurações.
/// Anunciar o que está a caminho é decisão de produto — o cliente entende que
/// a nota vem, em vez de achar que o sistema não emite.
///
/// A única coisa que NÃO fica acessível é a rota: `/m/invoice*` volta para a
/// home, porque a tela de verdade fala com um backend que o cliente ainda não
/// vai usar. O backend (`invoice`) fica intacto nos dois casos — isto é
/// visibilidade, não regra de acesso (quem barra de verdade é
/// `@RequiresModule('invoice')` + permissões).
///
/// Para abrir a NF ao cliente real, troque o default — nada muda no servidor.
const bool kInvoiceEnabled = bool.fromEnvironment('INVOICE_ENABLED');
