import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/erros.dart';

/// A mensagem mostrada ao usuário nunca pode ser o texto cru da exceção.
void main() {
  test('regra de negócio chega ao usuário como foi escrita', () {
    expect(
      mensagemDeErro(
        const RegraNegocioException('O horário 09:00 não está mais livre'),
        'Não foi possível agendar',
      ),
      'O horário 09:00 não está mais livre',
    );
  });

  test('falha técnica vira mensagem genérica, sem detalhes internos', () {
    final msg = mensagemDeErro(
      Exception(
        'DatabaseException(UNIQUE constraint failed: '
        'agendamento.id_barbeiro)',
      ),
      'Não foi possível agendar',
    );
    expect(msg, 'Não foi possível agendar. Tente novamente.');
    expect(msg, isNot(contains('UNIQUE')));
    expect(msg, isNot(contains('agendamento.')));
  });

  test('qualquer outra exceção também não vaza', () {
    final msg = mensagemDeErro(StateError('Bad state: x'), 'Erro ao salvar');
    expect(msg, 'Erro ao salvar. Tente novamente.');
  });
}
