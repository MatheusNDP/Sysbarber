import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int _pontos = 0;
  int _totalAgendamentos = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final c = AuthService.instance.usuarioAtual;
    if (c == null) return;
    final p = await DatabaseService.instance.obterPontos(c.id!);
    final ags =
        await DatabaseService.instance.listarAgendamentosCliente(c.id!);
    if (!mounted) return;
    setState(() {
      _pontos = p;
      _totalAgendamentos = ags.length;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Sair?',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold, fontSize: 18)),
        content: Text('Deseja realmente sair da conta?',
            style: GoogleFonts.dmSans(color: AppColors.text, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: GoogleFonts.dmSans(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sair',
                  style: GoogleFonts.dmSans(
                      color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AuthService.instance.usuarioAtual;
    if (c == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    return Scaffold(
      appBar: const BarberAppBar(title: 'MEU PERFIL'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            const SizedBox(height: 20),
            const GoldAvatar(text: '✂', size: 90, large: true),
            const SizedBox(height: 12),
            Text(
              c.nome,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(c.email, style: AppTheme.subtitle(size: 13)),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _item(Icons.phone_outlined, 'Telefone', c.telefone),
                  const SizedBox(height: 8),
                  _item(Icons.calendar_month, 'Meus agendamentos',
                      '$_totalAgendamentos no total',
                      onTap: () =>
                          Navigator.pushNamed(context, '/agendamentos')
                              .then((_) => _carregar())),
                  const SizedBox(height: 8),
                  _item(Icons.star_outline, 'Pontos de fidelidade',
                      '$_pontos pts',
                      onTap: () =>
                          Navigator.pushNamed(context, '/fidelidade')
                              .then((_) => _carregar())),
                  const SizedBox(height: 8),
                  _item(Icons.settings_outlined, 'Área administrativa',
                      'Painel de controle',
                      onTap: () => Navigator.pushNamed(context, '/admin')),
                  const SizedBox(height: 18),
                  GoldOutlineButton(label: 'SAIR', onPressed: _logout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String titulo, String descricao,
      {VoidCallback? onTap}) {
    return GoldCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.dmSans(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(descricao, style: AppTheme.subtitle(size: 12)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right,
                color: AppColors.gold.withOpacity(0.6), size: 22),
        ],
      ),
    );
  }
}
