import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';

/// O campo "Responsável" da criação de OS é OBRIGATÓRIO e nascia vazio: quem
/// abria a OS tinha de escolher sem nenhuma sugestão, o que confundia na
/// recepção. Agora vem pré-selecionado com o usuário logado — que quase sempre é
/// quem responde pela OS — e segue editável.
///
/// `assigned_to` guarda o userId (não o membershipId), então o id da sessão casa
/// direto com `MemberOption.id`.

const _ana = '11111111-1111-1111-1111-111111111111';
const _bruno = '22222222-2222-2222-2222-222222222222';
const _forasteiro = '99999999-9999-9999-9999-999999999999';

const _equipe = [
  MemberOption(id: _ana, name: 'Ana Mecânica'),
  MemberOption(id: _bruno, name: 'Bruno Funilaria'),
];

void main() {
  group('responsavelSugerido', () {
    test('sugere o usuário logado quando ele é membro da equipe', () {
      expect(
        responsavelSugerido(meuUserId: _ana, membros: _equipe),
        _ana,
      );
    });

    test('sugere o outro membro se for ele quem está logado', () {
      expect(
        responsavelSugerido(meuUserId: _bruno, membros: _equipe),
        _bruno,
      );
    });

    test('não inventa responsável quando o logado não é membro elegível', () {
      expect(
        responsavelSugerido(meuUserId: _forasteiro, membros: _equipe),
        isNull,
        reason: 'dono que não executa serviço não deve ser atribuído sozinho',
      );
    });

    test('sem sessão, não sugere nada', () {
      expect(responsavelSugerido(meuUserId: null, membros: _equipe), isNull);
      expect(responsavelSugerido(meuUserId: '', membros: _equipe), isNull);
    });

    test('equipe vazia não sugere nada', () {
      expect(
        responsavelSugerido(meuUserId: _ana, membros: const []),
        isNull,
      );
    });

    test('preserva a escolha já feita pelo usuário', () {
      // A lista de membros carrega de forma assíncrona e pode chegar DEPOIS de
      // o usuário ter escolhido — a sugestão não pode atropelar isso.
      expect(
        responsavelSugerido(
          meuUserId: _ana,
          membros: _equipe,
          jaEscolhido: _bruno,
        ),
        _bruno,
      );
    });

    test('preserva a escolha mesmo quando ela não está na lista carregada', () {
      expect(
        responsavelSugerido(
          meuUserId: _ana,
          membros: const [],
          jaEscolhido: _bruno,
        ),
        _bruno,
      );
    });
  });
}
