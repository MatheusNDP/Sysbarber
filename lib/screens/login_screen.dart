import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'recuperar_senha_screen.dart';

/// Tela de login (`/login`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _carregando = true);

    final resultado = await AuthService.instance.login(
      _emailCtrl.text,
      _senhaCtrl.text,
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (resultado.criarNovaSenha) {
      // Entrou com o código provisório que a barbearia liberou: antes de
      // qualquer coisa, cria uma senha nova (regra de negócio 16).
      final email = _emailCtrl.text;
      final codigo = _senhaCtrl.text;
      _senhaCtrl.clear();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RecuperarSenhaScreen(email: email, codigoDaBarbearia: codigo),
        ),
      );
      return;
    }

    if (resultado.sucesso) {
      // Profissional entra direto na própria agenda: a Home é a área do
      // cliente e depende de um cadastro de cliente, que ele não tem.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AuthService.instance.rotaInicial,
        (_) => false,
      );
    } else {
      mostrarErro(context, resultado.erro ?? 'Não foi possível entrar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'ENTRAR'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabecalho(),
                  const SizedBox(height: 28),
                  const TituloSecao('E-mail'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: AppTheme.texto(size: 14),
                    decoration: const InputDecoration(
                      hintText: 'seu@email.com',
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        color: AppColors.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const TituloSecao('Senha'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _senhaCtrl,
                    obscureText: _ocultarSenha,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _carregando ? null : _entrar(),
                    style: AppTheme.texto(size: 14),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
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
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AuthService.rotaRecuperarSenha),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        'Esqueci minha senha',
                        style: AppTheme.texto(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.amarelo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BotaoPrincipal(
                    texto: _carregando ? 'ENTRANDO...' : 'ENTRAR',
                    onPressed: _carregando ? null : _entrar,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Não tem conta? ',
                        style: AppTheme.texto(size: 13, color: AppColors.muted),
                      ),
                      // Botão de verdade (foco, leitor de tela e área de toque),
                      // e não um texto com GestureDetector.
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/cadastro'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(
                          'Criar conta',
                          style: AppTheme.texto(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.amarelo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amarelo, width: 1.5),
          ),
          child: const Text('✂️', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 16),
        Text(
          'SYSBARBER',
          style: AppTheme.titulo(
            size: 26,
            color: AppColors.amarelo,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'FAÇA SEU LOGIN',
          style: AppTheme.texto(
            size: 11,
            color: AppColors.muted,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
