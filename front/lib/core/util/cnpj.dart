import 'package:flutter/services.dart';

/// CNPJ helpers (validação + máscara). Espelha a regra do backend
/// (`back/src/modules/auth/cnpj.ts`). Funções puras, sem I/O.

/// Mantém só os dígitos.
String normalizeCnpj(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

const _firstWeights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
const _secondWeights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

int _checkDigit(String digits, List<int> weights) {
  var sum = 0;
  for (var i = 0; i < weights.length; i++) {
    sum += int.parse(digits[i]) * weights[i];
  }
  final mod = sum % 11;
  return mod < 2 ? 0 : 11 - mod;
}

/// `true` quando `raw` é um CNPJ estruturalmente válido (14 dígitos + DV).
bool isValidCnpj(String? raw) {
  final c = normalizeCnpj(raw);
  if (c.length != 14) return false;
  if (RegExp(r'^(\d)\1{13}$').hasMatch(c)) return false; // 000..., 111...
  if (_checkDigit(c.substring(0, 12), _firstWeights) != int.parse(c[12])) {
    return false;
  }
  return _checkDigit(c.substring(0, 13), _secondWeights) == int.parse(c[13]);
}

/// Formata dígitos como `XX.XXX.XXX/XXXX-XX`; devolve o que receber se não tiver
/// 14 dígitos (formatação parcial usada também no input enquanto digita).
String formatCnpj(String? raw) {
  final c = normalizeCnpj(raw);
  final b = StringBuffer();
  for (var i = 0; i < c.length && i < 14; i++) {
    if (i == 2 || i == 5) b.write('.');
    if (i == 8) b.write('/');
    if (i == 12) b.write('-');
    b.write(c[i]);
  }
  return b.toString();
}

/// Formatter de input que aplica a máscara de CNPJ enquanto o usuário digita.
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizeCnpj(newValue.text);
    final text = formatCnpj(digits.length > 14 ? digits.substring(0, 14) : digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
