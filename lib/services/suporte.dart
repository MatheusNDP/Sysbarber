import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

/// Contato do suporte do SysBarber, chamado pela seção "Suporte" do Perfil.
///
/// O suporte é de quem mantém o app, não da barbearia: o contato é fixo e o
/// mesmo em qualquer instalação. O app não envia nada por conta própria: os
/// botões só abrem o WhatsApp ou o app de e-mail do aparelho, com a mensagem
/// já escrita, e a pessoa decide se envia.
class ContatoSuporte {
  ContatoSuporte._();

  /// WhatsApp, só com dígitos: código do país (55), DDD e número.
  ///
  /// Provisório: o DDD 00 não existe, então o link não leva a ninguém.
  static const String whatsapp = '5500000000000';

  /// Provisório: o domínio `.example` é reservado e não recebe e-mail.
  static const String email = 'suporte@sysbarber.example';

  /// Assunto do e-mail ao suporte.
  static const String assunto = 'Suporte SysBarber';
}

/// Mensagem que já vem escrita no WhatsApp e no e-mail.
String mensagemAoSuporte({required String nome, required bool administrador}) =>
    'Olá! Sou $nome (${administrador ? 'administrador' : 'cliente'}) e '
    'preciso de ajuda com o SysBarber.';

/// Conversa com o suporte no WhatsApp, já com a [mensagem].
///
/// O `wa.me` abre o WhatsApp quando ele está instalado e, sem ele, a página
/// do WhatsApp no navegador.
Uri linkDoWhatsApp(String mensagem) => Uri.parse(
  'https://wa.me/${ContatoSuporte.whatsapp}'
  '?text=${Uri.encodeComponent(mensagem)}',
);

/// E-mail ao suporte, já com o assunto e a [mensagem].
///
/// Monta a query com `encodeComponent` porque `queryParameters` troca os
/// espaços por `+`, e os apps de e-mail mostram o `+` no texto.
Uri linkDoEmail(String mensagem) => Uri.parse(
  'mailto:${ContatoSuporte.email}'
  '?subject=${Uri.encodeComponent(ContatoSuporte.assunto)}'
  '&body=${Uri.encodeComponent(mensagem)}',
);

/// Abre um link fora do app. Devolve `false` quando ele não abriu.
typedef AbrirLink = Future<bool> Function(Uri link);

/// Abre [link] no app do aparelho que cuida dele (WhatsApp, navegador ou
/// e-mail). Devolve `false` quando nenhum app o abre.
Future<bool> abrirForaDoApp(Uri link) async {
  try {
    return await launchUrl(link, mode: LaunchMode.externalApplication);
  } catch (erro) {
    // Sem o link no log: ele leva o nome de quem está pedindo ajuda.
    developer.log(
      'Falha ao abrir o link (${link.scheme})',
      name: 'sysbarber',
      error: erro,
    );
    return false;
  }
}
