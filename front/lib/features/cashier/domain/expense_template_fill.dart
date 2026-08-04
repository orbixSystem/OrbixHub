import 'cashier_models.dart';

/// O que um atalho de despesa fixa preenche no formulário de lançamento.
///
/// Pura e separada da tela para ser testável: é aqui que mora a decisão de quando
/// respeitar a forma sugerida pelo modelo e quando ignorá-la.
class TemplateFill {
  const TemplateFill({
    required this.category,
    required this.method,
    required this.description,
    required this.amountText,
    required this.pedeValor,
  });

  final String category;
  final String method;

  /// Nome do modelo — vira a descrição do lançamento, que é o que aparece no
  /// extrato ("Aluguel"), em vez de só a categoria genérica ("despesa").
  final String description;

  /// Texto pronto para o campo de valor; vazio quando o valor varia.
  final String amountText;

  /// Modelo sem valor fechado: o foco vai para o campo de valor em vez de o
  /// operador achar que já está tudo preenchido e confirmar um lançamento errado.
  final bool pedeValor;
}

/// Aplica um modelo respeitando a config do caixa.
///
/// Duas correções que a tela sozinha erraria:
/// 1. **Forma indisponível** — o tenant pode ter desligado o Pix na config depois
///    de cadastrar "Aluguel · Pix". Sugerir uma forma que não está na lista
///    deixaria o dropdown num valor inválido, então cai na forma atual.
/// 2. **Sangria é gaveta** — retirada de dinheiro é sempre em espécie, como no
///    resto do módulo; a sugestão do modelo não manda nisso.
TemplateFill fillFromTemplate(
  ExpenseTemplate tpl, {
  required List<String> paymentMethods,
  required String currentMethod,
}) {
  final category = tpl.category;
  final sugerida = tpl.method;
  final String method;
  if (category == 'sangria') {
    method = 'dinheiro';
  } else if (sugerida != null && paymentMethods.contains(sugerida)) {
    method = sugerida;
  } else {
    method = currentMethod;
  }
  return TemplateFill(
    category: category,
    method: method,
    description: tpl.name,
    // Sem centavos quando é valor redondo — "1200" lê melhor que "1200,00" num
    // campo que o operador pode querer ajustar.
    amountText: tpl.temValor ? _valorTexto(tpl.valor) : '',
    pedeValor: !tpl.temValor,
  );
}

String _valorTexto(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}
