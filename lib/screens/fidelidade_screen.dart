import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';

class FidelidadeScreen extends StatefulWidget {
  const FidelidadeScreen({super.key});

  @override
  State<FidelidadeScreen> createState() => _FidelidadeScreenState();
}

class _FidelidadeScreenState extends State<FidelidadeScreen> {
  int _pontos = 0;
  List<HistoricoPonto> _historico = [];
  bool _carregando = true;
  static const _meta = 500;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final cliente = AuthService.instance.usuarioAtual;
    if (cliente == null) return;
    final pts = await DatabaseService.instance.obterPontos(cliente.id!);
    final hist =
        await DatabaseService.instance.listarHistoricoPontos(cliente.id!);
    if (!mounted) return;
    setState(() {
      _pontos = pts;
      _historico = hist;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progresso = (_pontos / _meta).clamp(0.0, 1.0);
    final faltam = (_meta - _pontos).clamp(0, _meta);

    return Scaffold(
      appBar: const BarberAppBar(title: 'FIDELIDADE'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.gold.withOpacity(0.35)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1C1422), Color(0xFF120E0A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('SEUS PONTOS',
                                    style: AppTheme.goldLabel()),
                                const SizedBox(height: 4),
                                Text(
                                  '$_pontos',
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.gold,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text('pontos acumulados',
                                    style: AppTheme.subtitle(size: 12)),
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progresso,
                                    minHeight: 6,
                                    backgroundColor: AppColors.card,
                                    valueColor: const AlwaysStoppedAnimation(
                                        AppColors.gold),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('0 pts',
                                        style: AppTheme.subtitle(size: 11)),
                                    Text(
                                      faltam > 0
                                          ? 'Faltam $faltam pts para prêmio'
                                          : '🎉 Prêmio disponível!',
                                      style: GoogleFonts.dmSans(
                                        color: AppColors.gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text('$_meta pts',
                                        style: AppTheme.subtitle(size: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Como funciona'),
                          _benefitCard('✂️', 'Ganhe pontos',
                              'A cada R\$ 1 gasto, você ganha 1 ponto'),
                          _benefitCard('🎁', 'Troque por prêmios',
                              'Cortes, barba e produtos grátis'),
                          _benefitCard('👑', 'Nível VIP',
                              '500 pts = 1 serviço gratuito'),
                          const SizedBox(height: 14),
                          const SectionLabel('Histórico de pontos'),
                          if (_historico.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'Nenhum histórico ainda. Faça seu primeiro agendamento!',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.subtitle(size: 12),
                                ),
                              ),
                            )
                          else
                            ..._historico.map((h) {
                              final positivo = h.pontos > 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Color(0x0DFFFFFF)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        h.descricao,
                                        style: GoogleFonts.dmSans(
                                          color: AppColors.text,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      positivo
                                          ? '+${h.pontos} pts'
                                          : '${h.pontos} pts',
                                      style: GoogleFonts.dmSans(
                                        color: positivo
                                            ? AppColors.green
                                            : AppColors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitCard(String icone, String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        child: Row(
          children: [
            Text(icone, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.dmSans(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(descricao, style: AppTheme.subtitle(size: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
