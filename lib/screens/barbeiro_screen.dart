import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/booking_flow.dart';
import '../models/models.dart';

class BarbeiroScreen extends StatefulWidget {
  const BarbeiroScreen({super.key});

  @override
  State<BarbeiroScreen> createState() => _BarbeiroScreenState();
}

class _BarbeiroScreenState extends State<BarbeiroScreen> {
  List<Barbeiro>? _barbeiros;
  Barbeiro? _selecionado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DatabaseService.instance.listarBarbeiros();
    if (!mounted) return;
    setState(() => _barbeiros = lista);
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    return Scaffold(
      appBar: const BarberAppBar(title: 'ESCOLHA O BARBEIRO'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            if (servico != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.gold.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text('Serviço: ', style: AppTheme.subtitle(size: 12)),
                      Expanded(
                        child: Text(
                          '${servico.nome} — R\$ ${servico.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.dmSans(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _barbeiros == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: _barbeiros!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final b = _barbeiros![i];
                        final isSelected = _selecionado?.id == b.id;
                        return GoldCard(
                          selected: isSelected,
                          onTap: () => setState(() => _selecionado = b),
                          child: Row(
                            children: [
                              GoldAvatar(text: b.iniciais, size: 50),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.nome,
                                      style: GoogleFonts.dmSans(
                                        color: AppColors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(b.especialidade,
                                        style: AppTheme.subtitle(size: 12)),
                                    const SizedBox(height: 6),
                                    if (isSelected)
                                      const GoldBadge(text: 'Selecionado ✓')
                                    else
                                      Row(
                                        children: [
                                          const Icon(Icons.star,
                                              color: AppColors.gold, size: 14),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${b.avaliacao} (${b.avaliacoes})',
                                            style: AppTheme.subtitle(size: 12),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              _RadioMark(isSelected: isSelected),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GoldButton(
                label: 'CONTINUAR',
                onPressed: _selecionado == null
                    ? null
                    : () {
                        BookingFlow.barbeiroSelecionado = _selecionado;
                        Navigator.pushNamed(context, '/horario');
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  final bool isSelected;
  const _RadioMark({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.gold : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.gold.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.black)
          : null,
    );
  }
}
