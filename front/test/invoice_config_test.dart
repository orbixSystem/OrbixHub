import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/invoice/data/fake_invoice_config_repository.dart';

void main() {
  test('fake repo aplica patch e marca empresa registrada', () async {
    final repo = FakeInvoiceConfigRepository();
    final c1 = await repo.fetch();
    expect(c1.ambiente, 'homologacao');
    final c2 = await repo.update({'serieNfse': '9', 'ambiente': 'producao'});
    expect(c2.serieNfse, '9');
    expect(c2.ambiente, 'producao');
    final c3 = await repo.registerEmpresa();
    expect(c3.empresaRegistrada, true);
  });
}
