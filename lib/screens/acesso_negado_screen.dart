import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';

/// Mostrada no lugar de uma tela que o perfil logado não pode abrir.
class AcessoNegadoScreen extends StatelessWidget {
  const AcessoNegadoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Acesso restrito'),
      body: Column(
        children: [
          const Expanded(
            child: EstadoVazio(
              icone: Icons.lock_outline_rounded,
              titulo: 'Acesso restrito',
              descricao: 'Esta área não está disponível para a sua conta.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: BotaoPrincipal(
              texto: 'Voltar ao início',
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                auth.estaLogado ? auth.rotaInicial : '/',
                (_) => false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
