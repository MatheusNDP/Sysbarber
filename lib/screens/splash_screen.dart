import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Tela inicial (`/`). Se houver sessão salva, entra direto na Home.
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
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioAtual;

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
                  color: AppColors.gold.withValues(alpha: 0.04),
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
                          style: AppTheme.serif(
                            size: 40,
                            color: AppColors.gold,
                            letterSpacing: 4,
                          ),
                        ),
                        TextSpan(
                          text: 'BARBER',
                          style: AppTheme.serif(
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
                    style: AppTheme.sans(
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
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Entrando como ${usuario?.nome ?? ''}...',
                          style: AppTheme.sans(
                            size: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    GoldButton(
                      texto: 'ENTRAR',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                    ),
                    const SizedBox(height: 12),
                    GoldOutlineButton(
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
