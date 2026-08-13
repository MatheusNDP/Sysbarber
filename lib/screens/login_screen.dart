import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

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

    if (resultado.sucesso) {
      // Profissional entra direto na própria agenda: a Home é a área do
      // cliente e depende de um cadastro de cliente, que ele não tem.
      final destino = AuthService.instance.ehBarbeiro
          ? '/agendamentos'
          : '/home';
      Navigator.of(context).pushNamedAndRemoveUntil(destino, (_) => false);
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
                  _dicaDemo(),
                  const SizedBox(height: 24),
                  const SectionLabel('E-mail'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: AppTheme.sans(size: 14),
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
                  const SectionLabel('Senha'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _senhaCtrl,
                    obscureText: _ocultarSenha,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _carregando ? null : _entrar(),
                    style: AppTheme.sans(size: 14),
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
                  const SizedBox(height: 32),
                  GoldButton(
                    texto: _carregando ? 'ENTRANDO...' : 'ENTRAR',
                    onPressed: _carregando ? null : _entrar,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Não tem conta? ',
                        style: AppTheme.sans(size: 13, color: AppColors.muted),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.of(context).pushNamed('/cadastro'),
                        child: Text(
                          'Criar conta',
                          style: AppTheme.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.gold,
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
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: const Text('✂️', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 16),
        Text(
          'SYSBARBER',
          style: AppTheme.serif(
            size: 26,
            color: AppColors.gold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'FAÇA SEU LOGIN',
          style: AppTheme.sans(
            size: 11,
            color: AppColors.muted,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _dicaDemo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conta administradora',
                  style: AppTheme.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DatabaseService.emailAdmin}  ·  '
                  '${DatabaseService.senhaAdmin}',
                  style: AppTheme.sans(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
