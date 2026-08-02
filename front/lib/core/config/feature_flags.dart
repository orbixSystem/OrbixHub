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

/// Nota Fiscal desligada no FRONT (o cliente não quer NF por enquanto).
///
/// Com `false`, o app esconde TODOS os pontos de NF: item "Notas Fiscais" no
/// menu, rotas `/m/invoice*`, botão "Emitir NF" na OS, a opção de emitir nota
/// na venda e a seção fiscal em Configurações. O backend (`invoice`) fica
/// intacto — é só uma retirada visual, reversível trocando para `true`.
const bool kInvoiceEnabled = false;
