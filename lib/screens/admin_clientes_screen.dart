import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Listagem de clientes com busca (`/admin` → Gerenciar Clientes).
class AdminClientesScreen extends StatefulWidget {
  const AdminClientesScreen({super.key});

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen> {
  final _db = DatabaseService.instance;
  final _buscaCtrl = TextEditingController();

  List<Cliente> _clientes = [];
  String _busca = '';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _db.listarClientes();
      if (!mounted) return;
      setState(() {
        _clientes = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao carregar clientes: $e');
    }
  }

  List<Cliente> get _filtrados {
    if (_busca.trim().isEmpty) return _clientes;
    final termo = _busca.toLowerCase();
    return _clientes
        .where(
          (c) =>
              c.nome.toLowerCase().contains(termo) ||
              c.email.toLowerCase().contains(termo) ||
              c.telefone.contains(termo),
        )
        .toList();
  }

  Future<void> _abrirDetalhe(Cliente c) async {
    if (c.id == null) return;
    try {
      final agendamentos = await _db.listarAgendamentosCliente(c.id!);
      final pontos = await _db.obterPontos(c.id!);
      if (!mounted) return;

      final ativos = agendamentos
          .where((a) => a.status == StatusAgendamento.confirmado)
          .length;
      final cancelados = agendamentos
          .where((a) => a.status == StatusAgendamento.cancelado)
          .length;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              GoldAvatar(texto: c.iniciais, tamanho: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.nome, style: AppTheme.serif(size: 17)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detalhe('E-mail', c.email),
              _detalhe('Telefone', c.telefone),
              _detalhe('Cliente desde', _dataCadastro(c.criadoEm)),
              const Divider(color: AppColors.border, height: 24),
              _detalhe('Agendamentos', '${agendamentos.length}'),
              _detalhe('Confirmados', '$ativos'),
              _detalhe('Cancelados', '$cancelados'),
              _detalhe('Pontos de fidelidade', '$pontos pts'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'FECHAR',
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, 'Erro ao abrir o cliente: $e');
    }
  }

  String _dataCadastro(String iso) {
    try {
      return formatarDataCurta(DateTime.parse(iso));
    } catch (_) {
      return '—';
    }
  }

  Widget _detalhe(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: AppTheme.sans(size: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: AppTheme.sans(size: 13, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'CLIENTES'),
      body: Column(
        children: [
          const GoldDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _buscaCtrl,
              onChanged: (v) => setState(() => _busca = v),
              style: AppTheme.sans(size: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, e-mail ou telefone',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.muted,
                  size: 20,
                ),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.muted,
                          size: 18,
                        ),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _busca = '');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('${lista.length} cliente(s)'),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : lista.isEmpty
                ? EstadoVazio(
                    icone: '👥',
                    titulo: _busca.isEmpty
                        ? 'Nenhum cliente'
                        : 'Nada encontrado',
                    descricao: _busca.isEmpty
                        ? 'Os clientes cadastrados no app aparecem aqui.'
                        : 'Tente outro termo de busca.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = lista[i];
                      return GoldCard(
                        onTap: () => _abrirDetalhe(c),
                        child: Row(
                          children: [
                            GoldAvatar(texto: c.iniciais, tamanho: 42),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.gold,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
