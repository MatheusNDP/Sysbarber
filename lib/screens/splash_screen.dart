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
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AuthService.instance.rotaInicial, (_) => false);
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
            right: -40,
            bottom: -30,
            child: Transform.rotate(
              angle: -math.pi / 8,
              child: Icon(
                Icons.content_cut_rounded,
                size: 240,
                color: AppColors.amarelo.withValues(alpha: 0.05),
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
                  const IconeCirculo(
                    icone: Icons.content_cut_rounded,
                    tamanho: 96,
                    destaque: true,
                  ),
                  const SizedBox(height: 28),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sys',
                          style: AppTheme.titulo(
                            size: 38,
                            color: AppColors.amarelo,
                          ),
                        ),
                        TextSpan(
                          text: 'Barber',
                          style: AppTheme.titulo(
                            size: 38,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A barbearia na palma da sua mão',
                    style: AppTheme.texto(size: 14, color: AppColors.muted),
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
                      texto: 'Configurar barbearia',
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(AuthService.rotaConfiguracao),
                    ),
                  ] else ...[
                    BotaoPrincipal(
                      texto: 'Entrar',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                    ),
                    const SizedBox(height: 12),
                    BotaoSecundario(
                      texto: 'Criar conta',
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
