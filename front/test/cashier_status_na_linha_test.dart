import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_colors.dart';
import 'package:orbixhub_front/features/os/presentation/payment_status.dart';

/// O extrato do Caixa mostra a SITUAÇÃO da venda na própria linha. Antes só
/// clicando: uma venda cancelada tinha a mesma cara de uma normal, porque
/// cancelar a venda não mexe no lançamento do caixa.
void main() {
  group('rótulo do status de pagamento', () {
    test('venda cancelada não é rotulada como cobrança pendente', () {
      // Regressão: sem o caso 'cancelada' o switch caía no `default` e dizia
      // "A receber" — anunciando uma dívida que não existe.
      expect(paymentStatusLabel('cancelada'), 'Cancelada');
      expect(paymentStatusColor('cancelada'), AppColors.danger);
    });

    test('os demais status seguem inalterados', () {
      expect(paymentStatusLabel('pago'), 'Paga');
      expect(paymentStatusLabel('parcial'), 'Parcial');
      expect(paymentStatusLabel('a_receber'), 'A receber');
      expect(paymentStatusColor('pago'), AppColors.success);
      expect(paymentStatusColor('parcial'), AppColors.warning);
      expect(paymentStatusColor('a_receber'), AppColors.inkMuted);
    });

    test('status desconhecido não quebra a tela', () {
      expect(paymentStatusLabel('vindo_do_futuro'), 'A receber');
      expect(paymentStatusColor('vindo_do_futuro'), AppColors.inkMuted);
    });
  });
}
