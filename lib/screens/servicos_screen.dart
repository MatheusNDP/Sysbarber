import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Catálogo de serviços (`/servicos`). Todos os dados vêm do banco.
class ServicosScreen extends StatefulWidget {
  const ServicosScreen({super.key});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> {
  List<Servico> _servicos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final servicos = await DatabaseService.instance.listarServicos();
    if (!mounted) return;
    setState(() {
      _servicos = servicos;
      _carregando = false;
    });
  }

  void _agendar(Servico servico) {
    BookingFlow.servicoSelecionado = servico;
    Navigator.of(context).pushNamed('/barbeiro');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'SERVIÇOS'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _servicos.isEmpty
                ? const EstadoVazio(
                    icone: '💈',
                    titulo: 'Nenhum serviço cadastrado',
                    descricao:
                        'Cadastre serviços na área administrativa para '
                        'que apareçam aqui.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: _servicos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _cardServico(_servicos[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cardServico(Servico s) {
    return GoldCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.icone, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.nome, style: AppTheme.serif(size: 17)),
                const SizedBox(height: 4),
                Text(
                  s.descricao,
                  style: AppTheme.sans(size: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      formatarReal(s.preco),
                      style: AppTheme.serif(size: 18, color: AppColors.gold),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.duracaoMinutos} min',
                      style: AppTheme.sans(size: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GoldButton(
            texto: 'Agendar',
            expandido: false,
            onPressed: () => _agendar(s),
          ),
        ],
      ),
    );
  }
}
