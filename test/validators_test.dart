import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/validators.dart';

/// Testes unitários das regras de validação do formulário.
void main() {
  group('Validators.emailValido', () {
    test('aceita e-mails bem formados', () {
      expect(Validators.emailValido('demo@sysbarber.com'), isTrue);
      expect(Validators.emailValido('joao.silva@teste.com.br'), isTrue);
      expect(Validators.emailValido('maria_99+tag@dominio.io'), isTrue);
    });

    test('rejeita e-mails mal formados', () {
      expect(Validators.emailValido(''), isFalse);
      expect(Validators.emailValido('sem-arroba.com'), isFalse);
      expect(Validators.emailValido('sem@dominio'), isFalse);
      expect(Validators.emailValido('@semusuario.com'), isFalse);
      expect(Validators.emailValido('espaco no@email.com'), isFalse);
    });
  });

  group('Validators.nomeValido', () {
    test('exige pelo menos 3 caracteres', () {
      expect(Validators.nomeValido('Ana'), isTrue);
      expect(Validators.nomeValido('João da Silva'), isTrue);
      expect(Validators.nomeValido(''), isFalse);
      expect(Validators.nomeValido('Jo'), isFalse);
      expect(Validators.nomeValido('   '), isFalse);
    });
  });

  group('Validators.telefoneValido', () {
    test('aceita telefones com 8 ou mais caracteres', () {
      expect(Validators.telefoneValido('99999999'), isTrue);
      expect(Validators.telefoneValido('(67) 99999-0000'), isTrue);
    });

    test('rejeita telefones curtos', () {
      expect(Validators.telefoneValido(''), isFalse);
      expect(Validators.telefoneValido('9999'), isFalse);
    });
  });

  group('Validators.senhaValida', () {
    test('aceita senhas com 6 ou mais caracteres', () {
      expect(Validators.senhaValida('123456'), isTrue);
      expect(Validators.senhaValida('demo1234'), isTrue);
    });

    test('rejeita senhas curtas', () {
      expect(Validators.senhaValida(''), isFalse);
      expect(Validators.senhaValida('12345'), isFalse);
    });
  });

  group('Validators.validarCadastro', () {
    String? validar({
      String nome = 'João da Silva',
      String email = 'joao@teste.com',
      String telefone = '(67) 99999-0000',
      String senha = 'senha123',
    }) => Validators.validarCadastro(
      nome: nome,
      email: email,
      telefone: telefone,
      senha: senha,
    );

    test('retorna null quando todos os campos são válidos', () {
      expect(validar(), isNull);
    });

    test('retorna a mensagem de campos vazios', () {
      expect(validar(nome: ''), 'Preencha todos os campos');
      expect(validar(email: ''), 'Preencha todos os campos');
      expect(validar(telefone: ''), 'Preencha todos os campos');
      expect(validar(senha: ''), 'Preencha todos os campos');
    });

    test('retorna a mensagem de nome inválido', () {
      expect(validar(nome: 'Jo'), 'Nome deve ter pelo menos 3 caracteres');
    });

    test('retorna a mensagem de e-mail inválido', () {
      expect(validar(email: 'email-invalido'), 'E-mail inválido');
    });

    test('retorna a mensagem de telefone inválido', () {
      expect(validar(telefone: '1234'), 'Telefone inválido');
    });

    test('retorna a mensagem de senha inválida', () {
      expect(validar(senha: '12345'), 'Senha deve ter no mínimo 6 caracteres');
    });
  });

  group('Validators.validarBarbeiro', () {
    String? validar({
      String nome = 'Carlos Eduardo',
      String especialidade = 'Especialista em barba',
      String telefone = '(67) 99101-1001',
      String email = 'carlos@sysbarber.com',
      String senha = 'barbeiro123',
      double salario = 2800,
      bool senhaObrigatoria = true,
    }) => Validators.validarBarbeiro(
      nome: nome,
      especialidade: especialidade,
      telefone: telefone,
      email: email,
      senha: senha,
      salario: salario,
      senhaObrigatoria: senhaObrigatoria,
    );

    test('retorna null quando o cadastro está completo', () {
      expect(validar(), isNull);
    });

    test('cobra especialidade e salário', () {
      expect(
        validar(especialidade: 'x'),
        'Especialidade deve ter pelo menos 3 caracteres',
      );
      expect(validar(salario: 0), 'Salário deve ser maior que zero');
    });

    test('na edição a senha em branco é aceita', () {
      expect(validar(senha: '', senhaObrigatoria: false), isNull);
      expect(
        validar(senha: '', senhaObrigatoria: true),
        'Senha deve ter no mínimo 6 caracteres',
      );
    });
  });

  group('Validators de cartão', () {
    test('aceita números que passam no algoritmo de Luhn', () {
      expect(Validators.cartaoValido('4111 1111 1111 1111'), isTrue);
      expect(Validators.cartaoValido('5500 0000 0000 0004'), isTrue);
    });

    test('rejeita números inválidos ou curtos', () {
      expect(Validators.cartaoValido('4111 1111 1111 1112'), isFalse);
      expect(Validators.cartaoValido('1234'), isFalse);
      expect(Validators.cartaoValido(''), isFalse);
    });

    test('valida a data de validade contra a referência informada', () {
      final agora = DateTime(2026, 8, 12);
      expect(
        Validators.validadeCartaoValida('12/26', agora: agora),
        isTrue,
      );
      expect(Validators.validadeCartaoValida('08/26', agora: agora), isTrue);
      expect(Validators.validadeCartaoValida('07/26', agora: agora), isFalse);
      expect(Validators.validadeCartaoValida('13/30', agora: agora), isFalse);
    });

    test('validarCartao devolve a primeira mensagem aplicável', () {
      final agora = DateTime(2026, 8, 12);
      expect(
        Validators.validarCartao(
          numero: '4111 1111 1111 1111',
          nome: 'JOAO SILVA',
          validade: '12/30',
          cvv: '123',
          agora: agora,
        ),
        isNull,
      );
      expect(
        Validators.validarCartao(
          numero: '1111',
          nome: 'JOAO SILVA',
          validade: '12/30',
          cvv: '123',
          agora: agora,
        ),
        'Número de cartão inválido',
      );
      expect(
        Validators.validarCartao(
          numero: '4111 1111 1111 1111',
          nome: 'JOAO SILVA',
          validade: '12/30',
          cvv: '1',
          agora: agora,
        ),
        'CVV inválido',
      );
    });
  });
}
