import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/database_service.dart';

/// Testes unitários das regras puras: hash de senha e serialização das
/// entidades. Nenhum deles toca no banco de dados.
void main() {
  group('Hash de senha (SHA-256)', () {
    test('o hash é diferente da senha original', () {
      const senha = 'minhaSenha123';
      final hash = DatabaseService.hashSenha(senha);
      expect(hash, isNot(equals(senha)));
      expect(hash.contains(senha), isFalse);
    });

    test('a mesma senha gera sempre o mesmo hash (determinístico)', () {
      final a = DatabaseService.hashSenha('demo1234');
      final b = DatabaseService.hashSenha('demo1234');
      expect(a, equals(b));
    });

    test('senhas diferentes geram hashes diferentes', () {
      final a = DatabaseService.hashSenha('demo1234');
      final b = DatabaseService.hashSenha('demo12345');
      expect(a, isNot(equals(b)));
    });

    test('o hash tem 64 caracteres hexadecimais', () {
      final hash = DatabaseService.hashSenha('qualquer');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });
  });

  group('Entidade Cliente', () {
    const cliente = Cliente(
      id: 1,
      nome: 'João da Silva',
      email: 'joao@teste.com',
      telefone: '(67) 99999-1111',
      senhaHash: 'hash_qualquer',
      criadoEm: '2026-08-10T10:00:00.000',
    );

    test('toMap() converte para as colunas do banco', () {
      final mapa = cliente.toMap();
      expect(mapa['id'], 1);
      expect(mapa['nome'], 'João da Silva');
      expect(mapa['email'], 'joao@teste.com');
      expect(mapa['telefone'], '(67) 99999-1111');
      expect(mapa['senha_hash'], 'hash_qualquer');
      expect(mapa['criado_em'], '2026-08-10T10:00:00.000');
    });

    test('fromMap() reconstrói o objeto corretamente', () {
      final reconstruido = Cliente.fromMap(cliente.toMap());
      expect(reconstruido.id, cliente.id);
      expect(reconstruido.nome, cliente.nome);
      expect(reconstruido.email, cliente.email);
      expect(reconstruido.telefone, cliente.telefone);
      expect(reconstruido.senhaHash, cliente.senhaHash);
      expect(reconstruido.criadoEm, cliente.criadoEm);
    });
  });

  group('Entidade Servico', () {
    test('toMap() → fromMap() preserva todos os dados', () {
      const original = Servico(
        id: 3,
        nome: 'Corte + Barba',
        descricao: 'Combo completo',
        preco: 55.00,
        duracaoMinutos: 50,
        icone: '💈',
      );

      final reconstruido = Servico.fromMap(original.toMap());

      expect(reconstruido.id, original.id);
      expect(reconstruido.nome, original.nome);
      expect(reconstruido.descricao, original.descricao);
      expect(reconstruido.preco, original.preco);
      expect(reconstruido.duracaoMinutos, original.duracaoMinutos);
      expect(reconstruido.icone, original.icone);
    });
  });

  group('Enum StatusAgendamento', () {
    test('dbValue e fromDb são simétricos para todos os valores', () {
      for (final status in StatusAgendamento.values) {
        expect(StatusAgendamentoX.fromDb(status.dbValue), status);
      }
      expect(StatusAgendamento.confirmado.dbValue, 'confirmado');
      expect(StatusAgendamento.cancelado.dbValue, 'cancelado');
      expect(StatusAgendamento.finalizado.dbValue, 'finalizado');
    });

    test('os labels estão em português', () {
      expect(StatusAgendamento.confirmado.label, 'Confirmado');
      expect(StatusAgendamento.cancelado.label, 'Cancelado');
      expect(StatusAgendamento.finalizado.label, 'Finalizado');
    });

    test('um valor desconhecido cai em confirmado', () {
      expect(StatusAgendamentoX.fromDb('valor_invalido'),
          StatusAgendamento.confirmado);
      expect(StatusAgendamentoX.fromDb(''), StatusAgendamento.confirmado);
    });
  });

  group('Enum MetodoPagamento', () {
    test('os labels estão corretos', () {
      expect(MetodoPagamento.pix.label, 'Pix');
      expect(MetodoPagamento.cartao.label, 'Cartão');
      expect(MetodoPagamento.dinheiro.label, 'Dinheiro');
    });
  });

  group('Entidade Agendamento', () {
    test('toMap() inclui todas as chaves estrangeiras', () {
      const agendamento = Agendamento(
        id: 7,
        idCliente: 1,
        idBarbeiro: 2,
        idServico: 3,
        dataHora: '2026-08-11T09:00:00.000',
        status: StatusAgendamento.confirmado,
      );

      final mapa = agendamento.toMap();

      expect(mapa.containsKey('id_cliente'), isTrue);
      expect(mapa.containsKey('id_barbeiro'), isTrue);
      expect(mapa.containsKey('id_servico'), isTrue);
      expect(mapa['id_cliente'], 1);
      expect(mapa['id_barbeiro'], 2);
      expect(mapa['id_servico'], 3);
      expect(mapa['data_hora'], '2026-08-11T09:00:00.000');
      expect(mapa['status'], 'confirmado');
    });
  });
}
