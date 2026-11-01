import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Termos de uso e política de privacidade (`/termos`, regra de negócio 18).
///
/// Quem cria conta aceita estes termos; depois, eles ficam no Perfil para
/// consulta. Abre para todos, até antes da configuração inicial.
class TermosScreen extends StatelessWidget {
  const TermosScreen({super.key});

  /// Data da versão atual, mostrada no fim.
  static const String versao = '31 de outubro de 2026';

  static const List<(String, List<String>)> _secoes = [
    (
      'O que é o SysBarber',
      [
        'O SysBarber é o aplicativo da barbearia para agendar serviços, pagar '
            'e acompanhar os pontos do programa de fidelidade. Para a equipe, '
            'ele organiza a agenda e os relatórios.',
        'A barbearia é a responsável pelo atendimento, pelos preços e pelos '
            'dados das contas. O suporte do SysBarber ajuda com problemas no '
            'aplicativo.',
      ],
    ),
    (
      'Sua conta',
      [
        '•  Use dados verdadeiros e guarde a sua senha só com você.',
        '•  Cada conta é de uma pessoa, e o e-mail não se repete entre contas.',
        '•  O barbeiro entra pelo convite que a barbearia envia.',
      ],
    ),
    (
      'Agendamentos, pagamentos e pontos',
      [
        '•  Cancelar com menos de 1 hora de antecedência ou faltar tem multa '
            'de 50% do valor. Num serviço pago com pontos, os 500 pontos são '
            'perdidos. Cancelado pela barbearia, não há multa.',
        '•  Cada R\$ 1,00 pago vale 1 ponto, e 500 pontos valem um serviço '
            'gratuito.',
        '•  O Pix e o cartão desta versão são de demonstração: nenhum valor é '
            'cobrado de verdade.',
      ],
    ),
    (
      'Quais dados o app guarda',
      [
        '•  Da conta: nome, e-mail, telefone e senha. A senha é guardada de '
            'forma protegida, nunca como foi digitada.',
        '•  Do uso: agendamentos, pagamentos (forma, valor e, no cartão, só '
            'os 4 últimos dígitos) e pontos.',
        '•  Do barbeiro: também a especialidade e o salário, informados pela '
            'barbearia, e a foto de perfil, se ele puser uma. A foto aparece '
            'para os clientes na escolha do profissional, e ele pode trocá-la '
            'ou removê-la no Perfil.',
      ],
    ),
    (
      'Para que os dados são usados',
      [
        'Para fazer e acompanhar os agendamentos, registrar pagamentos e '
            'pontos, recuperar a senha e mostrar à barbearia a agenda e os '
            'relatórios. Os dados não são vendidos nem usados em propaganda.',
      ],
    ),
    (
      'Onde ficam e com quem são compartilhados',
      [
        'Nesta versão, os dados ficam no banco do próprio aparelho onde o app '
            'está instalado. Eles só saem dele quando você pede:',
        '•  o código de "Esqueci minha senha" por e-mail é enviado pelo '
            'EmailJS, que recebe o seu nome, o seu e-mail e o código. O SMS '
            'desta versão é simulado e não sai do aparelho;',
        '•  o Suporte e o convite do barbeiro abrem o WhatsApp, o e-mail ou '
            'outro app que você escolher, e você decide o que enviar.',
      ],
    ),
    (
      'Seus direitos',
      [
        'Pela Lei Geral de Proteção de Dados (Lei nº 13.709/2018), você pode:',
        '•  ver e corrigir os seus dados, no Perfil;',
        '•  excluir a sua conta, no Perfil. O nome, o e-mail, o telefone e a '
            'senha são apagados e os pontos são perdidos; os atendimentos '
            'que já aconteceram ficam só nos relatórios da barbearia, sem '
            'identificar você. Com agendamento em aberto ou valor pendente '
            'com a barbearia, é preciso resolver isso antes. A conta do '
            'barbeiro é excluída pelo administrador;',
        '•  tirar dúvidas com o suporte, pelo Perfil. O barbeiro fala com o '
            'administrador da barbearia.',
      ],
    ),
    (
      'Mudanças nestes termos',
      ['Se os termos mudarem, a versão nova aparece aqui, com a data.'],
    ),
  ];

  /// Começo dos parágrafos que são itens de uma lista.
  static const String _marcador = '•  ';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Termos e privacidade'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Termos de uso e política de privacidade',
            style: AppTheme.titulo(size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Estes termos explicam como o SysBarber funciona e o que acontece '
            'com os seus dados. Ao criar uma conta, você concorda com eles.',
            style: AppTheme.texto(
              size: 14,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          for (final (titulo, paragrafos) in _secoes) ...[
            const SizedBox(height: 24),
            TituloSecao(titulo),
            const SizedBox(height: 8),
            for (final paragrafo in paragrafos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: paragrafo.startsWith(_marcador)
                    ? ItemDeLista(paragrafo.substring(_marcador.length))
                    : Text(
                        paragrafo,
                        style: AppTheme.texto(size: 14, height: 1.5),
                      ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Versão de $versao.',
            style: AppTheme.texto(size: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
