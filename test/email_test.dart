import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/email.dart';

/// Testes do envio do código por e-mail: a chamada à API do EmailJS (contra
/// um servidor local, sem internet) e o e-mail simulado.
void main() {
  late HttpServer servidor;
  Map<String, dynamic>? recebido;
  var resposta = (status: 200, corpo: 'OK');

  setUp(() async {
    recebido = null;
    resposta = (status: 200, corpo: 'OK');
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((pedido) async {
      recebido =
          jsonDecode(await utf8.decoder.bind(pedido).join())
              as Map<String, dynamic>;
      pedido.response
        ..statusCode = resposta.status
        ..write(resposta.corpo);
      await pedido.response.close();
    });
  });

  tearDown(() => servidor.close(force: true));

  EmailJs emailJs({Uri? endereco}) => EmailJs(
    servico: 'service_teste',
    modelo: 'template_teste',
    chavePublica: 'chave-publica',
    endereco: endereco ?? Uri.parse('http://127.0.0.1:${servidor.port}/send'),
  );

  Future<void> enviar(EmailJs envio) => envio.enviarCodigo(
    email: 'novo@teste.com',
    nome: 'Novo Cliente',
    codigo: '123456',
    minutos: 10,
  );

  test('envia ao EmailJS o serviço, o modelo, a chave pública e os dados do '
      'e-mail', () async {
    await enviar(emailJs());

    expect(recebido!['service_id'], 'service_teste');
    expect(recebido!['template_id'], 'template_teste');
    expect(recebido!['user_id'], 'chave-publica');
    expect(recebido!['template_params'], {
      'to_email': 'novo@teste.com',
      'to_name': 'Novo Cliente',
      'codigo': '123456',
      'minutos': '10',
    });
    // Nenhuma chave privada sai do app.
    expect(recebido!.containsKey('accessToken'), isFalse);
  });

  test('recusa do EmailJS vira falha no envio', () async {
    resposta = (status: 400, corpo: 'The Public Key is invalid');

    await expectLater(
      enviar(emailJs()),
      throwsA(
        isA<FalhaNoEnvioDeEmail>().having(
          (e) => e.detalhe,
          'detalhe',
          contains('400'),
        ),
      ),
    );
  });

  test('sem conexão também vira falha no envio', () async {
    final porta = servidor.port;
    await servidor.close(force: true);

    await expectLater(
      enviar(emailJs(endereco: Uri.parse('http://127.0.0.1:$porta/send'))),
      throwsA(isA<FalhaNoEnvioDeEmail>()),
    );
  });

  test('o e-mail simulado guarda a mensagem com o código e a validade', () async {
    await EmailSimulado.instance.enviarCodigo(
      email: 'novo@teste.com',
      nome: 'Novo Cliente',
      codigo: '654321',
      minutos: 10,
    );

    final email = EmailSimulado.instance.ultimo.value!;
    expect(email.email, 'novo@teste.com');
    expect(email.assunto, assuntoDoEmail);
    expect(email.texto, contains('Novo Cliente'));
    expect(email.texto, contains('654321'));
    expect(email.texto, contains('10 minutos'));
  });

  test('sem a chave do EmailJS no build, o app usa o e-mail simulado', () {
    expect(ConfiguracaoEmailJs.configurado, isFalse);
    expect(envioEmailPadrao(), same(EmailSimulado.instance));
  });
}
