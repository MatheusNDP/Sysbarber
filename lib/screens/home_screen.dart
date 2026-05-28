import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Agendamento? _proximo;
  int _pontos = 0;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) => _carregarDados());
  }

  Future<void> _carregarDados() async {
    final cliente = AuthService.instance.usuarioAtual;
    if (cliente == null) {
      // Não deveria estar aqui sem login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      });
      return;
    }
    final agora = DateTime.now();
    final ags =
        await DatabaseService.instance.listarAgendamentosCliente(cliente.id!);
    final futuros = ags
        .where((a) =>
            a.dataHora.isAfter(agora) &&
            a.status == StatusAgendamento.confirmado)
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    final pontos = await DatabaseService.instance.obterPontos(cliente.id!);
    if (!mounted) return;
    setState(() {
      _proximo = futuros.isNotEmpty ? futuros.first : null;
      _pontos = pontos;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cliente = AuthService.instance.usuarioAtual;
    if (cliente == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: _carregarDados,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, bem-vindo 👋',
                            style: GoogleFonts.dmSans(
                                color: AppColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cliente.nome,
                            style: GoogleFonts.dmSans(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/perfil')
                          .then((_) => _carregarDados()),
                      child:
                          const GoldAvatar(text: '✂', size: 56, large: true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.gold),
                        ),
                      )
                    else ...[
                      if (_proximo != null) _ProximoCard(agendamento: _proximo!),
                      if (_proximo != null) const SizedBox(height: 12),
                      // Pontos badge
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.25)),
                          color: AppColors.card,
                        ),
                        child: Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SEUS PONTOS',
                                      style: AppTheme.goldLabel()),
                                  Text(
                                    '$_pontos pts acumulados',
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.gold.withOpacity(0.6)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SectionLabel('Acesso rápido'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _AcessoRapido(
                          icone: '💈',
                          titulo: 'Ver Serviços',
                          onTap: () => Navigator.pushNamed(
                                  context, '/servicos')
                              .then((_) => _carregarDados()),
                        ),
                        _AcessoRapido(
                          icone: '📋',
                          titulo: 'Meus Agendamentos',
                          onTap: () => Navigator.pushNamed(
                                  context, '/agendamentos')
                              .then((_) => _carregarDados()),
                        ),
                        _AcessoRapido(
                          icone: '⭐',
                          titulo: 'Fidelidade',
                          onTap: () => Navigator.pushNamed(
                                  context, '/fidelidade')
                              .then((_) => _carregarDados()),
                        ),
                        _AcessoRapido(
                          icone: '⚙️',
                          titulo: 'Administração',
                          onTap: () =>
                              Navigator.pushNamed(context, '/admin'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(active: 0),
    );
  }
}

class _ProximoCard extends StatelessWidget {
  final Agendamento agendamento;
  const _ProximoCard({required this.agendamento});

  @override
  Widget build(BuildContext context) {
    String data;
    try {
      data = DateFormat("EEEE, dd/MM 'às' HH:mm", 'pt_BR')
          .format(agendamento.dataHora);
    } catch (_) {
      data =
          '${agendamento.dataHora.day}/${agendamento.dataHora.month} às ${agendamento.dataHora.hour}:${agendamento.dataHora.minute.toString().padLeft(2, '0')}';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        gradient: const LinearGradient(
          colors: [AppColors.card, AppColors.card2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRÓXIMO HORÁRIO', style: AppTheme.goldLabel()),
                const SizedBox(height: 6),
                Text(
                  agendamento.servico?.nome ?? 'Serviço',
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$data · ${agendamento.barbeiro?.nome ?? ""}',
                  style: AppTheme.subtitle(size: 12),
                ),
              ],
            ),
          ),
          const Text('📅', style: TextStyle(fontSize: 34)),
        ],
      ),
    );
  }
}

class _AcessoRapido extends StatelessWidget {
  final String icone;
  final String titulo;
  final VoidCallback onTap;
  const _AcessoRapido(
      {required this.icone, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icone, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int active;
  const _BottomBar({required this.active});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Início', 'route': '/home'},
      {'icon': Icons.content_cut, 'label': 'Serviços', 'route': '/servicos'},
      {
        'icon': Icons.calendar_month_outlined,
        'label': 'Agenda',
        'route': '/agendamentos'
      },
      {'icon': Icons.person_outline, 'label': 'Perfil', 'route': '/perfil'},
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final isActive = i == active;
          return GestureDetector(
            onTap: () {
              if (i == active) return;
              Navigator.pushReplacementNamed(
                  context, items[i]['route'] as String);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(items[i]['icon'] as IconData,
                    size: 22,
                    color: isActive ? AppColors.gold : AppColors.muted),
                const SizedBox(height: 4),
                Text(
                  items[i]['label'] as String,
                  style: GoogleFonts.dmSans(
                    color: isActive ? AppColors.gold : AppColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
