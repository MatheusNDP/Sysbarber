import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Escolha de data e horário (`/horario`).
///
/// Os horários vêm de [DatabaseService.horariosDisponiveis] — os já ocupados
/// pelo barbeiro naquele dia simplesmente não aparecem.
class HorarioScreen extends StatefulWidget {
  const HorarioScreen({super.key});

  @override
  State<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen> {
  late DateTime _dataSelecionada;
  String? _horaSelecionada;
  List<String> _horarios = [];
  bool _carregando = true;
  String? _erro;

  /// Número da consulta mais recente. Trocar de dia rápido dispara várias;
  /// só a última pode preencher a grade, senão os horários de um dia
  /// apareceriam sob outro.
  int _consulta = 0;

  late final List<DateTime> _dias;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _dias = List.generate(
      7,
      (i) => DateTime(hoje.year, hoje.month, hoje.day).add(Duration(days: i)),
    );
    _dataSelecionada = _dias.first;
    _carregarHorarios();
  }

  Future<void> _carregarHorarios() async {
    final consulta = ++_consulta;
    setState(() {
      _carregando = true;
      _erro = null;
      _horaSelecionada = null;
    });

    try {
      final barbeiro = BookingFlow.barbeiroSelecionado;
      final horarios = barbeiro?.id == null
          ? DatabaseService.horariosBase
          : await DatabaseService.instance.horariosDisponiveis(
              barbeiro!.id!,
              _dataSelecionada,
              // Só aparece o horário em que o serviço inteiro cabe e que não
              // conflita com outro atendimento do próprio cliente.
              duracaoMinutos: BookingFlow.servicoSelecionado?.duracaoMinutos,
              idCliente: AuthService.instance.usuarioAtual?.id,
            );

      if (!mounted || consulta != _consulta) return;
      setState(() {
        _horarios = horarios;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar os horários');
      });
    }
  }

  void _selecionarData(DateTime data) {
    setState(() => _dataSelecionada = data);
    _carregarHorarios();
  }

  Future<void> _confirmar() async {
    BookingFlow.dataSelecionada = _dataSelecionada;
    BookingFlow.horaSelecionada = _horaSelecionada;
    await Navigator.of(context).pushNamed('/confirmacao');
    // Na volta a grade pode ter mudado (o horário foi ocupado no meio do
    // caminho, por exemplo), então ela é relida.
    if (mounted) _carregarHorarios();
  }

  @override
  Widget build(BuildContext context) {
    final barbeiro = BookingFlow.barbeiroSelecionado;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'HORÁRIO'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                const SectionLabel('Escolha o dia'),
                const SizedBox(height: 12),
                _reguaDias(),
                const SizedBox(height: 28),
                const SectionLabel('Horários disponíveis'),
                const SizedBox(height: 12),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  )
                else if (_erro != null)
                  EstadoErro(
                    mensagem: _erro!,
                    onTentarNovamente: _carregarHorarios,
                  )
                else if (_horarios.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 34)),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum horário disponível neste dia',
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escolha outra data na régua acima.',
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _chipsHorarios(),
                const SizedBox(height: 28),
                if (_horaSelecionada != null)
                  GoldCard(
                    selected: true,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available,
                          color: AppColors.gold,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                barbeiro?.nome ?? 'Profissional',
                                style: AppTheme.sans(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formatarDataExtenso(_dataSelecionada),
                                style: AppTheme.sans(
                                  size: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _horaSelecionada!,
                          style: AppTheme.serif(
                            size: 22,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GoldButton(
              texto: 'CONFIRMAR',
              onPressed: _horaSelecionada == null ? null : _confirmar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reguaDias() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final dia = _dias[i];
          final selecionado =
              dia.day == _dataSelecionada.day &&
              dia.month == _dataSelecionada.month;

          // Leitor de tela anuncia a data completa ("Terça, 30 de setembro")
          // como botão, e não "TER 30" solto.
          return Semantics(
            button: true,
            selected: selecionado,
            label: formatarDataExtenso(dia),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _selecionarData(dia),
              child: Container(
                width: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado ? AppColors.gold : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selecionado ? AppColors.gold : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      abreviacaoDiaSemana(dia),
                      style: AppTheme.sans(
                        size: 10,
                        weight: FontWeight.w700,
                        color: selecionado ? Colors.black : AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dia.day}',
                      style: AppTheme.serif(
                        size: 20,
                        color: selecionado ? Colors.black : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chipsHorarios() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _horarios.map((hora) {
        final selecionado = hora == _horaSelecionada;
        return Semantics(
          button: true,
          selected: selecionado,
          child: GestureDetector(
            onTap: () => setState(() => _horaSelecionada = hora),
            child: Container(
              // 14 + 14 de respiro deixam o alvo de toque perto dos 48 pt
              // recomendados.
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: selecionado ? AppColors.gold : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selecionado ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Text(
                hora,
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: selecionado ? Colors.black : AppColors.text,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
