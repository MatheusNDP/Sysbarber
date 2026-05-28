import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Se já está logado, vai direto pra home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.instance.estaLogado) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: 80,
              child: Transform.rotate(
                angle: -0.5,
                child: const Text(
                  '✂',
                  style: TextStyle(
                    fontSize: 200,
                    color: Color(0x14C9A84C),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✂️', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'SYS',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.gold,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                            ),
                          ),
                          TextSpan(
                            text: 'BARBER',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.text,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SISTEMA DE BARBEARIA',
                      style: GoogleFonts.dmSans(
                        color: AppColors.muted,
                        fontSize: 11,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.gold,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    if (AuthService.instance.estaLogado) ...[
                      const CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Entrando como ${AuthService.instance.usuarioAtual!.nome}...',
                        style: GoogleFonts.dmSans(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ] else ...[
                      GoldButton(
                        label: 'ENTRAR',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                      ),
                      const SizedBox(height: 10),
                      GoldOutlineButton(
                        label: 'CRIAR CONTA',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/cadastro'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bem-vindo ao seu espaço de estilo',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF555555),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
