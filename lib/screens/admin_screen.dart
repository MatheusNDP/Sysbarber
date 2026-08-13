import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'admin_barbeiros_screen.dart';
import 'admin_clientes_screen.dart';
import 'admin_relatorios_screen.dart';
import 'admin_servicos_screen.dart';

/// Painel administrativo (`/admin`) com estatísticas vindas do banco.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _db = DatabaseService.instance;

  ResumoDia? _resumo;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final resumo = await _db.resumoDoDia();
      if (!mounted) return;
      setState(() {
        _resumo = resumo;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao carregar estatísticas: $e');
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => tela));
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'ADMINISTRAÇÃO'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando || resumo == null
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
                        const SectionLabel('Modo administrador'),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Painel de Controle',
                                style: AppTheme.serif(size: 24),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _seloHoje(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Movimento de ${formatarDataExtenso(DateTime.now())}',
                          style: AppTheme.sans(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          // 1.5 estourava por ~4px com a fonte serifada.
                          childAspectRatio: 1.25,
                          children: [
                            _estatistica(
                              '📋',
                              resumo.agendamentosHoje,
                              'Agendamentos',
                              resumo.agendamentosTotal,
                              'no total',
                            ),
                            _estatistica(
                              '✂️',
                              resumo.barbeirosHoje,
                              'Barbeiros',
                              resumo.barbeirosTotal,
                              'na equipe',
                            ),
                            _estatistica(
                              '👥',
                              resumo.clientesHoje,
                              'Clientes',
                              resumo.clientesTotal,
                              'cadastrados',
                            ),
                            _estatistica(
                              '💈',
                              resumo.servicosHoje,
                              'Serviços',
                              resumo.servicosTotal,
                              'no catálogo',
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const SectionLabel('Gerenciamento'),
                        const SizedBox(height: 12),
                        _itemGerenciar(
                          '💈',
                          'Gerenciar Serviços',
                          'Cadastrar, editar e excluir serviços',
                          () => _abrir(const AdminServicosScreen()),
                        ),
                        _itemGerenciar(
                          '✂️',
                          'Gerenciar Barbeiros',
                          'Equipe, acesso e salários',
                          () => _abrir(const AdminBarbeirosScreen()),
                        ),
                        _itemGerenciar(
                          '👥',
                          'Gerenciar Clientes',
                          'Cadastros, agendamentos e pontos',
                          () => _abrir(const AdminClientesScreen()),
                        ),
                        _itemGerenciar(
                          '📊',
                          'Relatórios',
                          'Faturamento e indicadores',
                          () => _abrir(const AdminRelatoriosScreen()),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Pílula "HOJE" ao lado do título do painel.
  Widget _seloHoje() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold),
      ),
      child: Text(
        'HOJE',
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w700,
          color: AppColors.gold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Card com o número do dia em destaque e o total geral como referência.
  Widget _estatistica(
    String icone,
    int hoje,
    String rotulo,
    int total,
    String legendaTotal,
  ) {
    return GoldCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icone, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$hoje',
              maxLines: 1,
              style: AppTheme.serif(size: 25, color: AppColors.gold),
            ),
          ),
          Text(
            rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 11, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '$total $legendaTotal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _itemGerenciar(
    String icone,
    String titulo,
    String descricao,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        onTap: onTap,
        child: Row(
          children: [
            Text(icone, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descricao,
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
