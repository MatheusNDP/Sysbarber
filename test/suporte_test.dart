import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/suporte.dart';
import 'package:sysbarber/services/validators.dart';

/// Testes do Suporte do Perfil: o contato, a mensagem pronta e os links do
/// WhatsApp e do e-mail.
void main() {
  test('o contato do suporte tem o formato que os links exigem', () {
    // O wa.me só aceita dígitos, com o código do país (55) e o DDD.
    expect(ContatoSuporte.whatsapp, matches(RegExp(r'^55\d{10,11}$')));
    expect(Validators.emailValido(ContatoSuporte.email), isTrue);
  });

  test('a mensagem pronta diz o nome e se é cliente ou administrador', () {
    expect(
      mensagemAoSuporte(nome: 'Lucas Martins', administrador: false),
      'Olá! Sou Lucas Martins (cliente) e preciso de ajuda com o SysBarber.',
    );
    expect(
      mensagemAoSuporte(nome: 'Matheus Nunes', administrador: true),
      'Olá! Sou Matheus Nunes (administrador) e preciso de ajuda com o '
      'SysBarber.',
    );
  });

  test('o WhatsApp abre a conversa com o suporte, já com a mensagem', () {
    final link = linkDoWhatsApp('Olá! Sou Lucas (cliente) & cia');

    expect(link.scheme, 'https');
    expect(link.host, 'wa.me');
    expect(link.path, '/${ContatoSuporte.whatsapp}');
    expect(link.queryParameters['text'], 'Olá! Sou Lucas (cliente) & cia');
  });

  test('o e-mail vai para o suporte com o assunto e a mensagem, sem "+" no '
      'lugar dos espaços', () {
    final link = linkDoEmail('Olá! Sou Lucas (cliente)');

    expect(link.scheme, 'mailto');
    expect(link.path, ContatoSuporte.email);
    expect(link.queryParameters['subject'], 'Suporte SysBarber');
    expect(link.queryParameters['body'], 'Olá! Sou Lucas (cliente)');
    // Os apps de e-mail mostram o "+" no texto em vez de um espaço.
    expect(link.query, isNot(contains('+')));
  });

  test('sem app para abrir o link, devolve false em vez de lançar', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Nos testes não há o lado Android do url_launcher, como num aparelho
    // sem app que abra o link.
    expect(await abrirForaDoApp(linkDoEmail('Olá')), isFalse);
  });
}
