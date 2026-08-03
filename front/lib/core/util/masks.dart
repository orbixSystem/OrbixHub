import 'package:flutter/services.dart';

import 'cnpj.dart';
export 'cnpj.dart'; // reexporta normalizeCnpj/isValidCnpj/formatCnpj/CnpjInputFormatter

/// Máscaras e helpers de formatação BR (funções puras + `TextInputFormatter`s).
/// Segue o padrão de `cnpj.dart`. Sem libs externas.

String _digits(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

// --------------------------------------------------------------------------
// Telefone — fixo (10 dígitos) ou celular (11). Máscara progressiva:
//   (11) 3456-7890   /   (11) 91234-5678
// --------------------------------------------------------------------------
String normalizePhone(String? raw) => _digits(raw);

String formatPhone(String? raw) {
  final d = _digits(raw);
  if (d.isEmpty) return '';
  final b = StringBuffer('(');
  for (var i = 0; i < d.length && i < 11; i++) {
    if (i == 2) b.write(') ');
    // Hífen antes do último bloco de 4: pos 6 (fixo, 10 díg.) ou 7 (cel, 11).
    if ((d.length <= 10 && i == 6) || (d.length >= 11 && i == 7)) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// `true` se tem 10 (fixo) ou 11 (celular) dígitos — validação estrutural leve.
bool isValidPhone(String? raw) {
  final n = _digits(raw).length;
  return n == 10 || n == 11;
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue v) {
    final text = formatPhone(v.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// --------------------------------------------------------------------------
// CPF — XXX.XXX.XXX-XX + validação de dígito verificador.
// --------------------------------------------------------------------------
String normalizeCpf(String? raw) => _digits(raw);

String formatCpf(String? raw) {
  final c = normalizeCpf(raw);
  final b = StringBuffer();
  for (var i = 0; i < c.length && i < 11; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(c[i]);
  }
  return b.toString();
}

bool isValidCpf(String? raw) {
  final c = normalizeCpf(raw);
  if (c.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(c)) return false; // 000..., 111...
  int dv(int len) {
    var sum = 0;
    for (var i = 0; i < len; i++) {
      sum += int.parse(c[i]) * ((len + 1) - i);
    }
    final mod = (sum * 10) % 11;
    return mod == 10 ? 0 : mod;
  }

  return dv(9) == int.parse(c[9]) && dv(10) == int.parse(c[10]);
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue v) {
    final digits = normalizeCpf(v.text);
    final text = formatCpf(digits.length > 11 ? digits.substring(0, 11) : digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// --------------------------------------------------------------------------
// Documento PF/PJ — decide CPF ou CNPJ pelo tipo do cliente.
// --------------------------------------------------------------------------

/// Formatter de documento por tipo: `'PJ'` → CNPJ, senão CPF.
TextInputFormatter documentFormatter(String type) =>
    type == 'PJ' ? CnpjInputFormatter() : CpfInputFormatter();

/// `true` se o documento (opcional) está vazio OU válido para o [type].
bool isValidDocument(String? raw, String type) {
  final d = _digits(raw);
  if (d.isEmpty) return true; // documento é opcional
  return type == 'PJ' ? isValidCnpj(raw) : isValidCpf(raw);
}

// --------------------------------------------------------------------------
// CEP — XXXXX-XXX.
// --------------------------------------------------------------------------
String formatCep(String? raw) {
  final c = _digits(raw);
  final b = StringBuffer();
  for (var i = 0; i < c.length && i < 8; i++) {
    if (i == 5) b.write('-');
    b.write(c[i]);
  }
  return b.toString();
}

bool isValidCep(String? raw) => _digits(raw).length == 8;

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue v) {
    final text = formatCep(v.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// --------------------------------------------------------------------------
// Placa — antiga (ABC1234) ou Mercosul (ABC1D23). 7 chars, MAIÚSCULO.
// --------------------------------------------------------------------------
final _plate = RegExp(r'^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$');

bool isValidPlate(String? raw) =>
    _plate.hasMatch((raw ?? '').toUpperCase().replaceAll(RegExp(r'[^0-9A-Za-z]'), ''));

/// Só letras/dígitos, MAIÚSCULO, no máximo 7 — serve placa e afins.
class PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue v) {
    final clean = v.text.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
    final text = clean.length > 7 ? clean.substring(0, 7) : clean;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Valor decimal em pt-BR: dígitos + UM separador, com casas limitadas.
///
/// `keyboardType: numberWithOptions(decimal: true)` só SUGERE o teclado no
/// celular — no desktop e na web não barra nada, e era por isso que a venda
/// avulsa aceitava letras. Este formatter é a barreira real.
///
/// Aceita vírgula ou ponto e normaliza para VÍRGULA (padrão brasileiro); o
/// parse do app já troca vírgula por ponto antes do `double.tryParse`
/// (`Validators.positiveNumber`, `_parseAmount` do caixa), então o texto
/// produzido segue parseável.
///
/// `decimals` = casas permitidas: 2 para dinheiro, 3 para quantidade.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter([this.decimals = 2]);

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) {
    final buf = StringBuffer();
    var separador = false;
    var casas = 0;
    for (final ch in v.text.split('')) {
      if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) {
        // Dígito depois do separador conta como casa decimal; além do teto, ignora.
        if (separador) {
          if (casas >= decimals) continue;
          casas++;
        }
        buf.write(ch);
        continue;
      }
      // Segundo separador (ou qualquer outro caractere) é descartado.
      if ((ch == ',' || ch == '.') && !separador) {
        separador = true;
        buf.write(',');
      }
    }
    final texto = buf.toString();
    // Nada mudou de fato: preserva a seleção que o usuário já tinha.
    if (texto == v.text) return v;
    // Digitação recusada por completo: mantém o estado anterior (não "pula" o
    // cursor para o fim de um texto que o usuário não alterou).
    if (texto == old.text) return old;
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Só dígitos (para EAN/GTIN, NCM, código de serviço, etc.), com teto opcional.
class DigitsOnlyFormatter extends TextInputFormatter {
  const DigitsOnlyFormatter([this.maxLength]);
  final int? maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue v) {
    var d = _digits(v.text);
    if (maxLength != null && d.length > maxLength!) d = d.substring(0, maxLength);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
