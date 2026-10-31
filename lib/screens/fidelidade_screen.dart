import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/animacoes.dart';
import '../widgets/common_widgets.dart';

/// Programa de fidelidade (`/fidelidade`). Meta: 500 pontos = 1 serviço grátis.
class FidelidadeScreen extends StatefulWidget {
  const FidelidadeScreen({super.key});

  @override
  State<FidelidadeScreen> createState() => _FidelidadeScreenState();
}

class _FidelidadeScreenState extends State<FidelidadeScreen> {
  static const int metaPontos = DatabaseService.pontosParaPremio;

  int _pontos = 0;
  List<HistoricoPonto> _historico = [];
  bool _carregando = true;
  String? _erro;

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
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }
    try {
      final db = DatabaseService.instance;
      final pontos = await db.obterPontos(usuario!.id!);
      final historico = await db.listarHistoricoPontos(usuario.id!);
      if (!mounted) return;
      setState(() {
        _pontos = pontos;
        _historico = historico;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar seus pontos');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Fidelidade'),
      body: Column(
        children: [
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                : RefreshIndicator(
                    color: AppColors.amarelo,
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
                        const TituloSecao('Como funciona'),
                        const SizedBox(height: 12),
                        _comoFunciona(),
                        const SizedBox(height: 28),
                        const TituloSecao('Histórico de pontos'),
                        const SizedBox(height: 12),
                        if (_historico.isEmpty)
                          const EstadoVazio(
                            icone: Icons.star_outline_rounded,
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
    final premios = _pontos ~/ metaPontos;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const TituloSecao('Seus pontos'),
          const SizedBox(height: 8),
          ContagemAnimada(
            valor: _pontos,
            estilo: AppTheme.titulo(size: 52, color: AppColors.amarelo),
          ),
          Text(
            'Pontos acumulados',
            style: AppTheme.texto(size: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BarraDeProgressoAnimada(
              valor: progresso,
              altura: 10,
              corDeFundo: AppColors.card2,
              cor: AppColors.amarelo,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (faltam <= 0) ...[
                const Icon(
                  Icons.celebration_outlined,
                  size: 18,
                  color: AppColors.green,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  faltam > 0
                      ? 'Faltam $faltam pts para prêmio'
                      : premios > 1
                      ? '$premios prêmios disponíveis!'
                      : 'Prêmio disponível!',
                  style: AppTheme.texto(
                    size: 13,
                    weight: FontWeight.w600,
                    color: faltam > 0 ? AppColors.muted : AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Meta: $metaPontos pontos = 1 serviço grátis',
            style: AppTheme.texto(size: 11, color: AppColors.muted),
          ),
          if (_pontos < 0) ...[
            const SizedBox(height: 12),
            Text(
              'Saldo negativo: um serviço pago foi estornado depois que os '
              'pontos dele já tinham sido usados. Os próximos pontos '
              'quitam a diferença.',
              textAlign: TextAlign.center,
              style: AppTheme.texto(
                size: 11,
                color: AppColors.red,
                height: 1.4,
              ),
            ),
          ],
          // Sem esta indicação o cliente vê "prêmio disponível" e não
          // descobre onde usá-lo.
          if (premios > 0) ...[
            const SizedBox(height: 16),
            BotaoPrincipal(
              texto: 'Resgatar em um agendamento',
              onPressed: () => Navigator.of(context).pushNamed('/servicos'),
            ),
            const SizedBox(height: 8),
            Text(
              'O resgate é feito na etapa de pagamento do agendamento.',
              textAlign: TextAlign.center,
              style: AppTheme.texto(size: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comoFunciona() {
    const itens = [
      (Icons.savings_outlined, 'Acumule', 'Cada R\$ 1,00 pago vira 1 ponto.'),
      (
        Icons.star_outline_rounded,
        'Junte 500',
        'Ao atingir 500 pontos você ganha um prêmio.',
      ),
      (
        Icons.card_giftcard_rounded,
        'Resgate',
        'Troque seus pontos por um serviço gratuito.',
      ),
    ];

    return Column(
      children: itens
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Cartao(
                child: Row(
                  children: [
                    IconeCirculo(icone: item.$1, tamanho: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: AppTheme.texto(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            style: AppTheme.texto(
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
      child: Cartao(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconeCirculo(
              icone: ganho
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              tamanho: 40,
              cor: cor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.descricao,
                    style: AppTheme.texto(size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatarDataCurta(DateTime.parse(h.criadoEm)),
                    style: AppTheme.texto(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${ganho ? '+' : '−'}${h.pontos.abs()} pts',
              style: AppTheme.texto(
                size: 14,
                weight: FontWeight.w600,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
