import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../di.dart';
import '../../features/auth/presentation/session_state.dart';

/// Acesso ao NICHO do tenant a partir de qualquer tela.
///
/// Tudo aqui deriva do `/me`, que é a fonte de verdade que já dirige menu,
/// papéis e módulos. Nenhum texto de vertical e nenhuma capacidade são
/// decididos no Flutter — o app só lê o que o servidor resolveu (regra 4).
///
/// Antes disso, as telas adivinhavam o nicho farejando o texto: o botão de
/// consulta por placa aparecia se o rótulo do campo contivesse "placa". Com
/// isso, renomear um campo mudava comportamento — e um nicho novo não tinha
/// como ligar a capacidade.

/// Textos do nicho, já resolvidos (padrão → vertical → override do tenant).
final vocabProvider = Provider<Map<String, String>>((ref) {
  final me = ref.watch(sessionControllerProvider).meOrNull;
  return me?.vocab ?? const <String, String>{};
});

/// Capacidades ligadas para este tenant.
final featuresProvider = Provider<Set<String>>((ref) {
  final me = ref.watch(sessionControllerProvider).meOrNull;
  return (me?.features ?? const <String>[]).toSet();
});

/// Chave do nicho (`veiculos`, `equipamentos`), ou null enquanto não há sessão.
final verticalProvider = Provider<String?>((ref) {
  return ref.watch(sessionControllerProvider).meOrNull?.vertical;
});

/// Uma capacidade está ligada? Use para MOSTRAR/ESCONDER — o backend continua
/// sendo a verdade, e 403 segue tratado com elegância. Esconder ≠ proteger.
final hasFeatureProvider = Provider.family<bool, String>((ref, key) {
  return ref.watch(featuresProvider).contains(key);
});

/// Chaves de capacidade conhecidas pelo app. Constantes existem para o
/// compilador pegar erro de digitação; a LISTA do que está ligado continua
/// vindo do servidor.
abstract final class Features {
  /// Consulta do identificador numa base externa (placa, nº de série).
  static const identifierLookup = 'customers.identifierLookup';

  /// Autocomplete encadeado (marca → modelo → ano).
  static const atributosCascata = 'customers.atributosCascata';

  /// Ficha técnica em PDF do objeto.
  static const fichaTecnica = 'customers.fichaTecnica';

  /// Link público de acompanhamento da OS.
  static const trackingLink = 'os.trackingLink';
}

/// Açúcar para ler um texto do nicho com fallback.
extension VocabRef on WidgetRef {
  String vocab(String key, String fallback) =>
      read(vocabProvider)[key] ?? fallback;

  bool hasFeature(String key) => read(featuresProvider).contains(key);
}

/// Mesma coisa a partir de um [Me] já em mãos (usado em funções puras e testes).
extension MeVocab on Me {
  String vocabOr(String key, String fallback) => vocab[key] ?? fallback;
}

/// Ícone do objeto atendido, escolhido pelo NICHO.
///
/// O servidor manda o NOME do ícone (`objeto.icone`), não o ícone — `IconData`
/// não é serializável, e é o mesmo padrão que o tema já usa (o back guarda a
/// escolha, a UI mapeia). Nome desconhecido cai no genérico, então um pacote
/// novo nunca deixa a tela sem ícone.
IconData iconeDoObjeto(Map<String, String> vocab) =>
    switch (vocab['objeto.icone']) {
      'veiculo' => Icons.directions_car_outlined,
      'moto' => Icons.two_wheeler_outlined,
      'pet' => Icons.pets_outlined,
      'pessoa' => Icons.person_outline,
      _ => Icons.inventory_2_outlined,
    };

/// Versão preenchida/arredondada, para os pontos que usavam `*_rounded`.
IconData iconeDoObjetoCheio(Map<String, String> vocab) =>
    switch (vocab['objeto.icone']) {
      'veiculo' => Icons.directions_car_rounded,
      'moto' => Icons.two_wheeler_rounded,
      'pet' => Icons.pets_rounded,
      'pessoa' => Icons.person_rounded,
      _ => Icons.inventory_2_rounded,
    };

/// Ícone do objeto a partir da sessão.
final objetoIconProvider =
    Provider<IconData>((ref) => iconeDoObjeto(ref.watch(vocabProvider)));

final objetoIconCheioProvider =
    Provider<IconData>((ref) => iconeDoObjetoCheio(ref.watch(vocabProvider)));
