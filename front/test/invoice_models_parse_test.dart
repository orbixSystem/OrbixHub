import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/invoice/domain/invoice_models.dart';

/// Pins the real backend contract (snake_case, decimals as String) → models.
void main() {
  test('parses an /invoices list page', () {
    final page = InvoicePage.fromJson({
      'items': [
        {
          'id': 'inv-1',
          'document_type': 'nfse',
          'status': 'authorized',
          'order_number': 'OS-0001',
          'customer_name': 'Maria Oliveira',
          'total_amount': '250.00',
          'created_at': '2026-07-02T14:29:00.000Z',
        },
      ],
      'total': 1,
      'page': 1,
      'pageSize': 20,
    });

    expect(page.total, 1);
    expect(page.page, 1);
    expect(page.items.single.status, 'authorized');
    expect(page.items.single.totalAmount, '250.00');
    expect(page.items.single.orderNumber, 'OS-0001');
    // Listas de detalhe não vêm na lista → default vazio, sem quebrar.
    expect(page.items.single.lines, isEmpty);
  });

  test('parses /invoices/:id with lines + events', () {
    final invoice = Invoice.fromJson({
      'id': 'inv-2',
      'document_type': 'nfse',
      'status': 'rejected',
      'environment': 'homologacao',
      'order_id': 'os-2',
      'order_number': 'OS-0002',
      'customer_id': 'cli-2',
      'customer_name': 'João Santos',
      'customer_document': '123.456.789-09',
      'series': null,
      'number': null,
      'access_key': null,
      'service_amount': '90.00',
      'product_amount': '0.00',
      'total_amount': '90.00',
      'pdf_url': null,
      'xml_url': null,
      'rejection_reason': 'CNAE incompatível.',
      'authorized_at': null,
      'canceled_at': null,
      'created_at': '2026-07-03T16:00:00.000Z',
      'updated_at': '2026-07-03T16:01:00.000Z',
      'lines': [
        {
          'kind': 'service',
          'name': 'Diagnóstico eletrônico',
          'quantity': '1',
          'unit_price': '90.00',
          'total': '90.00',
        },
      ],
      'events': [
        {
          'kind': 'rejected',
          'message': 'Rejeitada pela prefeitura',
          'status_snapshot': 'rejected',
          'created_at': '2026-07-03T16:01:00.000Z',
        },
      ],
    });

    expect(invoice.status, 'rejected');
    expect(invoice.rejectionReason, 'CNAE incompatível.');
    expect(invoice.customerDocument, '123.456.789-09');
    expect(invoice.number, isNull);
    expect(invoice.lines, hasLength(1));
    expect(invoice.lines.single.kind, 'service');
    expect(invoice.lines.single.unitPrice, '90.00');
    expect(invoice.events.single.statusSnapshot, 'rejected');
  });
}
