import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Tela inicial (`/`). Se houver sessão salva, entra direto na Home. Na
/// primeira abertura, sem administrador, leva à configuração da barbearia.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _restaurandoSessao = false;

  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    if (!AuthService.instance.estaLogado) return;
    setState(() => _restaurandoSessao = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    // O barbeiro volta direto para a própria agenda.
    Navigator.of(context).pushNamedAndRemoveUntil(
      AuthService.instance.rotaInicial,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final nome = auth.nomeLogado;

    return Scaffold(
      body: Stack(
        children: [
          // Tesoura decorativa translúcida no canto inferior direito.
          Positioned(
            right: -30,
            bottom: -20,
            child: Transform.rotate(
              angle: -math.pi / 8,
              child: Text(
                '✂️',
                style: TextStyle(
                  fontSize: 180,
                  color: AppColors.amarelo.withValues(alpha: 0.04),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  const Text('✂️', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 28),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'SYS',
                          style: AppTheme.titulo(
                            size: 40,
                            color: AppColors.amarelo,
                            letterSpacing: 4,
                          ),
                        ),
                        TextSpan(
                          text: 'BARBER',
                          style: AppTheme.titulo(
                            size: 40,
                            color: AppColors.text,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const GoldDivider(largura: 120),
                  const SizedBox(height: 18),
                  Text(
                    'SISTEMA DE BARBEARIA',
                    style: AppTheme.texto(
                      size: 11,
                      color: AppColors.muted,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_restaurandoSessao)
                    Column(
                      children: [
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.amarelo,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Entrando como ${nome ?? ''}...',
                          style: AppTheme.texto(
                            size: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    )
                  else if (!auth.barbeariaConfigurada) ...[
                    Text(
                      'Primeiro acesso: crie a conta de administrador da '
                      'barbearia para começar.',
                      textAlign: TextAlign.center,
                      style: AppTheme.texto(
                        size: 13,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BotaoPrincipal(
                      texto: 'CONFIGURAR BARBEARIA',
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AuthService.rotaConfiguracao),
                    ),
                  ] else ...[
                    BotaoPrincipal(
                      texto: 'ENTRAR',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                    ),
                    const SizedBox(height: 12),
                    BotaoSecundario(
                      texto: 'CRIAR CONTA',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/cadastro'),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
