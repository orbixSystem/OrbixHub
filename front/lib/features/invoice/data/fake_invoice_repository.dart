import '../domain/invoice_models.dart';
import '../domain/invoice_repository.dart';

/// In-memory [InvoiceRepository] para dev/testes. Espelha o contrato: lista
/// paginada com filtro de status, detalhe com linhas/eventos, emissão a partir
/// de uma OS e cancelamento (sem hard delete — só muda o status).
class FakeInvoiceRepository implements InvoiceRepository {
  FakeInvoiceRepository({List<Invoice>? seed})
      : _invoices = [...(seed ?? _defaultSeed())];

  final List<Invoice> _invoices;
  int _seq = 100;

  static List<Invoice> _defaultSeed() => [
        Invoice(
          id: 'inv-1',
          documentType: 'nfse',
          status: 'authorized',
          environment: 'homologacao',
          orderId: 'os-1',
          orderNumber: 'OS-0001',
          customerId: 'cli-1',
          customerName: 'Maria Oliveira',
          customerDocument: '123.456.789-09',
          series: '1',
          number: '42',
          accessKey: '3526 0712 3456 7890 0012 3456 7890 0012 3456 7890',
          serviceAmount: '250.00',
          productAmount: '0.00',
          totalAmount: '250.00',
          pdfUrl: 'https://example.com/nfse/inv-1.pdf',
          xmlUrl: 'https://example.com/nfse/inv-1.xml',
          authorizedAt: '2026-07-02T14:30:00.000Z',
          createdAt: '2026-07-02T14:29:00.000Z',
          lines: const [
            InvoiceLine(
              kind: 'service',
              name: 'Mão de obra — troca de óleo',
              quantity: '1',
              unitPrice: '250.00',
              total: '250.00',
            ),
          ],
          events: const [
            InvoiceEvent(
              kind: 'created',
              message: 'Nota criada',
              statusSnapshot: 'draft',
              createdAt: '2026-07-02T14:29:00.000Z',
            ),
            InvoiceEvent(
              kind: 'authorized',
              message: 'Nota autorizada pela prefeitura',
              statusSnapshot: 'authorized',
              createdAt: '2026-07-02T14:30:00.000Z',
            ),
          ],
        ),
        Invoice(
          id: 'inv-2',
          documentType: 'nfse',
          status: 'processing',
          environment: 'homologacao',
          orderId: 'os-2',
          orderNumber: 'OS-0002',
          customerId: 'cli-2',
          customerName: 'João Santos',
          serviceAmount: '480.00',
          productAmount: '120.00',
          totalAmount: '600.00',
          createdAt: '2026-07-04T09:10:00.000Z',
          lines: const [
            InvoiceLine(
              kind: 'service',
              name: 'Revisão completa',
              quantity: '1',
              unitPrice: '480.00',
              total: '480.00',
            ),
            InvoiceLine(
              kind: 'product',
              name: 'Filtro de ar',
              quantity: '2',
              unitPrice: '60.00',
              total: '120.00',
            ),
          ],
          events: const [
            InvoiceEvent(
              kind: 'created',
              message: 'Nota criada',
              statusSnapshot: 'draft',
              createdAt: '2026-07-04T09:10:00.000Z',
            ),
          ],
        ),
        Invoice(
          id: 'inv-3',
          documentType: 'nfse',
          status: 'rejected',
          environment: 'homologacao',
          orderId: 'os-3',
          orderNumber: 'OS-0003',
          customerName: 'Auto Center Ltda',
          customerDocument: '12.345.678/0001-90',
          serviceAmount: '90.00',
          productAmount: '0.00',
          totalAmount: '90.00',
          rejectionReason: 'CNAE do prestador incompatível com o serviço informado.',
          createdAt: '2026-07-03T16:00:00.000Z',
          lines: const [
            InvoiceLine(
              kind: 'service',
              name: 'Diagnóstico eletrônico',
              quantity: '1',
              unitPrice: '90.00',
              total: '90.00',
            ),
          ],
          events: const [
            InvoiceEvent(
              kind: 'rejected',
              message: 'Rejeitada pela prefeitura',
              statusSnapshot: 'rejected',
              createdAt: '2026-07-03T16:01:00.000Z',
            ),
          ],
        ),
      ];

  @override
  Future<InvoicePage> list({
    int page = 1,
    String? status,
    String? orderId,
    String? saleId,
  }) async {
    final filtered = _invoices.where((i) {
      final statusOk = status == null || status.isEmpty || i.status == status;
      final orderOk = orderId == null || orderId.isEmpty || i.orderId == orderId;
      final saleOk = saleId == null || saleId.isEmpty || i.saleId == saleId;
      return statusOk && orderOk && saleOk;
    }).toList();
    return InvoicePage(
      items: filtered,
      total: filtered.length,
      page: page,
      pageSize: 20,
    );
  }

  @override
  Future<Invoice> getOne(String id) async {
    return _invoices.firstWhere(
      (i) => i.id == id,
      orElse: () => throw StateError('Nota não encontrada: $id'),
    );
  }

  @override
  Future<Invoice> issue({String? orderId, String? saleId, String? documentType}) async {
    final created = Invoice(
      id: 'inv-${_seq++}',
      documentType: documentType ?? 'nfse',
      status: 'authorized',
      environment: 'homologacao',
      orderId: orderId,
      orderNumber: orderId != null ? 'OS-$orderId' : 'VD-$saleId',
      series: '1',
      number: '$_seq',
      accessKey: '0000 0000 0000 0000 0000 0000 0000 0000 0000 0000',
      serviceAmount: '100.00',
      productAmount: '0.00',
      totalAmount: '100.00',
      pdfUrl: 'https://example.com/nfse/new.pdf',
      xmlUrl: 'https://example.com/nfse/new.xml',
      authorizedAt: DateTime.now().toUtc().toIso8601String(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      lines: const [
        InvoiceLine(
          kind: 'service',
          name: 'Serviço',
          quantity: '1',
          unitPrice: '100.00',
          total: '100.00',
        ),
      ],
      events: [
        InvoiceEvent(
          kind: 'authorized',
          statusSnapshot: 'authorized',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ],
    );
    _invoices.insert(0, created);
    return created;
  }

  @override
  Future<Invoice> cancel(String id, String reason) async {
    final idx = _invoices.indexWhere((i) => i.id == id);
    if (idx < 0) throw StateError('Nota não encontrada: $id');
    final canceled = _invoices[idx].copyWith(
      status: 'canceled',
      canceledAt: DateTime.now().toUtc().toIso8601String(),
      events: [
        ..._invoices[idx].events,
        InvoiceEvent(
          kind: 'canceled',
          message: reason,
          statusSnapshot: 'canceled',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ],
    );
    _invoices[idx] = canceled;
    return canceled;
  }
}
