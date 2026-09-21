/// Feature flags de PRODUTO (build-time), separadas da config de ambiente.
///
/// Reversível por design: virar para `true` reativa a feature no front, sem
/// mexer no backend nem em `me.modules` (o módulo continua existindo no back).
library;

import 'package:flutter/foundation.dart';

/// Avisos de cobrança desligados no FRONT enquanto o fluxo de pagamento não
/// existe de ponta a ponta.
///
/// Com `false`, some o banner "Pagamento pendente — regularize a assinatura"
/// do painel. Cobrar uma regularização que o usuário não tem como fazer só
/// assusta. O backend continua marcando a assinatura como `past_due` e o
/// `ModuleAccessGuard` segue valendo — isto é retirada de AVISO, não de regra.
const bool kBillingNoticesEnabled = false;

/// Nota Fiscal visível só para NÓS (dev), ainda não para o cliente real.
///
/// Mesmo mecanismo do `kDevTools`: LIGADA em debug/profile (o que rodamos aqui)
/// e DESLIGADA em release (o build que vai para o cliente), com override
/// explícito por `--dart-define=INVOICE_ENABLED=true|false`. Como é `const`,
/// no build de release todo o código de NF é removido pelo tree-shaking —
/// o cliente não vê nem alcança a tela.
///
/// Com `false`, o app esconde TODOS os pontos de NF: item "Notas Fiscais" no
/// menu, rotas `/m/invoice*`, botão "Emitir NF" na OS, a opção de emitir nota
/// na venda e a seção fiscal em Configurações. O backend (`invoice`) fica
/// intacto nos dois casos — isto é visibilidade, não regra de acesso (quem
/// barra de verdade é `@RequiresModule('invoice')` + permissões).
///
/// Para abrir a NF ao cliente real, basta subir com
/// `--dart-define=INVOICE_ENABLED=true` (ou trocar o default) — nada muda no
/// servidor.
const bool kInvoiceEnabled =
    bool.fromEnvironment('INVOICE_ENABLED', defaultValue: !kReleaseMode);
