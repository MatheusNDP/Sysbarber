import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Envio do código de "Esqueci minha senha" por e-mail (regra de negócio 16).
///
/// O e-mail sai de verdade pelo [EmailJs], serviço feito para enviar e-mail
/// sem servidor próprio: o app guarda só a chave pública, e o texto fica num
/// modelo cadastrado na conta do EmailJS. A chave não vai para o Git; ela
/// entra no build ([ConfiguracaoEmailJs]). Sem ela, o app usa o
/// [EmailSimulado], como no SMS.
abstract interface class EnvioEmail {
  /// Envia o [codigo] para [email], cumprimentando [nome]. O código vale por
  /// [minutos] minutos.
  Future<void> enviarCodigo({
    required String email,
    required String nome,
    required String codigo,
    required int minutos,
  });
}

/// Assunto do e-mail, o mesmo do modelo cadastrado no EmailJS (ver README).
const String assuntoDoEmail = 'SysBarber: código para criar uma nova senha';

/// Texto do e-mail, o mesmo do modelo cadastrado no EmailJS (ver README).
String textoDoEmail({
  required String nome,
  required String codigo,
  required int minutos,
}) =>
    'Olá, $nome!\n\n'
    'Seu código para criar uma nova senha no SysBarber é $codigo. Ele vale '
    'por $minutos minutos e só pode ser usado uma vez.\n\n'
    'Se você não pediu uma nova senha, ignore este e-mail: a sua senha '
    'continua a mesma.';

/// Identificadores do EmailJS, passados no build:
/// `flutter run --dart-define-from-file=emailjs.json` (o arquivo fica fora do
/// Git; o modelo está em `emailjs.exemplo.json`).
class ConfiguracaoEmailJs {
  ConfiguracaoEmailJs._();

  static const String servico = String.fromEnvironment('EMAILJS_SERVICE_ID');
  static const String modelo = String.fromEnvironment('EMAILJS_TEMPLATE_ID');
  static const String chavePublica = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
  );

  static bool get configurado =>
      servico.isNotEmpty && modelo.isNotEmpty && chavePublica.isNotEmpty;
}

/// O envio que o app usa: o EmailJS, quando configurado no build, ou o
/// e-mail simulado.
EnvioEmail envioEmailPadrao() => ConfiguracaoEmailJs.configurado
    ? EmailJs(
        servico: ConfiguracaoEmailJs.servico,
        modelo: ConfiguracaoEmailJs.modelo,
        chavePublica: ConfiguracaoEmailJs.chavePublica,
      )
    : EmailSimulado.instance;

/// O e-mail não saiu: sem internet, tempo esgotado ou recusa do EmailJS.
class FalhaNoEnvioDeEmail implements Exception {
  final String detalhe;

  const FalhaNoEnvioDeEmail(this.detalhe);

  @override
  String toString() => 'FalhaNoEnvioDeEmail: $detalhe';
}

/// Envio de verdade pela API REST do EmailJS.
///
/// Usa o `HttpClient` do próprio Dart, sem pacote novo. A única requisição
/// de rede do app é esta.
class EmailJs implements EnvioEmail {
  EmailJs({
    required this.servico,
    required this.modelo,
    required this.chavePublica,
    Uri? endereco,
    this.limite = const Duration(seconds: 15),
  }) : endereco =
           endereco ?? Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

  final String servico;
  final String modelo;
  final String chavePublica;

  /// Endpoint de envio; os testes apontam para um servidor local.
  final Uri endereco;

  /// Tempo máximo de espera pela resposta.
  final Duration limite;

  @override
  Future<void> enviarCodigo({
    required String email,
    required String nome,
    required String codigo,
    required int minutos,
  }) async {
    final cliente = HttpClient()..connectionTimeout = limite;
    try {
      final pedido = await cliente.postUrl(endereco).timeout(limite);
      pedido.headers.contentType = ContentType.json;
      pedido.write(
        jsonEncode({
          'service_id': servico,
          'template_id': modelo,
          'user_id': chavePublica,
          'template_params': {
            'to_email': email,
            'to_name': nome,
            'codigo': codigo,
            'minutos': '$minutos',
          },
        }),
      );
      final resposta = await pedido.close().timeout(limite);
      final corpo = await resposta
          .transform(utf8.decoder)
          .join()
          .timeout(limite);
      if (resposta.statusCode != 200) {
        throw FalhaNoEnvioDeEmail(
          'EmailJS respondeu ${resposta.statusCode}: $corpo',
        );
      }
    } on SocketException catch (e) {
      throw FalhaNoEnvioDeEmail('sem conexão: ${e.message}');
    } on TimeoutException {
      throw const FalhaNoEnvioDeEmail('tempo esgotado');
    } on HttpException catch (e) {
      throw FalhaNoEnvioDeEmail(e.message);
    } finally {
      cliente.close(force: true);
    }
  }
}

/// E-mail que o [EmailSimulado] "enviou".
typedef EmailEnviado = ({String email, String assunto, String texto});

/// Envio simulado: a mensagem fica em [ultimo], e a tela de recuperação a
/// mostra como "e-mail simulado". É o que vale nos testes e nos builds sem o
/// EmailJS configurado.
class EmailSimulado implements EnvioEmail {
  EmailSimulado._interno();

  static final EmailSimulado instance = EmailSimulado._interno();

  /// Último e-mail enviado (`null` antes do primeiro envio).
  final ValueNotifier<EmailEnviado?> ultimo = ValueNotifier(null);

  @override
  Future<void> enviarCodigo({
    required String email,
    required String nome,
    required String codigo,
    required int minutos,
  }) async {
    ultimo.value = (
      email: email,
      assunto: assuntoDoEmail,
      texto: textoDoEmail(nome: nome, codigo: codigo, minutos: minutos),
    );
  }
}
