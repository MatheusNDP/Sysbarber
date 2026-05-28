import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _showPassword = false;
  bool _carregando = false;

  Future<void> _cadastrar() async {
    setState(() => _carregando = true);
    final r = await AuthService.instance.cadastrar(
      nome: _nomeController.text,
      email: _emailController.text,
      telefone: _telController.text,
      senha: _senhaController.text,
    );
    if (!mounted) return;
    setState(() => _carregando = false);

    if (r.sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Cadastro realizado com sucesso!',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      });
    } else {
      _mostrarErro(r.erro ?? 'Erro ao cadastrar');
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
      appBar: const BarberAppBar(title: 'CRIAR CONTA'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text('👤', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Preencha seus dados para continuar',
                        style: AppTheme.subtitle(size: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('Nome completo'),
                    TextField(
                      controller: _nomeController,
                      style: const TextStyle(color: AppColors.text),
                      decoration:
                          const InputDecoration(hintText: 'João da Silva'),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('E-mail'),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.text),
                      decoration:
                          const InputDecoration(hintText: 'joao@email.com'),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Telefone'),
                    TextField(
                      controller: _telController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                          hintText: '(67) 99999-9999'),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Senha (mín. 6 caracteres)'),
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
                    const SizedBox(height: 20),
                    GoldButton(
                      label: _carregando ? 'CADASTRANDO...' : 'CADASTRAR',
                      onPressed: _carregando ? null : _cadastrar,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        children: [
                          Text('Já tem conta? ',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.muted, fontSize: 13)),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, '/login'),
                            child: Text('Fazer login',
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
