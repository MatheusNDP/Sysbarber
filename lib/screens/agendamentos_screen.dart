import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';

class AgendamentosScreen extends StatefulWidget {
  const AgendamentosScreen({super.key});

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen> {
  int _tabIndex = 0;
  List<Agendamento>? _agendamentos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final cliente = AuthService.instance.usuarioAtual;
    if (cliente == null) return;
    final lista =
        await DatabaseService.instance.listarAgendamentosCliente(cliente.id!);
    if (!mounted) return;
    setState(() => _agendamentos = lista);
  }

  Future<void> _cancelar(Agendamento a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Cancelar agendamento?',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold, fontSize: 18)),
        content: Text(
          'Tem certeza que deseja cancelar este agendamento? Esta ação não poderá ser desfeita.',
          style: GoogleFonts.dmSans(color: AppColors.text, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Voltar',
                style: GoogleFonts.dmSans(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancelar',
                style: GoogleFonts.dmSans(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService.instance
        .atualizarStatusAgendamento(a.id!, StatusAgendamento.cancelado);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final proximos = (_agendamentos ?? [])
        .where((a) =>
            a.dataHora.isAfter(agora) &&
            a.status == StatusAgendamento.confirmado)
        .toList();
    final historico = (_agendamentos ?? [])
        .where((a) =>
            a.dataHora.isBefore(agora) ||
            a.status == StatusAgendamento.cancelado ||
            a.status == StatusAgendamento.finalizado)
        .toList();
    final lista = _tabIndex == 0 ? proximos : historico;

    return Scaffold(
      appBar: const BarberAppBar(title: 'MEUS AGENDAMENTOS'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Expanded(child: _tabBtn('Próximos', 0)),
                  Expanded(child: _tabBtn('Histórico', 1)),
                ],
              ),
            ),
            Expanded(
              child: _agendamentos == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : lista.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_busy,
                                  color: AppColors.muted, size: 48),
                              const SizedBox(height: 8),
                              Text('Nenhum agendamento',
                                  style: AppTheme.subtitle(size: 13)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.gold,
                          backgroundColor: AppColors.card,
                          onRefresh: _carregar,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            itemCount: lista.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _AgendamentoCard(
                              agendamento: lista[i],
                              onCancel: () => _cancelar(lista[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final isActive = _tabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.gold : AppColors.border,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: isActive ? AppColors.gold : AppColors.muted,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendamentoCard extends StatelessWidget {
  final Agendamento agendamento;
  final VoidCallback onCancel;
  const _AgendamentoCard(
      {required this.agendamento, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String statusText;
    switch (agendamento.status) {
      case StatusAgendamento.confirmado:
        badgeColor = AppColors.green;
        statusText = 'Confirmado';
        break;
      case StatusAgendamento.cancelado:
        badgeColor = AppColors.red;
        statusText = 'Cancelado';
        break;
      case StatusAgendamento.finalizado:
        badgeColor = AppColors.gold;
        statusText = 'Finalizado';
        break;
    }
    final d = agendamento.dataHora;
    final dataStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final podeCancelar = agendamento.status == StatusAgendamento.confirmado &&
        agendamento.dataHora.isAfter(DateTime.now());

    return GoldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  agendamento.servico?.nome ?? '—',
                  style: GoogleFonts.dmSans(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GoldBadge(text: statusText, color: badgeColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.muted, size: 14),
              const SizedBox(width: 5),
              Text(agendamento.barbeiro?.nome ?? '—',
                  style: AppTheme.subtitle(size: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_month,
                  color: AppColors.muted, size: 14),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(dataStr, style: AppTheme.subtitle(size: 12))),
              Text(
                'R\$ ${(agendamento.servico?.preco ?? 0).toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (podeCancelar) ...[
            const Divider(color: Color(0x10FFFFFF), height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onCancel,
                child: Text(
                  'Cancelar agendamento',
                  style: GoogleFonts.dmSans(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
