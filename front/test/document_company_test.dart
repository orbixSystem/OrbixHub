import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/pdf/document_company.dart';

/// Cabeçalho dos documentos gerados.
///
/// O bundle de Configurações › Empresa é jsonb livre no servidor: chave ausente,
/// tipo errado ou string vazia são normais. Um documento não pode estourar — nem
/// sair com "CNPJ: null" — por causa de um campo mal preenchido.
void main() {
  group('companyFromSettings', () {
    test('lê todos os campos do bundle', () {
      final c = companyFromSettings(const {
        'companyName': 'Auto Elétrico São Francisco',
        'legalName': 'Bruno Cirino ME',
        'taxId': '33007505000137',
        'inscricaoEstadual': '638.011.636.111',
        'phone': '(17) 9743-7674',
        'email': 'contato@autoeletrico.com',
        'logradouro': 'Oscar Antonio da Costa',
        'numero': '1659',
        'bairro': 'Centro',
        'municipio': 'São Francisco',
        'uf': 'SP',
        'cep': '15710000',
      });
      expect(c.name, 'Auto Elétrico São Francisco');
      expect(c.legalName, 'Bruno Cirino ME');
      expect(c.documentosLinha,
          'CNPJ: 33.007.505/0001-37   IE: 638.011.636.111');
      expect(c.enderecoLinha, 'Oscar Antonio da Costa, 1659 - Centro');
      expect(c.cidadeLinha, 'São Francisco - SP   CEP: 15710-000');
      expect(c.contatoLinha,
          'Fone: (17) 9743-7674   E-mail: contato@autoeletrico.com');
    });

    test('bundle nulo ou vazio não estoura e usa o nome de reserva', () {
      expect(companyFromSettings(null, fallbackName: 'Oficina').name, 'Oficina');
      expect(
        companyFromSettings(const {}, fallbackName: 'Oficina').name,
        'Oficina',
      );
    });

    test('razão social entra como nome quando não há nome fantasia', () {
      final c = companyFromSettings(const {'legalName': 'Bruno Cirino ME'});
      expect(c.name, 'Bruno Cirino ME');
    });

    test('valores não-string e vazios caem para null (não para "null")', () {
      // jsonb livre: alguém pode ter gravado número no CEP ou string vazia.
      final c = companyFromSettings(const {
        'companyName': 'X',
        'taxId': '',
        'cep': 15710000,
        'phone': '   ',
      });
      expect(c.cnpj, isNull);
      expect(c.cep, isNull);
      expect(c.phone, isNull);
      // Sem CNPJ nem IE a linha não existe — nada de "CNPJ:" solto.
      expect(c.documentosLinha, isEmpty);
      expect(c.contatoLinha, isEmpty);
    });

    test('endereço parcial monta só o que existe, sem separadores órfãos', () {
      final so = companyFromSettings(const {'municipio': 'Marinópolis'});
      expect(so.enderecoLinha, isEmpty);
      expect(so.cidadeLinha, 'Marinópolis');

      final semNumero = companyFromSettings(const {
        'logradouro': 'Praça da Bandeira',
        'bairro': 'Centro',
      });
      expect(semNumero.enderecoLinha, 'Praça da Bandeira - Centro');
    });

    test('semDadosFiscais aponta empresa que só tem nome', () {
      expect(companyFromSettings(const {'companyName': 'X'}).semDadosFiscais,
          isTrue);
      expect(
        companyFromSettings(const {'companyName': 'X', 'phone': '1799'})
            .semDadosFiscais,
        isFalse,
      );
    });

    test('logo passa direto para o modelo', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final c = companyFromSettings(const {'companyName': 'X'}, logo: bytes);
      expect(c.logo, same(bytes));
      // Sem logo é o caso normal (empresa que não subiu imagem).
      expect(companyFromSettings(const {'companyName': 'X'}).logo, isNull);
    });
  });

  group('formataCnpj', () {
    test('14 dígitos viram CNPJ mascarado', () {
      expect(formataCnpj('33007505000137'), '33.007.505/0001-37');
      expect(formataCnpj('33.007.505/0001-37'), '33.007.505/0001-37');
    });

    test('11 dígitos viram CPF mascarado', () {
      expect(formataCnpj('12345678901'), '123.456.789-01');
    });

    test('contagem inesperada volta como está — não inventa máscara', () {
      // Documento estrangeiro ou meio digitado sai literal, em vez de virar uma
      // máscara errada num papel que o cliente leva embora.
      expect(formataCnpj('123'), '123');
      expect(formataCnpj('ABC-999'), 'ABC-999');
      expect(formataCnpj('  '), '');
    });
  });
}
