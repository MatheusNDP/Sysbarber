import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Programa de fidelidade (`/fidelidade`). Meta: 500 pontos = 1 serviço grátis.
class FidelidadeScreen extends StatefulWidget {
  const FidelidadeScreen({super.key});

  @override
  State<FidelidadeScreen> createState() => _FidelidadeScreenState();
}

class _FidelidadeScreenState extends State<FidelidadeScreen> {
  static const int metaPontos = 500;

  int _pontos = 0;
  List<HistoricoPonto> _historico = [];
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
    final pontos = await db.obterPontos(usuario!.id!);
    final historico = await db.listarHistoricoPontos(usuario.id!);
    if (!mounted) return;
    setState(() {
      _pontos = pontos;
      _historico = historico;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'FIDELIDADE'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.card,
                    onRefresh: _carregar,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      children: [
                        _cartaoPontos(),
                        const SizedBox(height: 28),
                        const SectionLabel('Como funciona'),
                        const SizedBox(height: 12),
                        _comoFunciona(),
                        const SizedBox(height: 28),
                        const SectionLabel('Histórico de pontos'),
                        const SizedBox(height: 12),
                        if (_historico.isEmpty)
                          const EstadoVazio(
                            icone: '⭐',
                            titulo: 'Nenhum ponto ainda',
                            descricao:
                                'Finalize um pagamento para começar a '
                                'acumular pontos.',
                          )
                        else
                          ..._historico.map(_itemHistorico),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoPontos() {
    final progresso = (_pontos / metaPontos).clamp(0.0, 1.0);
    final faltam = metaPontos - _pontos;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.card2, AppColors.dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        children: [
          const SectionLabel('Seus pontos'),
          const SizedBox(height: 10),
          Text(
            '$_pontos',
            style: AppTheme.serif(size: 52, color: AppColors.gold),
          ),
          Text(
            'PONTOS ACUMULADOS',
            style: AppTheme.sans(
              size: 10,
              color: AppColors.muted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 10,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            faltam > 0
                ? 'Faltam $faltam pts para prêmio'
                : '🎉 Prêmio disponível!',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w700,
              color: faltam > 0 ? AppColors.muted : AppColors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Meta: $metaPontos pontos = 1 serviço grátis',
            style: AppTheme.sans(size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _comoFunciona() {
    const itens = [
      ('💰', 'Acumule', 'Cada R\$ 1,00 pago vira 1 ponto.'),
      ('⭐', 'Junte 500', 'Ao atingir 500 pontos você ganha um prêmio.'),
      ('🎁', 'Resgate', 'Troque seus pontos por um serviço gratuito.'),
    ];

    return Column(
      children: itens
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GoldCard(
                child: Row(
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: AppTheme.sans(
                              size: 14,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            style: AppTheme.sans(
                              size: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _itemHistorico(HistoricoPonto h) {
    final ganho = h.pontos >= 0;
    final cor = ganho ? AppColors.green : AppColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.descricao,
                    style: AppTheme.sans(size: 13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatarDataCurta(DateTime.parse(h.criadoEm)),
                    style: AppTheme.sans(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${ganho ? '+' : '−'}${h.pontos.abs()} pts',
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w700,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
