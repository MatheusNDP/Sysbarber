import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _showPassword = false;
  bool _carregando = false;

  Future<void> _login() async {
    setState(() => _carregando = true);
    final r = await AuthService.instance
        .login(_emailController.text, _senhaController.text);
    if (!mounted) return;
    setState(() => _carregando = false);

    if (r.sucesso) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } else {
      _mostrarErro(r.erro ?? 'Erro desconhecido');
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, Color(0xFF7A5920)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Text('✂️', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSBARBER',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'FAÇA SEU LOGIN',
                        style: GoogleFonts.dmSans(
                          color: AppColors.muted,
                          fontSize: 10,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const GoldDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dica para a banca
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Conta demo: demo@sysbarber.com / demo1234',
                              style: GoogleFonts.dmSans(
                                color: AppColors.gold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionLabel('E-mail'),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.text),
                      decoration:
                          const InputDecoration(hintText: 'exemplo@email.com'),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Senha'),
                    TextField(
                      controller: _senhaController,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.muted,
                          ),
                          onPressed: () => setState(
                              () => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GoldButton(
                      label: _carregando ? 'ENTRANDO...' : 'ENTRAR',
                      onPressed: _carregando ? null : _login,
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Wrap(
                        children: [
                          Text('Não tem conta? ',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.muted, fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                                context, '/cadastro'),
                            child: Text('Criar conta',
                                style: GoogleFonts.dmSans(
                                    color: AppColors.gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
