import '../../cashier/domain/local_payment.dart';

/// Como o valor recebido se divide entre **caixa**, **troco** e **fiado**.
///
/// É a regra de dinheiro da venda de balcão, fora da UI de propósito: ela decide
/// quanto entra na gaveta e quanto vira dívida, e errar aqui não aparece na tela
/// — aparece no fechamento do dia e na cobrança que ninguém fez.
///
/// O bug que esta classe existe para impedir: recebendo menos que o total, o app
/// lançava o TOTAL no caixa e escrevia "Faltou X" na descrição. A gaveta acusava
/// dinheiro que não entrou, a venda ficava `pago` e a dívida desaparecia da
/// carteira de fiado — restando só um texto livre que nenhum relatório soma.
class SalePaymentSplit {
  const SalePaymentSplit({
    required this.total,
    required this.recebido,
    required this.aLancarNoCaixa,
    required this.falta,
    required this.troco,
  });

  /// Valor a pagar (já com desconto).
  final double total;

  /// O que o cliente entregou.
  final double recebido;

  /// O que o caixa registra: no MÁXIMO o total — o excedente é troco, não
  /// receita. Sem esse teto, receber R$ 100 numa venda de R$ 90 inflaria o
  /// faturamento em R$ 10.
  final double aLancarNoCaixa;

  /// O que fica a receber (fiado). Zero quando quitou.
  final double falta;

  /// Troco a devolver. Só existe recebendo acima do total.
  final double troco;

  /// Venda com saldo em aberto — a que precisa de confirmação e vai para o Fiado.
  bool get ehFiado => falta > 0;

  /// Nada entrou na gaveta: a venda inteira é dívida.
  bool get fiadoIntegral => ehFiado && aLancarNoCaixa <= paymentEps;

  /// Divide um recebimento. [dinheiro] distingue a forma: só em dinheiro existe
  /// troco — em Pix/cartão ninguém paga "a mais", então um valor acima do total
  /// é digitação errada e o excedente é ignorado (o caixa recebe o total) em vez
  /// de virar um troco fantasma.
  factory SalePaymentSplit.of({
    required double total,
    required double recebido,
    required bool dinheiro,
  }) {
    final t = total <= 0 ? 0.0 : round2Money(total);
    final r = recebido <= 0 ? 0.0 : round2Money(recebido);
    final noCaixa = r > t ? t : r;
    final faltou = round2Money(t - noCaixa);
    final trocou = dinheiro ? round2Money(r - t) : 0.0;
    return SalePaymentSplit(
      total: t,
      recebido: r,
      aLancarNoCaixa: noCaixa,
      // Um centavo de resíduo não é dívida nem troco (mesma régua do backend).
      falta: faltou <= paymentEps ? 0 : faltou,
      troco: trocou <= paymentEps ? 0 : trocou,
    );
  }
}
