import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Configuração inicial da barbearia (`/configuracao`, regra de negócio 15).
///
/// Aparece na primeira abertura, quando ainda não existe administrador: o
/// dono cria a própria conta de administrador e escolhe se começa com os
/// dados de exemplo. Depois disso a rota não abre mais.
class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({super.key});

  @override
  State<ConfiguracaoScreen> createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmacaoCtrl = TextEditingController();
  bool _ocultarSenha = true;
  bool _dadosDeExemplo = false;
  bool _aceitouTermos = false;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _configurar() async {
    if (_senhaCtrl.text != _confirmacaoCtrl.text) {
      mostrarErro(context, 'A confirmação não confere com a senha');
      return;
    }

    setState(() => _salvando = true);

    final resultado = await AuthService.instance.configurarBarbearia(
      nome: _nomeCtrl.text,
      email: _emailCtrl.text,
      telefone: _telefoneCtrl.text,
      senha: _senhaCtrl.text,
      aceitouTermos: _aceitouTermos,
      dadosDeExemplo: _dadosDeExemplo,
    );

    if (!mounted) return;
    if (!resultado.sucesso) {
      setState(() => _salvando = false);
      mostrarErro(
        context,
        resultado.erro ?? 'Não foi possível configurar a barbearia',
      );
      return;
    }

    if (_dadosDeExemplo) {
      await _mostrarDadosDeExemplo();
      if (!mounted) return;
    } else {
      mostrarSucesso(
        context,
        'Barbearia configurada! Cadastre seus serviços e barbeiros na '
        'Administração.',
      );
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  /// Sem isto o dono não saberia como os barbeiros de exemplo entram.
  Future<void> _mostrarDadosDeExemplo() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Dados de exemplo criados',
          style: AppTheme.titulo(size: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foram criados 5 serviços e 3 barbeiros. Os barbeiros entram '
              'com estes e-mails e a senha '
              '${DatabaseService.senhaBarbeirosDeExemplo}:',
              style: AppTheme.texto(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (final email in DatabaseService.emailsBarbeirosDeExemplo)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '•  $email',
                  style: AppTheme.texto(size: 13, weight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Marcos Lima começa indisponível. Ao cadastrar a sua equipe, '
              'troque as senhas ou exclua esses barbeiros em Administração.',
              style: AppTheme.texto(
                size: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Entendi',
              style: AppTheme.texto(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.amarelo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Primeiro acesso'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Configurar a barbearia',
                    textAlign: TextAlign.center,
                    style: AppTheme.titulo(size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crie a conta do administrador. Com ela você cadastra '
                    'serviços e barbeiros e acompanha a agenda e os '
                    'relatórios.',
                    textAlign: TextAlign.center,
                    style: AppTheme.texto(
                      size: 13,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _campo(
                    rotulo: 'Seu nome',
                    controller: _nomeCtrl,
                    hint: 'João da Silva',
                    icone: Icons.person_outline,
                    tipo: TextInputType.name,
                  ),
                  _campo(
                    rotulo: 'E-mail de acesso',
                    controller: _emailCtrl,
                    hint: 'voce@barbearia.com',
                    icone: Icons.mail_outline,
                    tipo: TextInputType.emailAddress,
                  ),
                  _campo(
                    rotulo: 'Telefone',
                    controller: _telefoneCtrl,
                    hint: '(67) 99999-0000',
                    icone: Icons.phone_outlined,
                    tipo: TextInputType.phone,
                    formatters: [TelefoneInputFormatter()],
                  ),
                  _campo(
                    rotulo: 'Senha (mín. 6 caracteres)',
                    controller: _senhaCtrl,
                    hint: '••••••••',
                    icone: Icons.lock_outline,
                    obscuro: _ocultarSenha,
                    sufixo: IconButton(
                      tooltip: _ocultarSenha
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      icon: Icon(
                        _ocultarSenha
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _ocultarSenha = !_ocultarSenha),
                    ),
                  ),
                  _campo(
                    rotulo: 'Confirme a senha',
                    controller: _confirmacaoCtrl,
                    hint: '••••••••',
                    icone: Icons.lock_outline,
                    obscuro: _ocultarSenha,
                  ),
                  _opcaoDadosDeExemplo(),
                  const SizedBox(height: 12),
                  AceiteTermos(
                    aceito: _aceitouTermos,
                    onChanged: (v) => setState(() => _aceitouTermos = v),
                    aoLerTermos: () =>
                        Navigator.of(context).pushNamed(AuthService.rotaTermos),
                  ),
                  const SizedBox(height: 16),
                  BotaoPrincipal(
                    texto: _salvando
                        ? 'Configurando...'
                        : 'Configurar e entrar',
                    onPressed: _salvando ? null : _configurar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcaoDadosDeExemplo() {
    return Cartao(
      selected: _dadosDeExemplo,
      onTap: () => setState(() => _dadosDeExemplo = !_dadosDeExemplo),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _dadosDeExemplo,
            activeColor: AppColors.amarelo,
            checkColor: Colors.black,
            onChanged: (v) => setState(() => _dadosDeExemplo = v ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Começar com dados de exemplo',
                    style: AppTheme.texto(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.amarelo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cria 3 barbeiros (senha '
                    '${DatabaseService.senhaBarbeirosDeExemplo}) e 5 serviços, '
                    'para testar ou apresentar o app. Desmarcado, a barbearia '
                    'começa vazia e você cadastra os seus.',
                    style: AppTheme.texto(
                      size: 12,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required String rotulo,
    required TextEditingController controller,
    required String hint,
    required IconData icone,
    TextInputType tipo = TextInputType.text,
    bool obscuro = false,
    Widget? sufixo,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotuloCampo(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: obscuro,
            inputFormatters: formatters,
            autocorrect: false,
            style: AppTheme.texto(size: 14),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icone, color: AppColors.muted, size: 20),
              suffixIcon: sufixo,
            ),
          ),
        ],
      ),
    );
  }
}
