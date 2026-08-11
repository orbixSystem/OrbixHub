import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/os/presentation/os_status.dart';

/// O seletor de 3 botões (Em andamento / Finalizada / Cancelada) por baixo dos
/// panos ainda respeita a FSM real de 7 estados — estes testes garantem que o
/// caminho automático NUNCA propõe uma transição que o backend recusaria.
void main() {
  group('osSimpleStatusOf — resume os 7 estados em 3', () {
    test('concluida e entregue caem os DOIS em finalizada', () {
      expect(osSimpleStatusOf('concluida'), OsSimpleStatus.finalizada);
      expect(osSimpleStatusOf('entregue'), OsSimpleStatus.finalizada);
    });

    test('cancelada é cancelada', () {
      expect(osSimpleStatusOf('cancelada'), OsSimpleStatus.cancelada);
    });

    test('os quatro estados do meio do fluxo caem em em andamento', () {
      for (final s in ['aberta', 'aguardando_aprovacao', 'aprovada', 'em_execucao']) {
        expect(osSimpleStatusOf(s), OsSimpleStatus.emAndamento, reason: s);
      }
    });
  });

  group('osCaminhoAte — nunca propõe uma transição que a FSM recusaria', () {
    test('aberta → finalizada percorre TODO o fluxo positivo até entregue', () {
      expect(
        osCaminhoAte('aberta', OsSimpleStatus.finalizada),
        ['em_execucao', 'concluida', 'entregue'],
      );
    });

    test('em_execucao → finalizada pula direto (mais perto do destino)', () {
      expect(
        osCaminhoAte('em_execucao', OsSimpleStatus.finalizada),
        ['concluida', 'entregue'],
      );
    });

    test('já finalizada (concluida) só falta o último passo', () {
      expect(osCaminhoAte('concluida', OsSimpleStatus.finalizada), ['entregue']);
    });

    test('já entregue: lista vazia, é idempotente, não chama a API de novo', () {
      expect(osCaminhoAte('entregue', OsSimpleStatus.finalizada), isEmpty);
    });

    test('aberta → cancelada é um passo só', () {
      expect(osCaminhoAte('aberta', OsSimpleStatus.cancelada), ['cancelada']);
    });

    test('CONCLUÍDA NÃO PODE cancelar — a FSM do backend não permite', () {
      // Regra real: `concluida: ['entregue']` no backend, sem saída para
      // cancelada. Se isto retornasse um caminho, o botão "Cancelada" ficaria
      // habilitado e a chamada real quebraria com 400 na cara do usuário.
      expect(osCaminhoAte('concluida', OsSimpleStatus.cancelada), isNull);
    });

    test('ENTREGUE é terminal — nenhum destino tem caminho', () {
      expect(osCaminhoAte('entregue', OsSimpleStatus.finalizada), isEmpty);
      expect(osCaminhoAte('entregue', OsSimpleStatus.cancelada), isNull);
      expect(osCaminhoAte('entregue', OsSimpleStatus.emAndamento), isNull);
    });

    test('cancelada → "Em andamento" reabre (única saída real: para aberta)', () {
      expect(osCaminhoAte('cancelada', OsSimpleStatus.emAndamento), ['aberta']);
    });

    test('já em andamento, "Em andamento" não tem ação (lista vazia)', () {
      for (final s in ['aberta', 'aguardando_aprovacao', 'aprovada', 'em_execucao']) {
        expect(
          osCaminhoAte(s, OsSimpleStatus.emAndamento),
          isEmpty,
          reason: s,
        );
      }
    });

    test('aguardando_aprovacao → cancelada passa por aprovada? NÃO — direto',
        () {
      // `aguardando_aprovacao: ['aprovada', 'aberta', 'cancelada']` já tem
      // saída direta — o BFS não deve rodear por 'aprovada' antes.
      expect(
        osCaminhoAte('aguardando_aprovacao', OsSimpleStatus.cancelada),
        ['cancelada'],
      );
    });
  });
}
