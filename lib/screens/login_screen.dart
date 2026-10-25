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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AuthService.instance.rotaInicial, (_) => false);
    } else {
      mostrarErro(context, resultado.erro ?? 'Não foi possível entrar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Entrar'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabecalho(),
                  const SizedBox(height: 28),
                  const RotuloCampo('E-mail'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: AppTheme.texto(size: 14),
                    decoration: const InputDecoration(
                      hintText: 'seu@email.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const RotuloCampo('Senha'),
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
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
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
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(AuthService.rotaRecuperarSenha),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        'Esqueci minha senha',
                        style: AppTheme.texto(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.amarelo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BotaoPrincipal(
                    texto: _carregando ? 'Entrando...' : 'Entrar',
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
                            weight: FontWeight.w600,
                            color: AppColors.amarelo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // O barbeiro não se cadastra: entra pelo convite que o
                  // administrador enviou (regra de negócio 10).
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(AuthService.rotaConvite),
                      icon: const Icon(Icons.content_cut_rounded, size: 18),
                      label: Text(
                        'Tenho um convite de barbeiro',
                        style: AppTheme.texto(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        minimumSize: const Size(48, 48),
                      ),
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

  Widget _cabecalho() {
    return Column(
      children: [
        const IconeCirculo(
          icone: Icons.content_cut_rounded,
          tamanho: 72,
          destaque: true,
        ),
        const SizedBox(height: 18),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Sys',
                style: AppTheme.titulo(size: 28, color: AppColors.amarelo),
              ),
              TextSpan(text: 'Barber', style: AppTheme.titulo(size: 28)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Faça seu login',
          style: AppTheme.texto(size: 14, color: AppColors.muted),
        ),
      ],
    );
  }
}
