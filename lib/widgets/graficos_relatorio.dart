import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'animacoes.dart';
import 'common_widgets.dart';

/// Gráficos da tela de Relatórios (a biblioteca `fl_chart`). O PDF desenha
/// os mesmos gráficos com a biblioteca `pdf` ([gerarPdfDoRelatorio]).

/// Cores dos itens da rosca e das barras horizontais, na ordem dos itens.
/// O PDF usa a mesma sequência.
const coresDosGraficos = [
  AppColors.amarelo,
  Color(0xFFE6E6E6),
  AppColors.green,
  Color(0xFF7FB7FF),
  Color(0xFFFF9F6B),
];

Color corDoItem(int i) => coresDosGraficos[i % coresDosGraficos.length];

/// Abreviação do mês, ex.: "nov".
String abreviacaoDoMes(DateTime d) => const [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ][d.month - 1];

/// Rótulo de uma barra do faturamento: o dia ("12") ou o mês ("nov/26").
String rotuloDoFaturamento(FaturamentoNoTempo f, {required bool porMes}) => porMes
    ? '${abreviacaoDoMes(f.data)}/${(f.data.year % 100).toString().padLeft(2, '0')}'
    : '${f.data.day}';

/// Com muitas barras, só algumas ganham rótulo: uma a cada [passo].
int passoDosRotulos(int barras) => barras <= 10 ? 1 : (barras / 6).ceil();

/// Card de um gráfico, com o título em cima.
class _CardDoGrafico extends StatelessWidget {
  const _CardDoGrafico({
    required this.titulo,
    required this.child,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TituloSecao(titulo),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: AppTheme.texto(size: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          Cartao(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _SemDados extends StatelessWidget {
  const _SemDados(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: AppTheme.texto(size: 12, color: AppColors.muted),
      );
}

/// Uma linha da legenda: a cor, o nome e, à direita, quantidade e valor.
class _LinhaDaLegenda extends StatelessWidget {
  const _LinhaDaLegenda({required this.cor, required this.item});

  final Color cor;
  final ItemRelatorio item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.texto(size: 13, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.quantidade}× · ${formatarReal(item.valor)}',
            style: AppTheme.texto(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
        ],
      ),
    );
  }
}

/// O faturamento líquido de cada dia (ou mês) do período, em barras.
class GraficoDoFaturamento extends StatelessWidget {
  const GraficoDoFaturamento({
    super.key,
    required this.pontos,
    required this.porMes,
  });

  final List<FaturamentoNoTempo> pontos;
  final bool porMes;

  @override
  Widget build(BuildContext context) {
    final maior = pontos.fold<double>(0, (m, p) => max(m, p.valor));
    final passo = passoDosRotulos(pontos.length);
    return _CardDoGrafico(
      titulo: 'Faturamento no tempo',
      subtitulo: porMes ? 'Por mês' : 'Por dia',
      child: maior <= 0
          ? const _SemDados('Sem faturamento no período')
          : SizedBox(
              height: 180,
              child: BarChart(
                duration: Animacoes.desligadas(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                BarChartData(
                  maxY: maior * 1.15,
                  minY: 0,
                  alignment: BarChartAlignment.spaceBetween,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maior * 1.15 / 3,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: maior * 1.15 / 3,
                        getTitlesWidget: (valor, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            valor.round().toString(),
                            style: AppTheme.texto(
                              size: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (valor, meta) {
                          final i = valor.toInt();
                          if (i % passo != 0 || i >= pontos.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              rotuloDoFaturamento(pontos[i], porMes: porMes),
                              style: AppTheme.texto(
                                size: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.card2,
                      getTooltipItem: (grupo, _, barra, __) => BarTooltipItem(
                        '${porMes ? rotuloDoFaturamento(pontos[grupo.x], porMes: true) : formatarDataCurta(pontos[grupo.x].data)}\n'
                        '${formatarReal(barra.toY)}',
                        AppTheme.texto(size: 12, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < pontos.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: max(0, pontos[i].valor),
                            color: AppColors.amarelo,
                            width: pontos.length > 20 ? 5 : 10,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// As formas de pagamento numa rosca, com a legenda embaixo.
class GraficoDasFormasDePagamento extends StatelessWidget {
  const GraficoDasFormasDePagamento({super.key, required this.itens});

  final List<ItemRelatorio> itens;

  @override
  Widget build(BuildContext context) {
    final total = itens.fold<double>(0, (t, i) => t + max(0, i.valor));
    return _CardDoGrafico(
      titulo: 'Por forma de pagamento',
      child: itens.isEmpty
          ? const _SemDados('Ainda sem dados suficientes')
          : Column(
              children: [
                if (total > 0)
                  SizedBox(
                    height: 170,
                    child: PieChart(
                      duration: Animacoes.desligadas(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      PieChartData(
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                        sections: [
                          for (var i = 0; i < itens.length; i++)
                            PieChartSectionData(
                              value: max(0, itens[i].valor),
                              color: corDoItem(i),
                              radius: 30,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < itens.length; i++)
                  _LinhaDaLegenda(cor: corDoItem(i), item: itens[i]),
              ],
            ),
    );
  }
}

/// Serviços ou barbeiros em barras horizontais, do que tem mais atendimentos
/// para o que tem menos, com a legenda embaixo.
class GraficoDeBarrasHorizontais extends StatelessWidget {
  const GraficoDeBarrasHorizontais({
    super.key,
    required this.titulo,
    required this.itens,
  });

  final String titulo;
  final List<ItemRelatorio> itens;

  @override
  Widget build(BuildContext context) {
    final maior = itens.fold<int>(0, (m, i) => max(m, i.quantidade));
    return _CardDoGrafico(
      titulo: titulo,
      child: itens.isEmpty || maior == 0
          ? const _SemDados('Ainda sem dados suficientes')
          : Column(
              children: [
                SizedBox(
                  height: 34.0 * itens.length,
                  child: BarChart(
                    duration: Animacoes.desligadas(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 400),
                    BarChartData(
                      // Girado um quarto de volta: a primeira barra fica em
                      // cima, e as barras crescem para a direita.
                      rotationQuarterTurns: 1,
                      maxY: maior.toDouble(),
                      minY: 0,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barTouchData: const BarTouchData(enabled: false),
                      barGroups: [
                        for (var i = 0; i < itens.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: itens[i].quantidade.toDouble(),
                                color: corDoItem(i),
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maior.toDouble(),
                                  color: AppColors.card2,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < itens.length; i++)
                  _LinhaDaLegenda(cor: corDoItem(i), item: itens[i]),
              ],
            ),
    );
  }
}
