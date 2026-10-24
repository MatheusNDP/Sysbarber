import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
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

/// Recorte de tempo do relatório.
enum _Periodo { esteMes, mesPassado, tudo }

class _AdminRelatoriosScreenState extends State<AdminRelatoriosScreen> {
  RelatorioGeral? _relatorio;
  bool _carregando = true;
  String? _erro;

  /// O padrão é o mês corrente: é o único recorte em que comparar
  /// faturamento com a folha mensal faz sentido.
  _Periodo _periodo = _Periodo.esteMes;

  /// Início e fim (exclusivo) do período escolhido.
  (DateTime?, DateTime?) get _intervalo {
    final agora = DateTime.now();
    return switch (_periodo) {
      _Periodo.esteMes => (
        DateTime(agora.year, agora.month),
        DateTime(agora.year, agora.month + 1),
      ),
      _Periodo.mesPassado => (
        DateTime(agora.year, agora.month - 1),
        DateTime(agora.year, agora.month),
      ),
      _Periodo.tudo => (null, null),
    };
  }

  bool get _mensal => _periodo != _Periodo.tudo;

  void _mudarPeriodo(_Periodo p) {
    if (p == _periodo) return;
    setState(() {
      _periodo = p;
      _carregando = true;
    });
    _carregar();
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }
    try {
      final (inicio, fim) = _intervalo;
      final r = await DatabaseService.instance.gerarRelatorio(
        inicio: inicio,
        fim: fim,
      );
      if (!mounted) return;
      setState(() {
        _relatorio = r;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível gerar o relatório');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _relatorio;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Relatórios'),
      body: Column(
        children: [
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null || r == null
                ? EstadoErro(
                    mensagem: _erro ?? 'Não foi possível gerar o relatório.',
                    onTentarNovamente: _carregar,
                  )
                : RefreshIndicator(
                    color: AppColors.amarelo,
                    backgroundColor: AppColors.card,
                    onRefresh: _carregar,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Embaixo, o espaço da barra de navegação quando a tela
                      // é uma aba.
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _seletorPeriodo(),
                        const SizedBox(height: 18),
                        _destaqueFaturamento(r),
                        const SizedBox(height: 22),
                        const TituloSecao('Financeiro'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador(
                            'A receber',
                            formatarReal(r.aReceber),
                            'pendente hoje',
                          ),
                          _indicador(
                            'Ticket médio',
                            formatarReal(r.ticketMedio),
                            'por atendimento pago',
                          ),
                          _indicador(
                            'Folha salarial',
                            formatarReal(r.folhaSalarial),
                            'mensal da equipe',
                          ),
                          // Faturamento de todo o histórico menos UMA folha
                          // mensal não significa nada: o resultado só
                          // aparece quando o recorte é de um mês.
                          if (_mensal)
                            _indicador(
                              'Resultado do mês',
                              formatarReal(r.faturamento - r.folhaSalarial),
                              'faturamento − folha',
                              cor: r.faturamento - r.folhaSalarial >= 0
                                  ? AppColors.green
                                  : AppColors.red,
                            ),
                        ]),
                        const SizedBox(height: 26),
                        const TituloSecao('Agendamentos'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador(
                            'Total',
                            '${r.totalAgendamentos}',
                            'geral',
                          ),
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
                            'Concluídos',
                            '${r.finalizados}',
                            'atendimentos realizados',
                          ),
                          _indicador(
                            'Faltas',
                            '${r.faltas}',
                            'cliente não compareceu',
                            cor: AppColors.red,
                          ),
                        ]),
                        const SizedBox(height: 26),
                        const TituloSecao('Clientes e fidelidade'),
                        const SizedBox(height: 12),
                        _grade([
                          _indicador(
                            'Clientes',
                            '${r.totalClientes}',
                            r.totalClientes == 1 ? 'cadastrado' : 'cadastrados',
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
                          style: AppTheme.texto(
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
        color: AppColors.amarelo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Faturamento líquido',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatarReal(r.faturamento),
              maxLines: 1,
              style: AppTheme.titulo(size: 38, color: Colors.black),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pagamentos e multas recebidos, menos estornos',
            textAlign: TextAlign.center,
            style: AppTheme.texto(
              size: 12,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seletorPeriodo() {
    const rotulos = {
      _Periodo.esteMes: 'Este mês',
      _Periodo.mesPassado: 'Mês passado',
      _Periodo.tudo: 'Tudo',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _Periodo.values)
          ChoiceChip(
            label: Text(rotulos[p]!),
            selected: _periodo == p,
            onSelected: (_) => _mudarPeriodo(p),
            labelStyle: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: _periodo == p ? Colors.black : AppColors.text,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }

  Widget _grade(List<Widget> filhos) => GradeDuasColunas(filhos: filhos);

  Widget _indicador(
    String rotulo,
    String valor,
    String legenda, {
    Color cor = AppColors.amarelo,
  }) {
    return Cartao(
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
            style: AppTheme.texto(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: AppTheme.titulo(size: 22, color: cor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            legenda,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.texto(size: 10, color: AppColors.muted),
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
          TituloSecao(titulo),
          const SizedBox(height: 12),
          if (itens.isEmpty)
            Cartao(
              child: Text(
                'Ainda sem dados suficientes',
                style: AppTheme.texto(size: 12, color: AppColors.muted),
              ),
            )
          else
            ...itens.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Cartao(
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
                              style: AppTheme.texto(
                                size: 13,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            mostrarValor
                                ? '${item.quantidade}× · '
                                      '${formatarReal(item.valor)}'
                                : '${item.quantidade}×',
                            style: AppTheme.texto(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppColors.amarelo,
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
                          backgroundColor: AppColors.card2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.amarelo,
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
