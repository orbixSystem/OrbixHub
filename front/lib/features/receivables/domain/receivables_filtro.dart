import 'receivables_query.dart';

/// Regra PURA do "A receber" — irmã de `back/.../receivables.filtro.ts`.
///
/// Existe porque o offline RECALCULA a carteira das linhas locais e precisa
/// filtrar, ordenar e paginar igual ao servidor. Dart e TypeScript não
/// compartilham código, então são duas implementações — e é exatamente onde
/// bug nasce (foi assim que o offline devolvia todos os títulos sem cliente
/// enquanto o servidor já filtrava por apelido). A mitigação é concreta: as
/// duas rodam a MESMA tabela de casos, `receivables-filtro.casos.json`, no
/// backend. Divergir vira teste vermelho dos dois lados.
class TituloParaFiltro {
  const TituloParaFiltro({
    required this.origin,
    required this.createdAt,
    required this.balance,
    required this.proximaParcelaEm,
  });

  /// 'os' | 'sale'
  final String origin;
  final String? createdAt;
  final num balance;

  /// Próxima parcela em aberto (YYYY-MM-DD); null = sem plano.
  final String? proximaParcelaEm;
}

class DevedorParaFiltro {
  const DevedorParaFiltro({
    required this.customerId,
    required this.customerName,
    required this.totalDue,
    required this.titleCount,
    required this.oldestAt,
    required this.titulos,
  });

  final String? customerId;
  final String customerName;
  final num totalDue;
  final int titleCount;
  final String? oldestAt;
  final List<TituloParaFiltro> titulos;
}

class DevedorClassificado extends DevedorParaFiltro {
  const DevedorClassificado({
    required super.customerId,
    required super.customerName,
    required super.totalDue,
    required super.titleCount,
    required super.oldestAt,
    required super.titulos,
    required this.nextDueAt,
    required this.overdue,
  });

  /// Vencimento mais próximo entre os títulos (parcela, senão data do título).
  final String? nextDueAt;

  /// Ao menos UM título vencido — não é preciso estar tudo vencido.
  final bool overdue;
}

/// Sem acento e em minúsculas — a mesma normalização do servidor (NFD sem
/// marcas). Tabela fixa porque Dart não tem `String.normalize`.
String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString().toLowerCase();
}

/// "YYYY-MM-DD" em UTC — comparação por DIA, não por instante (igual ao TS).
/// Data pura ("2026-09-10") é lida como UTC, como o `new Date()` do JS faz;
/// `DateTime.parse` sozinho a leria no fuso local e mudaria o dia a leste de UTC.
///
/// Devolve `null` quando a data é ilegível. Offline os valores vêm do espelho
/// local (JSON cru gravado pelo pull), então uma linha estranha é possível — e
/// derrubar a carteira inteira com `FormatException` seria o pior desfecho: sem
/// rede, esta tela é a ÚNICA fonte de cobrança que o operador tem.
String? _diaUtc(String iso) {
  final normalizada = iso.length == 10 ? '${iso}T00:00:00Z' : iso;
  final d = DateTime.tryParse(normalizada);
  return d?.toUtc().toIso8601String().substring(0, 10);
}

/// O vencimento é o PRAZO COMBINADO — a próxima parcela em aberto. Sem plano de
/// prazo não há vencimento: `null` (fiar sem combinar data é legítimo; atraso
/// sem prazo combinado não existe). Data ÚNICA combinada é um plano de UMA
/// parcela, então chega aqui por `proximaParcelaEm` como qualquer outra.
String? _vencimentoEfetivo(TituloParaFiltro t) => t.proximaParcelaEm;

DevedorClassificado classificar(DevedorParaFiltro d, DateTime hoje) {
  final hojeDia = _diaUtc(hoje.toUtc().toIso8601String())!;
  String? nextDueAt;
  var overdue = false;
  for (final t in d.titulos) {
    final v = _vencimentoEfetivo(t);
    if (v == null) continue;
    final dia = _diaUtc(v);
    // Data ilegível é tratada como SEM prazo: acusar vencimento por causa de
    // lixo de dado seria pior do que não acusar nada.
    if (dia == null) continue;
    final atual = nextDueAt == null ? null : _diaUtc(nextDueAt);
    if (atual == null || dia.compareTo(atual) < 0) nextDueAt = v;
    if (dia.compareTo(hojeDia) < 0) overdue = true;
  }
  return DevedorClassificado(
    customerId: d.customerId,
    customerName: d.customerName,
    totalDue: d.totalDue,
    titleCount: d.titleCount,
    oldestAt: d.oldestAt,
    titulos: d.titulos,
    nextDueAt: nextDueAt,
    overdue: overdue,
  );
}

/// Genérico como no TS: quem chama pode passar um subtipo (o teste carrega o
/// `id` do caso; o offline carrega o `Debtor` já montado) e recebe o mesmo tipo.
List<T> filtrarDevedores<T extends DevedorClassificado>(
  List<T> lista, {
  String? q,
  required VencimentoFiltro vencimento,
  required OrigemFiltro origem,
  required DateTime hoje,
}) {
  final hojeDia = _diaUtc(hoje.toUtc().toIso8601String())!;
  final limite7Dia = _diaUtc(
    hoje.toUtc().add(const Duration(days: 7)).toIso8601String(),
  )!;
  final termo = (q ?? '').trim().isEmpty ? '' : semAcento(q!.trim());

  return lista.where((d) {
    if (origem != OrigemFiltro.todos &&
        !d.titulos.any((t) => t.origin == origem.wire)) {
      return false;
    }
    if (termo.isNotEmpty && !semAcento(d.customerName).contains(termo)) {
      return false;
    }
    switch (vencimento) {
      case VencimentoFiltro.todos:
        return true;
      case VencimentoFiltro.vencidos:
        return d.overdue;
      case VencimentoFiltro.vence7:
        if (d.overdue || d.nextDueAt == null) return false;
        final dia = _diaUtc(d.nextDueAt!);
        if (dia == null) return false;
        return dia.compareTo(hojeDia) >= 0 && dia.compareTo(limite7Dia) <= 0;
      case VencimentoFiltro.aVencer:
        return !d.overdue && d.nextDueAt != null;
      case VencimentoFiltro.semPrazo:
        // Quem não tem prazo não some: tem fila própria, porque a ação aqui é
        // outra — não é cobrar atraso, é combinar uma data.
        return d.nextDueAt == null;
    }
  }).toList();
}

/// Desempate SEMPRE por nome sem acento — a mesma colação do servidor.
int _porNome(DevedorClassificado a, DevedorClassificado b) =>
    semAcento(a.customerName).compareTo(semAcento(b.customerName));

List<T> ordenarDevedores<T extends DevedorClassificado>(
  List<T> lista,
  OrdemDevedores ordem,
) {
  final copia = <T>[...lista];
  switch (ordem) {
    case OrdemDevedores.valor:
      copia.sort((a, b) {
        final c = b.totalDue.compareTo(a.totalDue);
        return c != 0 ? c : _porNome(a, b);
      });
    case OrdemDevedores.maisAntigo:
      copia.sort((a, b) {
        if (a.oldestAt == b.oldestAt) return _porNome(a, b);
        if (a.oldestAt == null) return 1;
        if (b.oldestAt == null) return -1;
        return a.oldestAt!.compareTo(b.oldestAt!);
      });
    case OrdemDevedores.nome:
      copia.sort(_porNome);
    case OrdemDevedores.vencimento:
      copia.sort((a, b) {
        if (a.nextDueAt == b.nextDueAt) return _porNome(a, b);
        // Sem data (ou com data ilegível) vai para o fim.
        final da = a.nextDueAt == null ? null : _diaUtc(a.nextDueAt!);
        final dbb = b.nextDueAt == null ? null : _diaUtc(b.nextDueAt!);
        if (da == null && dbb == null) return _porNome(a, b);
        if (da == null) return 1;
        if (dbb == null) return -1;
        return da.compareTo(dbb);
      });
  }
  return copia;
}

({List<T> items, int total}) paginar<T>(List<T> lista, int page, int pageSize) {
  final p = page < 1 ? 1 : page;
  final inicio = (p - 1) * pageSize;
  if (inicio >= lista.length) return (items: <T>[], total: lista.length);
  final fim = (inicio + pageSize).clamp(0, lista.length);
  return (items: lista.sublist(inicio, fim), total: lista.length);
}
