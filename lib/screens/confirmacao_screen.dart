import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Revisão final antes de gravar o agendamento (`/confirmacao`).
class ConfirmacaoScreen extends StatefulWidget {
  const ConfirmacaoScreen({super.key});

  @override
  State<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends State<ConfirmacaoScreen> {
  bool _salvando = false;

  Future<void> _confirmar() async {
    final usuario = AuthService.instance.usuarioAtual;
    final servico = BookingFlow.servicoSelecionado;
    final barbeiro = BookingFlow.barbeiroSelecionado;
    final dataHora = BookingFlow.dataHoraCompleta;

    if (usuario?.id == null ||
        servico?.id == null ||
        barbeiro?.id == null ||
        dataHora == null) {
      mostrarErro(context, 'Dados do agendamento incompletos');
      return;
    }

    setState(() => _salvando = true);

    try {
      // Reconfere a disponibilidade: outro cliente pode ter pego o horário
      // enquanto esta tela estava aberta.
      final livres = await DatabaseService.instance.horariosDisponiveis(
        barbeiro!.id!,
        dataHora,
      );
      final hora = formatarHora(dataHora);
      if (!livres.contains(hora)) {
        if (!mounted) return;
        setState(() => _salvando = false);
        mostrarErro(context, 'O horário $hora acabou de ser ocupado');
        return;
      }

      final id = await DatabaseService.instance.criarAgendamento(
        Agendamento(
          idCliente: usuario!.id!,
          idBarbeiro: barbeiro.id!,
          idServico: servico!.id!,
          dataHora: dataHora.toIso8601String(),
          status: StatusAgendamento.confirmado,
        ),
      );

      if (!mounted) return;
      setState(() => _salvando = false);

      BookingFlow.agendamentoCriadoId = id;
      Navigator.of(context).pushNamed('/pagamento');
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, 'Não foi possível criar o agendamento: $e');
    }
  }

  void _cancelar() {
    BookingFlow.limpar();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    final barbeiro = BookingFlow.barbeiroSelecionado;
    final dataHora = BookingFlow.dataHoraCompleta;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'CONFIRMAÇÃO'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.gold,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Revise seu agendamento',
                  textAlign: TextAlign.center,
                  style: AppTheme.serif(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confira os dados antes de confirmar',
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                _linhaResumo(
                  'Serviço',
                  servico?.nome ?? '-',
                  detalhe: servico?.descricao,
                  icone: servico?.icone,
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Barbeiro',
                  barbeiro?.nome ?? '-',
                  detalhe: barbeiro?.especialidade,
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Data',
                  dataHora == null ? '-' : formatarDataExtenso(dataHora),
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Horário',
                  dataHora == null ? '-' : formatarHora(dataHora),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('Valor total'),
                      Text(
                        formatarReal(servico?.preco ?? 0),
                        style: AppTheme.serif(size: 26, color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                GoldButton(
                  texto: _salvando
                      ? 'CONFIRMANDO...'
                      : 'CONFIRMAR AGENDAMENTO',
                  onPressed: _salvando ? null : _confirmar,
                ),
                const SizedBox(height: 10),
                GoldOutlineButton(
                  texto: 'CANCELAR',
                  onPressed: _salvando ? null : _cancelar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaResumo(
    String rotulo,
    String valor, {
    String? detalhe,
    String? icone,
  }) {
    return GoldCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icone != null) ...[
            Text(icone, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(rotulo),
                const SizedBox(height: 6),
                Text(
                  valor,
                  style: AppTheme.sans(size: 15, weight: FontWeight.w700),
                ),
                if (detalhe != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detalhe,
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
