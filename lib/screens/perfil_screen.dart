import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Perfil do usuário logado (`/perfil`).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int _totalAgendamentos = 0;
  int _pontos = 0;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final usuario = AuthService.instance.usuarioAtual;
    if (usuario?.id == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    final db = DatabaseService.instance;
    final agendamentos = await db.listarAgendamentosCliente(usuario!.id!);
    final pontos = await db.obterPontos(usuario.id!);
    if (!mounted) return;
    setState(() {
      _totalAgendamentos = agendamentos.length;
      _pontos = pontos;
      _carregando = false;
    });
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Sair da conta?', style: AppTheme.serif(size: 18)),
        content: Text(
          'Você precisará entrar novamente para acessar seus agendamentos.',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'CANCELAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'SAIR',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioAtual;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'PERFIL'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    children: [
                      Center(
                        child: GoldAvatar(
                          texto: usuario?.iniciais ?? '?',
                          tamanho: 92,
                          large: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        usuario?.nome ?? 'Visitante',
                        textAlign: TextAlign.center,
                        style: AppTheme.serif(size: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.email ?? '',
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(size: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 32),
                      _item(
                        Icons.phone_outlined,
                        'Telefone',
                        usuario?.telefone ?? '-',
                      ),
                      _item(
                        Icons.calendar_today_outlined,
                        'Meus agendamentos',
                        '$_totalAgendamentos no total',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/agendamentos'),
                      ),
                      _item(
                        Icons.star_outline,
                        'Pontos de fidelidade',
                        '$_pontos pts',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/fidelidade'),
                      ),
                      if (AuthService.instance.podeAdministrar)
                        _item(
                          Icons.settings_outlined,
                          'Área administrativa',
                          'Painel de controle',
                          onTap: () =>
                              Navigator.of(context).pushNamed('/admin'),
                        ),
                      const SizedBox(height: 28),
                      GoldOutlineButton(texto: 'SAIR', onPressed: _sair),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    IconData icone,
    String rotulo,
    String valor, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icone, color: AppColors.gold, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    valor,
                    style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
