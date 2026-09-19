import 'package:flutter/material.dart';

import '../../sale/presentation/sale_create_dialog.dart';

/// "Registrar venda a prazo" — o mesmo diálogo da venda, em modo a prazo. Existe
/// para quem está no "A receber" não precisar ir ao Caixa só para fiar. O
/// diálogo de venda já tem itens, desconto, estoque com aviso, cliente e
/// validação — duplicar geraria dois cálculos de total que divergem.
Future<void> showCreditSaleDialog(BuildContext context) =>
    showSaleCreateDialog(context, modoPrazo: true);
