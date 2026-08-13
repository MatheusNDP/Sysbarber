import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Tela de cadastro (`/cadastro`). Ao concluir, o usuário já entra logado.
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    setState(() => _carregando = true);

    final resultado = await AuthService.instance.cadastrar(
      nome: _nomeCtrl.text,
      email: _emailCtrl.text,
      telefone: _telefoneCtrl.text,
      senha: _senhaCtrl.text,
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (resultado.sucesso) {
      mostrarSucesso(context, 'Conta criada com sucesso!');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      mostrarErro(context, resultado.erro ?? 'Não foi possível cadastrar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'CRIAR CONTA'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bem-vindo à barbearia',
                    textAlign: TextAlign.center,
                    style: AppTheme.serif(size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preencha seus dados para começar',
                    textAlign: TextAlign.center,
                    style: AppTheme.sans(size: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  _campo(
                    rotulo: 'Nome completo',
                    controller: _nomeCtrl,
                    hint: 'João da Silva',
                    icone: Icons.person_outline,
                    tipo: TextInputType.name,
                  ),
                  _campo(
                    rotulo: 'E-mail',
                    controller: _emailCtrl,
                    hint: 'seu@email.com',
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
                  const SizedBox(height: 16),
                  GoldButton(
                    texto: _carregando ? 'CADASTRANDO...' : 'CADASTRAR',
                    onPressed: _carregando ? null : _cadastrar,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Já tem conta? ',
                        style: AppTheme.sans(size: 13, color: AppColors.muted),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Entrar',
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
          SectionLabel(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: obscuro,
            inputFormatters: formatters,
            autocorrect: false,
            style: AppTheme.sans(size: 14),
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
