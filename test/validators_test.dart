import 'dart:typed_data';

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
    test('aceita fixo (10 dígitos) e celular (11), com ou sem máscara', () {
      expect(Validators.telefoneValido('(67) 3333-4444'), isTrue);
      expect(Validators.telefoneValido('(67) 99999-0000'), isTrue);
      expect(Validators.telefoneValido('67999990000'), isTrue);
    });

    test('rejeita telefones incompletos ou longos demais', () {
      expect(Validators.telefoneValido(''), isFalse);
      expect(Validators.telefoneValido('9999'), isFalse);
      // Antes passava: 8 caracteres contando a máscara, mas só 5 dígitos.
      expect(Validators.telefoneValido('(67) 999'), isFalse);
      // Sem DDD não é um telefone completo.
      expect(Validators.telefoneValido('99999999'), isFalse);
      expect(Validators.telefoneValido('679999900001'), isFalse);
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

  group('Validators.validarDadosBarbeiro', () {
    String? validar({
      String nome = 'Carlos Eduardo',
      String especialidade = 'Especialista em barba',
      double salario = 2800,
    }) => Validators.validarDadosBarbeiro(
      nome: nome,
      especialidade: especialidade,
      salario: salario,
    );

    test('retorna null quando os dados estão completos', () {
      expect(validar(), isNull);
    });

    test('cobra nome, especialidade e salário', () {
      expect(validar(nome: 'Jo'), 'Nome deve ter pelo menos 3 caracteres');
      expect(
        validar(especialidade: 'x'),
        'Especialidade deve ter pelo menos 3 caracteres',
      );
      expect(validar(salario: 0), 'Salário deve ser maior que zero');
    });
  });

  group('Validators.validarContatoBarbeiro', () {
    test('retorna null com e-mail e telefone válidos', () {
      expect(
        Validators.validarContatoBarbeiro(
          email: 'carlos@sysbarber.com',
          telefone: '(67) 99101-1001',
        ),
        isNull,
      );
    });

    test('recusa e-mail ou telefone inválido', () {
      expect(
        Validators.validarContatoBarbeiro(
          email: 'carlos',
          telefone: '(67) 99101-1001',
        ),
        'E-mail inválido',
      );
      expect(
        Validators.validarContatoBarbeiro(
          email: 'carlos@sysbarber.com',
          telefone: '(67) 999',
        ),
        'Telefone inválido',
      );
    });
  });

  group('Validators.validarFoto (regra de negócio 22)', () {
    /// Arquivo de [tamanho] bytes que começa com [cabecalho].
    Uint8List arquivo(List<int> cabecalho, [int tamanho = 64]) =>
        Uint8List(tamanho)..setAll(0, cabecalho);

    const jpeg = [0xFF, 0xD8, 0xFF, 0xE0];
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    final webp = [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits];
    const naoEFoto = 'Escolha uma foto em JPG, PNG ou WebP';

    test('aceita JPG, PNG e WebP', () {
      expect(Validators.validarFoto(arquivo(jpeg)), isNull);
      expect(Validators.validarFoto(arquivo(png)), isNull);
      expect(Validators.validarFoto(arquivo(webp)), isNull);
    });

    test('recusa o que não é foto, como um texto, um GIF ou um áudio', () {
      expect(
        Validators.validarFoto(Uint8List.fromList('não é foto'.codeUnits)),
        naoEFoto,
      );
      expect(Validators.validarFoto(Uint8List(0)), naoEFoto);
      expect(Validators.validarFoto(arquivo('GIF89a'.codeUnits)), naoEFoto);
      // Um WAVE também começa com "RIFF".
      final wave = [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits];
      expect(Validators.validarFoto(arquivo(wave)), naoEFoto);
    });

    test('recusa a foto acima de 1 MB', () {
      const limite = Validators.tamanhoMaximoFoto;
      expect(Validators.validarFoto(arquivo(jpeg, limite)), isNull);
      expect(
        Validators.validarFoto(arquivo(jpeg, limite + 1)),
        'A foto passa de 1 MB. Escolha outra',
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
