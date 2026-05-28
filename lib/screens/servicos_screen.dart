import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/booking_flow.dart';
import '../models/models.dart';

class ServicosScreen extends StatefulWidget {
  const ServicosScreen({super.key});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> {
  List<Servico>? _servicos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DatabaseService.instance.listarServicos();
    if (!mounted) return;
    setState(() => _servicos = lista);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(title: 'SERVIÇOS'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: _servicos == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : _servicos!.isEmpty
                      ? Center(
                          child: Text('Nenhum serviço cadastrado',
                              style: AppTheme.subtitle()))
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          itemCount: _servicos!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _ServicoCard(servico: _servicos![i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicoCard extends StatelessWidget {
  final Servico servico;
  const _ServicoCard({required this.servico});

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      child: Row(
        children: [
          Text(servico.icone, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.nome,
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(servico.descricao, style: AppTheme.subtitle(size: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'R\$ ${servico.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.dmSans(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time,
                        size: 12, color: AppColors.muted),
                    const SizedBox(width: 3),
                    Text(
                      '${servico.duracaoMinutos} min',
                      style: AppTheme.subtitle(size: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              BookingFlow.servicoSelecionado = servico;
              Navigator.pushNamed(context, '/barbeiro');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Agendar',
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
