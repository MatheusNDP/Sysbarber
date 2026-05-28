import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/booking_flow.dart';

class HorarioScreen extends StatefulWidget {
  const HorarioScreen({super.key});

  @override
  State<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen> {
  late List<DateTime> _datas;
  DateTime? _dataSelecionada;
  String? _horarioSelecionado;
  List<String> _horariosDisponiveis = [];
  bool _carregando = false;

  static const _diasSemana = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _datas = List.generate(7, (i) => hoje.add(Duration(days: i)));
    _dataSelecionada = _datas[1];
    _carregarHorarios();
  }

  Future<void> _carregarHorarios() async {
    final barb = BookingFlow.barbeiroSelecionado;
    final data = _dataSelecionada;
    if (barb == null || data == null) return;
    setState(() => _carregando = true);
    final disponiveis =
        await DatabaseService.instance.horariosDisponiveis(barb.id!, data);
    if (!mounted) return;
    setState(() {
      _horariosDisponiveis = disponiveis;
      _horarioSelecionado = null;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final barb = BookingFlow.barbeiroSelecionado;
    return Scaffold(
      appBar: const BarberAppBar(title: 'ESCOLHA O HORÁRIO'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Selecione a data'),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _datas.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final d = _datas[i];
                          final isSelected = _dataSelecionada != null &&
                              _dataSelecionada!.day == d.day &&
                              _dataSelecionada!.month == d.month;
                          final dia = _diasSemana[(d.weekday - 1) % 7];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _dataSelecionada = d);
                              _carregarHorarios();
                            },
                            child: Container(
                              width: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold.withOpacity(0.2)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.border,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dia,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    d.day.toString().padLeft(2, '0'),
                                    style: GoogleFonts.dmSans(
                                      color: isSelected
                                          ? AppColors.gold
                                          : AppColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionLabel('Horários disponíveis'),
                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold),
                        ),
                      )
                    else if (_horariosDisponiveis.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            'Nenhum horário disponível nesta data',
                            style: AppTheme.subtitle(size: 13),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _horariosDisponiveis.map((h) {
                          final isSel = _horarioSelecionado == h;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _horarioSelecionado = h),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.gold.withOpacity(0.2)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.gold
                                      : AppColors.gold.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                h,
                                style: GoogleFonts.dmSans(
                                  color:
                                      isSel ? AppColors.gold : AppColors.text,
                                  fontSize: 13,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 18),
                    if (barb != null && _horarioSelecionado != null)
                      GoldCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Barbeiro',
                                      style: AppTheme.subtitle(size: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    barb.nome,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Horário escolhido',
                                    style: AppTheme.subtitle(size: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')} · $_horarioSelecionado',
                                  style: GoogleFonts.dmSans(
                                    color: AppColors.gold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    GoldButton(
                      label: 'CONFIRMAR',
                      onPressed: _horarioSelecionado == null
                          ? null
                          : () {
                              BookingFlow.dataSelecionada = _dataSelecionada;
                              BookingFlow.horarioSelecionado =
                                  _horarioSelecionado;
                              Navigator.pushNamed(context, '/confirmacao');
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
