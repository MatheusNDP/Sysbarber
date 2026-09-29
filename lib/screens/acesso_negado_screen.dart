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
      appBar: const BarberAppBar(titulo: 'ACESSO RESTRITO'),
      body: Column(
        children: [
          const GoldDivider(),
          const Expanded(
            child: EstadoVazio(
              icone: '🔒',
              titulo: 'Acesso restrito',
              descricao: 'Esta área não está disponível para a sua conta.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GoldButton(
              texto: 'VOLTAR AO INÍCIO',
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
