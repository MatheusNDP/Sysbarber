import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'admin_barbeiros_screen.dart';
import 'admin_clientes_screen.dart';
import 'admin_relatorios_screen.dart';
import 'admin_servicos_screen.dart';
import 'agendamentos_screen.dart';

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
  String? _erro;

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
      final resumo = await _db.resumoDoDia();
      if (!mounted) return;
      setState(() {
        _resumo = resumo;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar o painel');
      });
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => tela));
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Administração'),
      body: Column(
        children: [
          Expanded(
            // Antes uma falha deixava o carregamento girando para sempre.
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null || resumo == null
                ? EstadoErro(
                    mensagem: _erro ?? 'Não foi possível carregar o painel.',
                    onTentarNovamente: _carregar,
                  )
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
                        const RotuloCampo('Modo administrador'),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Painel de Controle',
                                style: AppTheme.titulo(size: 22),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _seloHoje(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Movimento de ${formatarDataExtenso(DateTime.now())}',
                          style: AppTheme.texto(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Linhas com a altura do conteúdo: a proporção fixa
                        // do GridView estourava com a fonte do sistema maior.
                        GradeDuasColunas(
                          filhos: [
                            _estatistica(
                              Icons.event_note_outlined,
                              resumo.agendamentosHoje,
                              'Agendamentos',
                              resumo.agendamentosTotal,
                              'no total',
                            ),
                            _estatistica(
                              Icons.content_cut_rounded,
                              resumo.barbeirosHoje,
                              'Barbeiros',
                              resumo.barbeirosTotal,
                              'na equipe',
                            ),
                            _estatistica(
                              Icons.people_outline_rounded,
                              resumo.clientesHoje,
                              'Clientes',
                              resumo.clientesTotal,
                              resumo.clientesTotal == 1
                                  ? 'cadastrado'
                                  : 'cadastrados',
                            ),
                            _estatistica(
                              Icons.design_services_outlined,
                              resumo.servicosHoje,
                              'Serviços',
                              resumo.servicosTotal,
                              'no catálogo',
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const TituloSecao('Gerenciamento'),
                        const SizedBox(height: 12),
                        _itemGerenciar(
                          Icons.calendar_month_outlined,
                          'Agenda geral',
                          'Todos os atendimentos: receber, concluir e faltas',
                          () => _abrir(
                            const AgendamentosScreen(agendaGeral: true),
                          ),
                        ),
                        _itemGerenciar(
                          Icons.design_services_outlined,
                          'Gerenciar Serviços',
                          'Cadastrar, editar e excluir serviços',
                          () => _abrir(const AdminServicosScreen()),
                        ),
                        _itemGerenciar(
                          Icons.content_cut_rounded,
                          'Gerenciar Barbeiros',
                          'Equipe, acesso e salários',
                          () => _abrir(const AdminBarbeirosScreen()),
                        ),
                        _itemGerenciar(
                          Icons.people_outline_rounded,
                          'Gerenciar Clientes',
                          'Cadastros, agendamentos e pontos',
                          () => _abrir(const AdminClientesScreen()),
                        ),
                        _itemGerenciar(
                          Icons.bar_chart_rounded,
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
      decoration: const ShapeDecoration(
        color: AppColors.amarelo,
        shape: StadiumBorder(),
      ),
      child: Text(
        'Hoje',
        style: AppTheme.texto(
          size: 12,
          weight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  /// Card com o número do dia em destaque e o total geral como referência.
  Widget _estatistica(
    IconData icone,
    int hoje,
    String rotulo,
    int total,
    String legendaTotal,
  ) {
    return Cartao(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconeCirculo(icone: icone, tamanho: 36, cor: AppColors.amarelo),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$hoje',
              maxLines: 1,
              style: AppTheme.titulo(size: 25, color: AppColors.amarelo),
            ),
          ),
          Text(
            rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.texto(size: 12, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '$total $legendaTotal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.texto(size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _itemGerenciar(
    IconData icone,
    String titulo,
    String descricao,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Cartao(
        onTap: onTap,
        child: Row(
          children: [
            IconeCirculo(icone: icone, tamanho: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTheme.texto(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descricao,
                    style: AppTheme.texto(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
