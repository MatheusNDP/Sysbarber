import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Relatórios gerenciais (`/admin` → Relatórios).
///
/// Todos os números são calculados por SQL sobre as tabelas reais — nada é
/// fixo no código.
class AdminRelatoriosScreen extends StatefulWidget {
  const AdminRelatoriosScreen({super.key});

  @override
  State<AdminRelatoriosScreen> createState() => _AdminRelatoriosScreenState();
}

class _AdminRelatoriosScreenState extends State<AdminRelatoriosScreen> {
  RelatorioGeral? _relatorio;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final r = await DatabaseService.instance.gerarRelatorio();
      if (!mounted) return;
      setState(() {
        _relatorio = r;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao gerar relatório: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _relatorio;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'RELATÓRIOS'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : r == null
                ? const EstadoVazio(
                    icone: '📊',
                    titulo: 'Sem dados',
                    descricao: 'Não foi possível gerar o relatório.',
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
                        _destaqueFaturamento(r),
                        const SizedBox(height: 22),
                        const SectionLabel('Financeiro'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador(
                            'A receber',
                            formatarReal(r.aReceber),
                            'pagamentos pendentes',
                          ),
                          _indicador(
                            'Ticket médio',
                            formatarReal(r.ticketMedio),
                            'por pagamento',
                          ),
                          _indicador(
                            'Folha salarial',
                            formatarReal(r.folhaSalarial),
                            'mensal da equipe',
                          ),
                          _indicador(
                            'Resultado',
                            formatarReal(r.faturamento - r.folhaSalarial),
                            'faturamento − folha',
                            cor: r.faturamento - r.folhaSalarial >= 0
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ]),
                        const SizedBox(height: 26),
                        const SectionLabel('Agendamentos'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador('Total', '${r.totalAgendamentos}', 'geral'),
                          _indicador(
                            'Confirmados',
                            '${r.confirmados}',
                            'em aberto',
                            cor: AppColors.green,
                          ),
                          _indicador(
                            'Cancelados',
                            '${r.cancelados}',
                            '${r.taxaCancelamento.toStringAsFixed(1)}% do total',
                            cor: AppColors.red,
                          ),
                          _indicador(
                            'Finalizados',
                            '${r.finalizados}',
                            'concluídos',
                          ),
                        ]),
                        const SizedBox(height: 26),
                        const SectionLabel('Clientes e fidelidade'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador(
                            'Clientes',
                            '${r.totalClientes}',
                            'cadastrados',
                          ),
                          _indicador(
                            'Pontos ativos',
                            '${r.pontosEmCirculacao}',
                            'em circulação',
                          ),
                        ]),
                        const SizedBox(height: 26),
                        _ranking(
                          'Por forma de pagamento',
                          r.porMetodo,
                          mostrarValor: true,
                        ),
                        _ranking('Serviços mais procurados', r.porServico),
                        _ranking('Barbeiros mais requisitados', r.porBarbeiro),
                        const SizedBox(height: 10),
                        Text(
                          'Gerado em ${formatarDataHora(DateTime.now())}',
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(
                            size: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _destaqueFaturamento(RelatorioGeral r) {
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
          const SectionLabel('Faturamento confirmado'),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatarReal(r.faturamento),
              maxLines: 1,
              style: AppTheme.serif(size: 40, color: AppColors.gold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Somente pagamentos efetivados',
            style: AppTheme.sans(size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _grade(List<Widget> filhos) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: filhos,
    );
  }

  Widget _indicador(
    String rotulo,
    String valor,
    String legenda, {
    Color cor = AppColors.gold,
  }) {
    return GoldCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: AppTheme.serif(size: 22, color: cor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            legenda,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _ranking(
    String titulo,
    List<ItemRelatorio> itens, {
    bool mostrarValor = false,
  }) {
    final maior = itens.isEmpty
        ? 1
        : itens.map((i) => i.quantidade).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(titulo),
          const SizedBox(height: 12),
          if (itens.isEmpty)
            GoldCard(
              child: Text(
                'Ainda sem dados suficientes',
                style: AppTheme.sans(size: 12, color: AppColors.muted),
              ),
            )
          else
            ...itens.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GoldCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.rotulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            mostrarValor
                                ? '${item.quantidade}× · '
                                      '${formatarReal(item.valor)}'
                                : '${item.quantidade}×',
                            style: AppTheme.sans(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maior == 0 ? 0 : item.quantidade / maior,
                          minHeight: 6,
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
