import 'package:flutter/foundation.dart';

/// Envio de SMS, usado pela recuperação de senha (regra de negócio 16).
///
/// O app não tem servidor nem acesso à internet, e a chave de um provedor de
/// SMS guardada no APK poderia ser extraída por qualquer um. Por isso o envio
/// é simulado, como o Pix e o cartão ([SmsSimulado]). Um provedor real entra
/// implementando esta interface, chamado por um servidor que guarde a chave.
abstract interface class EnvioSms {
  Future<void> enviar({required String telefone, required String mensagem});
}

/// Mensagem que o [SmsSimulado] "enviou".
typedef SmsEnviado = ({String telefone, String mensagem});

/// Envio simulado: em vez de sair para a operadora, a mensagem fica em
/// [ultima], e a tela de recuperação de senha a mostra como "SMS simulado".
class SmsSimulado implements EnvioSms {
  SmsSimulado._interno();

  static final SmsSimulado instance = SmsSimulado._interno();

  /// Última mensagem enviada (`null` antes do primeiro envio).
  final ValueNotifier<SmsEnviado?> ultima = ValueNotifier(null);

  @override
  Future<void> enviar({
    required String telefone,
    required String mensagem,
  }) async {
    ultima.value = (telefone: telefone, mensagem: mensagem);
  }
}
