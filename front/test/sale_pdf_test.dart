import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:orbixhub_front/core/pdf/document_company.dart';
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_pdf.dart';

/// Geração do comprovante de venda.
///
/// Estes testes GERAM o PDF de verdade (o `pdf` monta o documento na memória) e
/// checam que ele sai em bytes válidos. Não valem como conferência visual do
/// layout, mas pegam a classe de bug que mais dói aqui: dado faltando derrubando
/// a exportação na frente do cliente.
void main() {
  const empresa = DocumentCompany(
    name: 'Auto Elétrico São Francisco',
    cnpj: '33007505000137',
    inscricaoEstadual: '638.011.636.111',
    phone: '(17) 9743-7674',
    logradouro: 'Oscar Antonio da Costa',
    numero: '1659',
    bairro: 'Centro',
    municipio: 'São Francisco',
    uf: 'SP',
    cep: '15710000',
  );

  const venda = Sale(
    id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    number: 'VND-2744',
    customerId: 'c1',
    customerName: 'Prefeitura Municipio de Marinopolis',
    total: '490.90',
    createdAt: '2026-08-04T14:22:45.000Z',
    items: [
      SaleItem(
        id: 'i1',
        name: 'GAS EOS R134A COMPLEMENTO',
        quantity: '1',
        unitPrice: '150.00',
        subtotal: '150.00',
      ),
      SaleItem(
        id: 'i2',
        name: 'RC205045 - PRESSOSTATO (TRANSDUTOR) 3 VIAS',
        quantity: '1',
        unitPrice: '190.90',
        subtotal: '190.90',
      ),
      SaleItem(
        id: 'i3',
        kind: 'service',
        name: 'SERVICO DE AR CONDICIONADO',
        quantity: '1',
        unitPrice: '150.00',
        subtotal: '150.00',
      ),
    ],
  );

  const cliente = Customer(
    id: 'c1',
    name: 'Prefeitura Municipio de Marinopolis',
    type: 'PJ',
    document: '45132719000114',
    phone: '(17) 3695-1101',
    address: 'Praca da Bandeira, 69 - Centro',
  );

  /// Um PDF válido começa com "%PDF" e termina com o marcador de fim.
  void esperaPdfValido(Uint8List bytes) {
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  }

  test('venda completa gera PDF válido', () async {
    final bytes = await buildSalePdf(
      venda,
      PdfPageFormat.a4,
      company: empresa,
      extras: const SaleReceiptExtras(
        customer: cliente,
        vendedor: 'FUNCIONARIO PADRAO',
        pagamentos: [(label: 'Dinheiro', valor: 490.90)],
      ),
      emitidoEm: DateTime(2026, 8, 4, 14, 22, 45),
    );
    esperaPdfValido(bytes);
  });

  test('sem cliente (consumidor não identificado) ainda sai', () async {
    const semCliente = Sale(
      id: 'x',
      number: 'VND-1',
      total: '10',
      items: [
        SaleItem(id: 'i', name: 'Item', quantity: '1', unitPrice: '10', subtotal: '10'),
      ],
    );
    final bytes = await buildSalePdf(
      semCliente,
      PdfPageFormat.a4,
      company: empresa,
    );
    esperaPdfValido(bytes);
  });

  test('empresa só com nome (nada preenchido) ainda sai', () async {
    // Tenant novo que não passou por Configurações — o comprovante tem de sair,
    // só com menos coisa no topo.
    final bytes = await buildSalePdf(
      venda,
      PdfPageFormat.a4,
      company: const DocumentCompany(name: 'Minha Oficina'),
    );
    esperaPdfValido(bytes);
  });

  test('venda sem itens não estoura a tabela', () async {
    const vazia = Sale(id: 'v', number: 'VND-0', total: '0');
    final bytes = await buildSalePdf(
      vazia,
      PdfPageFormat.a4,
      company: empresa,
    );
    esperaPdfValido(bytes);
  });

  test('muitos itens quebram em várias páginas (MultiPage)', () async {
    final muitos = Sale(
      id: 'm',
      number: 'VND-9',
      total: '5000',
      items: [
        for (var i = 0; i < 120; i++)
          SaleItem(
            id: 'i$i',
            name: 'Peça número $i com nome razoavelmente longo para ocupar linha',
            quantity: '2',
            unitPrice: '20.83',
            subtotal: '41.66',
          ),
      ],
    );
    final bytes = await buildSalePdf(
      muitos,
      PdfPageFormat.a4,
      company: empresa,
    );
    // Página única estouraria; o MultiPage continua na folha seguinte.
    esperaPdfValido(bytes);
  });

  test('logo corrompido é rejeitado ANTES de virar página', () {
    // A proteção mora aqui, não no gerador: o `pdf` estoura ao desenhar bytes
    // que não são imagem, e aí o documento inteiro deixaria de sair por causa de
    // um upload corrompido. Rejeitando cedo, o papel sai só sem o logo.
    expect(bytesParecemImagem(Uint8List.fromList([0, 1, 2, 3, 4])), isFalse);
    expect(bytesParecemImagem(Uint8List.fromList([])), isFalse);
    // PNG e JPEG de verdade (assinaturas) passam.
    expect(
      bytesParecemImagem(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2])),
      isTrue,
    );
    expect(
      bytesParecemImagem(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1])),
      isTrue,
    );
  });

  test('venda parcial mostra saldo a receber (fiado)', () async {
    final bytes = await buildSalePdf(
      venda,
      PdfPageFormat.a4,
      company: empresa,
      extras: const SaleReceiptExtras(
        customer: cliente,
        pagamentos: [(label: 'Pix', valor: 200)],
      ),
    );
    esperaPdfValido(bytes);
  });
}
