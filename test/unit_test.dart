import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/models/models.dart';

/// ============================================================
/// TESTES UNITÁRIOS
/// Testam funções/unidades isoladas, sem dependências externas
/// como banco de dados ou rede.
/// ============================================================
void main() {
  group('Hash de Senha (segurança)', () {
    test('deve gerar hash diferente da senha original', () {
      const senha = 'minhaSenha123';
      final hash = DatabaseService.hashSenha(senha);

      expect(hash, isNot(equals(senha)));
      expect(hash.isNotEmpty, true);
    });

    test('mesma senha deve gerar sempre o mesmo hash (determinístico)', () {
      const senha = 'demo1234';
      final hash1 = DatabaseService.hashSenha(senha);
      final hash2 = DatabaseService.hashSenha(senha);

      expect(hash1, equals(hash2));
    });

    test('senhas diferentes devem gerar hashes diferentes', () {
      final hashA = DatabaseService.hashSenha('senhaA');
      final hashB = DatabaseService.hashSenha('senhaB');

      expect(hashA, isNot(equals(hashB)));
    });

    test('hash SHA-256 deve ter 64 caracteres hexadecimais', () {
      final hash = DatabaseService.hashSenha('qualquercoisa');
      expect(hash.length, equals(64));
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash), true);
    });
  });

  group('Entidade Cliente (serialização)', () {
    test('toMap deve converter cliente em mapa corretamente', () {
      final cliente = Cliente(
        id: 1,
        nome: 'João Teste',
        email: 'joao@teste.com',
        telefone: '(67) 99999-9999',
        senhaHash: 'hash123',
        criadoEm: DateTime(2026, 1, 1),
      );

      final map = cliente.toMap();

      expect(map['id'], 1);
      expect(map['nome'], 'João Teste');
      expect(map['email'], 'joao@teste.com');
      expect(map['telefone'], '(67) 99999-9999');
      expect(map['senha_hash'], 'hash123');
    });

    test('fromMap deve reconstruir cliente a partir do mapa', () {
      final map = {
        'id': 5,
        'nome': 'Maria',
        'email': 'maria@teste.com',
        'telefone': '(67) 98888-8888',
        'senha_hash': 'abc',
        'criado_em': '2026-01-15T10:30:00.000',
      };

      final cliente = Cliente.fromMap(map);

      expect(cliente.id, 5);
      expect(cliente.nome, 'Maria');
      expect(cliente.email, 'maria@teste.com');
      expect(cliente.criadoEm.year, 2026);
      expect(cliente.criadoEm.month, 1);
      expect(cliente.criadoEm.day, 15);
    });
  });

  group('Entidade Servico (serialização)', () {
    test('toMap e fromMap devem ser consistentes (ida e volta)', () {
      final original = Servico(
        id: 3,
        nome: 'Corte + Barba',
        descricao: 'Combo completo',
        preco: 55.0,
        duracaoMinutos: 50,
        icone: '💈',
      );

      final reconstruido = Servico.fromMap(original.toMap());

      expect(reconstruido.id, original.id);
      expect(reconstruido.nome, original.nome);
      expect(reconstruido.preco, original.preco);
      expect(reconstruido.duracaoMinutos, original.duracaoMinutos);
      expect(reconstruido.icone, original.icone);
    });
  });

  group('Enum StatusAgendamento', () {
    test('deve converter status para valor de banco e voltar', () {
      for (final status in StatusAgendamento.values) {
        final dbValue = status.dbValue;
        final reconstruido = StatusAgendamentoX.fromDb(dbValue);
        expect(reconstruido, equals(status));
      }
    });

    test('deve ter labels corretos em português', () {
      expect(StatusAgendamento.confirmado.label, 'Confirmado');
      expect(StatusAgendamento.cancelado.label, 'Cancelado');
      expect(StatusAgendamento.finalizado.label, 'Finalizado');
    });

    test('valor desconhecido deve retornar confirmado como padrão', () {
      final status = StatusAgendamentoX.fromDb('valor_invalido');
      expect(status, StatusAgendamento.confirmado);
    });
  });

  group('Enum MetodoPagamento', () {
    test('deve ter labels corretos', () {
      expect(MetodoPagamento.pix.label, 'Pix');
      expect(MetodoPagamento.cartao.label, 'Cartão');
      expect(MetodoPagamento.dinheiro.label, 'Dinheiro');
    });
  });

  group('Entidade Agendamento (serialização)', () {
    test('toMap deve incluir todas as chaves estrangeiras', () {
      final ag = Agendamento(
        id: 1,
        idCliente: 10,
        idBarbeiro: 20,
        idServico: 30,
        dataHora: DateTime(2026, 5, 27, 10, 0),
        status: StatusAgendamento.confirmado,
      );

      final map = ag.toMap();

      expect(map['id_cliente'], 10);
      expect(map['id_barbeiro'], 20);
      expect(map['id_servico'], 30);
      expect(map['status'], 'confirmado');
    });
  });
}
