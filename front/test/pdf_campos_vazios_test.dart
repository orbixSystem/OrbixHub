import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:orbixhub_front/core/pdf/document_company.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_pdf.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_pdf.dart';

/// Campo NÃO preenchido não sai no papel.
///
/// A reclamação da cliente foi literal: ela não usa "previsão de início/fim", e
/// a OS saía com "Previsão início: -" e "Previsão fim: -". Rótulo sem valor faz
/// o documento parecer formulário abandonado no meio — pior do que a ausência
/// da linha.
///
/// Os testes batem nas funções PURAS que decidem quais linhas existem: widget de
/// PDF não se inspeciona (o documento sai comprimido), mas a decisão, sim.
void main() {
  const empresa = DocumentCompany(name: 'Auto Elétrico São Francisco');

  ServiceOrder os({
    String? cliente = 'PREFEITURA DE SAO FRANCISCO',
    String? veiculo = 'GDY8B74',
    String? inicio,
    String? fim,
  }) =>
      ServiceOrder(
        id: 'os-1',
        number: 'OS-0002',
        customerId: 'c1',
        customerName: cliente,
        subjectLabel: veiculo,
        status: 'em_execucao',
        total: '252.00',
        scheduledStart: inicio,
        scheduledEnd: fim,
      );

  group('OS — bloco cliente e veículo', () {
    test('previsão não preenchida some (não vira "Previsão fim: -")', () {
      final linhas = osClienteVeiculoLinhas(os());
      expect(linhas.previsoes, isEmpty);
      expect(
        linhas.dados.map((l) => l.$1),
        ['Cliente:', 'Veículo:'],
      );
    });

    test('só a previsão de fim preenchida: sai ela sozinha', () {
      final linhas = osClienteVeiculoLinhas(
        os(fim: '2026-08-18T00:00:00.000Z'),
      );
      expect(linhas.previsoes.map((l) => l.$1), ['Previsão fim:']);
    });

    test('veículo em branco não ocupa linha', () {
      final linhas = osClienteVeiculoLinhas(os(veiculo: ''));
      expect(linhas.dados.map((l) => l.$1), ['Cliente:']);
    });

    test('sem nada preenchido a seção inteira fica vazia', () {
      // O gerador usa isto para suprimir até a faixa "Cliente e veículo": uma
      // faixa de título sobre o nada é pior que a ausência dela.
      final linhas = osClienteVeiculoLinhas(os(cliente: null, veiculo: null));
      expect(linhas.dados, isEmpty);
      expect(linhas.previsoes, isEmpty);
    });
  });

  group('quadro de totais', () {
    test('OS sem desconto não imprime a linha de desconto', () {
      final rotulos = osTotaisLinhas(
        qtdTotal: 6,
        somaItens: 252,
        desconto: 0,
        total: 252,
      ).map((l) => l.$1);
      expect(rotulos, isNot(contains('Desconto')));
      expect(rotulos, contains('Valor total'));
    });

    test('OS com desconto concedido imprime a linha', () {
      final rotulos = osTotaisLinhas(
        qtdTotal: 2,
        somaItens: 32,
        desconto: 31,
        total: 1,
      ).map((l) => l.$1);
      expect(rotulos, contains('Desconto'));
    });

    test('venda sem desconto e sem troco não imprime nenhum dos dois', () {
      final rotulos = saleTotaisLinhas(
        qtdTotal: 3,
        somaItens: 490.9,
        desconto: 0,
        total: 490.9,
        troco: 0,
      ).map((l) => l.$1);
      expect(rotulos, isNot(contains('Valor total desconto')));
      expect(rotulos, isNot(contains('Valor troco')));
      expect(rotulos, contains('Valor total'));
    });

    test('venda com troco de verdade imprime o troco', () {
      final rotulos = saleTotaisLinhas(
        qtdTotal: 1,
        somaItens: 90,
        desconto: 0,
        total: 90,
        troco: 10,
      ).map((l) => l.$1);
      expect(rotulos, contains('Valor troco'));
    });
  });

  group('os documentos continuam saindo', () {
    void ehPdfValido(Uint8List bytes, String qual) {
      expect(bytes.length, greaterThan(800), reason: '$qual saiu vazio demais');
      expect(String.fromCharCodes(bytes.take(4)), '%PDF', reason: qual);
    }

    test('OS sem previsão nenhuma gera normalmente', () async {
      ehPdfValido(
        await buildOsPdf(os(), PdfPageFormat.a4, company: empresa),
        'PDF da OS',
      );
    });

    test('OS sem cliente nem veículo (seção suprimida) gera normalmente',
        () async {
      ehPdfValido(
        await buildOsPdf(
          os(cliente: null, veiculo: null),
          PdfPageFormat.a4,
          company: empresa,
        ),
        'PDF da OS sem cliente',
      );
    });

    test('comprovante de venda com observação gera normalmente', () async {
      const venda = Sale(
        id: 'v1',
        number: 'VND-0007',
        total: '250.00',
        // Sem travessão de propósito: a Helvetica embutida no PDF não desenha
        // U+2014 (o mesmo motivo pelo qual `pdfLabelValue` usa hífen simples).
        description: 'Bateria - trator Massey, no 4292. Levou o rapaz do sitio.',
        items: [
          SaleItem(
            id: 'i1',
            name: 'Bateria 60Ah',
            quantity: '1',
            unitPrice: '250.00',
            subtotal: '250.00',
          ),
        ],
      );
      ehPdfValido(
        await buildSalePdf(venda, PdfPageFormat.a4, company: empresa),
        'PDF da venda com observação',
      );
    });
  });
}
