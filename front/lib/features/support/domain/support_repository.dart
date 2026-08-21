import 'support_models.dart';

/// Conversa do ambiente com o suporte da Orbix. Uma thread por empresa.
abstract interface class SupportRepository {
  /// Thread inteira, mais antiga primeiro. Ler marca as respostas da Orbix
  /// como lidas no servidor — abrir a tela É a leitura.
  Future<List<SupportMessage>> thread();

  /// Quantas respostas da Orbix ainda não foram lidas.
  Future<int> unread();

  Future<SupportMessage> enviar(String body);
}
