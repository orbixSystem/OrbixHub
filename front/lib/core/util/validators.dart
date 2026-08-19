import 'masks.dart';

/// Validadores de formulário: `String? Function(String?)` (mensagem PT-BR ou
/// null). Compõe com [Validators.combine]. Uso:
/// `validator: Validators.combine([Validators.required('Nome')])`.
typedef Validator = String? Function(String?);

class Validators {
  /// Roda os validadores em ordem; devolve a 1ª mensagem de erro (ou null).
  static Validator combine(List<Validator> vs) => (value) {
        for (final f in vs) {
          final e = f(value);
          if (e != null) return e;
        }
        return null;
      };

  static Validator required([String field = 'Este campo']) =>
      (v) => (v == null || v.trim().isEmpty) ? '$field é obrigatório.' : null;

  static Validator minLength(int n, [String field = 'Este campo']) => (v) =>
      (v != null && v.trim().isNotEmpty && v.trim().length < n)
          ? '$field: mínimo de $n caracteres.'
          : null;

  static Validator maxLength(int n) =>
      (v) => (v != null && v.length > n) ? 'Máximo de $n caracteres.' : null;

  static Validator email({bool optional = true}) => (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return optional ? null : 'E-mail é obrigatório.';
        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
            ? null
            : 'E-mail inválido.';
      };

  static Validator phone({bool optional = true}) => (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return optional ? null : 'Telefone é obrigatório.';
        return isValidPhone(s) ? null : 'Telefone inválido — DDD + número.';
      };

  /// Documento por tipo do cliente (`'PF'` → CPF, `'PJ'` → CNPJ). Opcional:
  /// vazio passa; se preenchido, exige DV válido.
  static Validator document(String type) => (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return null;
        return isValidDocument(s, type)
            ? null
            : (type == 'PJ' ? 'CNPJ inválido.' : 'CPF inválido.');
      };

  static Validator cep({bool optional = true}) => (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return optional ? null : 'CEP é obrigatório.';
        return isValidCep(s) ? null : 'CEP inválido.';
      };

  static Validator plate({bool optional = true}) => (v) {
        final s = v?.trim() ?? '';
        if (s.isEmpty) return optional ? null : 'Placa é obrigatória.';
        return isValidPlate(s) ? null : 'Placa inválida (ex.: ABC1D23).';
      };

  /// Número > 0 — preços, quantidades. Aceita vírgula ou ponto.
  /// Número >= 0 (zero é resposta válida, não erro).
  ///
  /// Existe para o recebimento de título, onde ZERO significa "não recebi nada,
  /// vai ficar fiado" — uma decisão de negócio legítima que o
  /// [positiveNumber] rejeitava. Campo vazio continua obrigatório: em branco é
  /// falta de resposta, zero é uma resposta.
  static Validator nonNegativeNumber({String field = 'Valor'}) => (v) {
        final s = (v ?? '').trim().replaceAll(',', '.');
        if (s.isEmpty) return '$field é obrigatório.';
        final n = double.tryParse(s);
        if (n == null) return '$field inválido.';
        return n >= 0 ? null : '$field não pode ser negativo.';
      };

  static Validator positiveNumber({
    bool optional = false,
    String field = 'Valor',
  }) =>
      (v) {
        final s = (v ?? '').trim().replaceAll(',', '.');
        if (s.isEmpty) return optional ? null : '$field é obrigatório.';
        final n = double.tryParse(s);
        if (n == null) return '$field inválido.';
        return n > 0 ? null : '$field deve ser maior que zero.';
      };
}
