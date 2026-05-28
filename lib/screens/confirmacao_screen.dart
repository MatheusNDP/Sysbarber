import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../models/models.dart';

class ConfirmacaoScreen extends StatefulWidget {
  const ConfirmacaoScreen({super.key});

  @override
  State<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends State<ConfirmacaoScreen> {
  bool _processando = false;

  Future<void> _confirmar() async {
    final servico = BookingFlow.servicoSelecionado;
    final barb = BookingFlow.barbeiroSelecionado;
    final data = BookingFlow.dataSelecionada;
    final hora = BookingFlow.horarioSelecionado;
    final cliente = AuthService.instance.usuarioAtual;

    if (servico == null ||
        barb == null ||
        data == null ||
        hora == null ||
        cliente == null) return;

    setState(() => _processando = true);

    final partes = hora.split(':');
    final dataHora = DateTime(
      data.year,
      data.month,
      data.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );

    final id = await DatabaseService.instance.criarAgendamento(Agendamento(
      idCliente: cliente.id!,
      idBarbeiro: barb.id!,
      idServico: servico.id!,
      dataHora: dataHora,
    ));

    BookingFlow.agendamentoCriadoId = id;
    if (!mounted) return;
    Navigator.pushNamed(context, '/pagamento');
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    final barb = BookingFlow.barbeiroSelecionado;
    final data = BookingFlow.dataSelecionada;
    final hora = BookingFlow.horarioSelecionado;

    if (servico == null || barb == null || data == null || hora == null) {
      return const Scaffold(
        body: Center(child: Text('Dados incompletos')),
      );
    }

    return Scaffold(
      appBar: const BarberAppBar(title: 'CONFIRMAR AGENDAMENTO'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withOpacity(0.15),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.4),
                              width: 2),
                        ),
                        child: const Icon(Icons.assignment_outlined,
                            color: AppColors.gold, size: 28),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Revise seu agendamento',
                        style: GoogleFonts.dmSans(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Confirme os dados antes de finalizar',
                        style: AppTheme.subtitle(size: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _resumoCard(Icons.content_cut, 'SERVIÇO', servico.nome),
                    const SizedBox(height: 8),
                    _resumoCard(Icons.person_outline, 'BARBEIRO', barb.nome),
                    const SizedBox(height: 8),
                    _resumoCard(
                      Icons.calendar_month,
                      'DATA',
                      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
                    ),
                    const SizedBox(height: 8),
                    _resumoCard(Icons.access_time, 'HORÁRIO', hora),
                    const SizedBox(height: 8),
                    _resumoCard(
                      Icons.attach_money,
                      'VALOR TOTAL',
                      'R\$ ${servico.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    const SizedBox(height: 18),
                    GoldButton(
                      label: _processando
                          ? 'PROCESSANDO...'
                          : 'CONFIRMAR AGENDAMENTO',
                      onPressed: _processando ? null : _confirmar,
                    ),
                    const SizedBox(height: 6),
                    GoldOutlineButton(
                      label: 'CANCELAR',
                      onPressed: _processando
                          ? null
                          : () {
                              BookingFlow.limpar();
                              Navigator.popUntil(
                                  context, (r) => r.settings.name == '/home');
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

  Widget _resumoCard(IconData icone, String label, String valor) {
    return GoldCard(
      child: Row(
        children: [
          Icon(icone, color: AppColors.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.goldLabel()),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
