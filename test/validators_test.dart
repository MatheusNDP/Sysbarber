import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/validators.dart';

/// ============================================================
/// TESTES UNITÁRIOS — Validadores
/// Testam as regras de validação de forma isolada.
/// ============================================================
void main() {
  group('Validação de E-mail', () {
    test('e-mails válidos devem passar', () {
      expect(Validators.emailValido('joao@email.com'), true);
      expect(Validators.emailValido('maria.silva@empresa.com.br'), true);
      expect(Validators.emailValido('teste_123@dominio.org'), true);
    });

    test('e-mails inválidos devem falhar', () {
      expect(Validators.emailValido('semarroba.com'), false);
      expect(Validators.emailValido('@semNome.com'), false);
      expect(Validators.emailValido('sem@dominio'), false);
      expect(Validators.emailValido(''), false);
      expect(Validators.emailValido('espaco @email.com'), false);
    });
  });

  group('Validação de Nome', () {
    test('nome com 3+ caracteres é válido', () {
      expect(Validators.nomeValido('Ana'), true);
      expect(Validators.nomeValido('João da Silva'), true);
    });

    test('nome com menos de 3 caracteres é inválido', () {
      expect(Validators.nomeValido('Jo'), false);
      expect(Validators.nomeValido(''), false);
      expect(Validators.nomeValido('  '), false);
    });
  });

  group('Validação de Telefone', () {
    test('telefone com 8+ caracteres é válido', () {
      expect(Validators.telefoneValido('99999999'), true);
      expect(Validators.telefoneValido('(67) 99999-9999'), true);
    });

    test('telefone curto é inválido', () {
      expect(Validators.telefoneValido('123'), false);
      expect(Validators.telefoneValido(''), false);
    });
  });

  group('Validação de Senha', () {
    test('senha com 6+ caracteres é válida', () {
      expect(Validators.senhaValida('123456'), true);
      expect(Validators.senhaValida('senhaForte123'), true);
    });

    test('senha curta é inválida', () {
      expect(Validators.senhaValida('123'), false);
      expect(Validators.senhaValida(''), false);
    });
  });

  group('Validação completa de Cadastro', () {
    test('dados válidos retornam null (sem erro)', () {
      final erro = Validators.validarCadastro(
        nome: 'João Silva',
        email: 'joao@email.com',
        telefone: '(67) 99999-9999',
        senha: '123456',
      );
      expect(erro, isNull);
    });

    test('nome inválido retorna mensagem de erro', () {
      final erro = Validators.validarCadastro(
        nome: 'Jo',
        email: 'joao@email.com',
        telefone: '(67) 99999-9999',
        senha: '123456',
      );
      expect(erro, contains('Nome'));
    });

    test('e-mail inválido retorna mensagem de erro', () {
      final erro = Validators.validarCadastro(
        nome: 'João Silva',
        email: 'emailerrado',
        telefone: '(67) 99999-9999',
        senha: '123456',
      );
      expect(erro, contains('mail'));
    });

    test('senha curta retorna mensagem de erro', () {
      final erro = Validators.validarCadastro(
        nome: 'João Silva',
        email: 'joao@email.com',
        telefone: '(67) 99999-9999',
        senha: '123',
      );
      expect(erro, contains('Senha'));
    });
  });
}
