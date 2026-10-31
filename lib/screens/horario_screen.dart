import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/animacoes.dart';
import '../widgets/common_widgets.dart';

/// Escolha de data e horário (`/horario`).
///
/// A régua mostra os dias de [DatabaseService.diasDisponiveis] (de hoje até 13
/// dias depois, sem os domingos), e os horários vêm de
/// [DatabaseService.horariosDisponiveis] — os já ocupados pelo barbeiro
/// naquele dia simplesmente não aparecem.
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
    _dias = DatabaseService.diasDisponiveis();
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
      final reagendando = BookingFlow.reagendando;
      var horarios = barbeiro?.id == null
          ? DatabaseService.horariosBase
          : await DatabaseService.instance.horariosDisponiveis(
              barbeiro!.id!,
              _dataSelecionada,
              // Só aparece o horário em que o serviço inteiro cabe e que não
              // conflita com outro atendimento do próprio cliente. Num
              // reagendamento, vale a duração registrada, e o horário atual
              // não conta como ocupado.
              duracaoMinutos:
                  reagendando?.duracaoMinutos ??
                  BookingFlow.servicoSelecionado?.duracaoMinutos,
              idCliente: AuthService.instance.usuarioAtual?.id,
              ignorarAgendamento: reagendando?.id,
            );
      // O horário atual, com o mesmo barbeiro, não é um horário novo.
      if (reagendando != null && reagendando.idBarbeiro == barbeiro?.id) {
        final atual = reagendando.data;
        if (_mesmoDia(atual, _dataSelecionada)) {
          final hora =
              '${atual.hour.toString().padLeft(2, '0')}:'
              '${atual.minute.toString().padLeft(2, '0')}';
          horarios = horarios.where((h) => h != hora).toList();
        }
      }

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

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _confirmar() async {
    BookingFlow.dataSelecionada = _dataSelecionada;
    BookingFlow.horaSelecionada = _horaSelecionada;
    final reagendando = BookingFlow.reagendando;
    if (reagendando != null) return _reagendar(reagendando);
    await Navigator.of(context).pushNamed('/confirmacao');
    // Na volta a grade pode ter mudado (o horário foi ocupado no meio do
    // caminho, por exemplo), então ela é relida.
    if (mounted) _carregarHorarios();
  }

  /// Troca o horário do agendamento (regra de negócio 19), depois de o
  /// cliente confirmar, e volta à lista de agendamentos.
  Future<void> _reagendar(Agendamento a) async {
    final barbeiro = BookingFlow.barbeiroSelecionado!;
    final novo = BookingFlow.dataHoraCompleta!;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reagendar?', style: AppTheme.titulo(size: 18)),
        content: Text(
          'De ${formatarDataHora(a.data)}, com ${a.barbeiro?.nome ?? '-'}, '
          'para ${formatarDataHora(novo)}, com ${barbeiro.nome}. O serviço e '
          'o pagamento continuam os mesmos.',
          style: AppTheme.texto(size: 13, color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Voltar',
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Reagendar',
              style: AppTheme.texto(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.amarelo,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    try {
      await DatabaseService.instance.reagendarAgendamento(
        a.id!,
        idCliente: AuthService.instance.usuarioAtual!.id!,
        idBarbeiro: barbeiro.id!,
        dataHora: novo,
      );
      // O lembrete acompanha o horário novo (regra de negócio 20).
      await AuthService.instance.atualizarLembretes();
      if (!mounted) return;
      mostrarSucesso(
        context,
        'Horário alterado para ${formatarDataHora(novo)}',
      );
      // Volta por cima do Horário e do Profissional, até a lista.
      var telas = 0;
      Navigator.of(context).popUntil((_) => telas++ >= 2);
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Não foi possível reagendar'));
      _carregarHorarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    final barbeiro = BookingFlow.barbeiroSelecionado;
    final reagendando = BookingFlow.reagendando != null;

    return Scaffold(
      appBar: BarberAppBar(titulo: reagendando ? 'Novo horário' : 'Horário'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                const TituloSecao('Escolha o dia'),
                const SizedBox(height: 12),
                _reguaDias(),
                const SizedBox(height: 28),
                const TituloSecao('Horários disponíveis'),
                const SizedBox(height: 12),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.amarelo,
                      ),
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const IconeCirculo(
                          icone: Icons.event_busy_outlined,
                          cor: AppColors.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum horário disponível neste dia',
                          textAlign: TextAlign.center,
                          style: AppTheme.texto(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escolha outra data na régua acima.',
                          textAlign: TextAlign.center,
                          style: AppTheme.texto(
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
                  Cartao(
                    selected: true,
                    child: Row(
                      children: [
                        const IconeCirculo(
                          icone: Icons.event_available_outlined,
                          tamanho: 44,
                          destaque: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                barbeiro?.nome ?? 'Profissional',
                                style: AppTheme.texto(
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formatarDataExtenso(_dataSelecionada),
                                style: AppTheme.texto(
                                  size: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _horaSelecionada!,
                          style: AppTheme.titulo(
                            size: 22,
                            color: AppColors.amarelo,
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
            child: BotaoPrincipal(
              texto: reagendando ? 'Reagendar' : 'Confirmar',
              onPressed: _horaSelecionada == null ? null : _confirmar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reguaDias() {
    return SizedBox(
      height: 84,
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
                width: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado ? AppColors.amarelo : AppColors.card,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      abreviacaoDiaSemana(dia),
                      style: AppTheme.texto(
                        size: 11,
                        weight: FontWeight.w600,
                        color: selecionado ? Colors.black : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dia.day}',
                      style: AppTheme.titulo(
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
    // Cada dia carregado é uma lista nova: os horários entram de novo.
    return Cascata(
      key: ObjectKey(_horarios),
      intervalo: const Duration(milliseconds: 30),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _horarios.indexed.map((item) {
          final (i, hora) = item;
          final selecionado = hora == _horaSelecionada;
          return ItemDaCascata(
            ordem: i,
            child: Semantics(
              button: true,
              selected: selecionado,
              child: GestureDetector(
                onTap: () => setState(() => _horaSelecionada = hora),
                child: Container(
                  // 14 + 14 de respiro deixam o alvo de toque perto dos 48 pt
                  // recomendados.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: ShapeDecoration(
                    color: selecionado ? AppColors.amarelo : AppColors.card,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    hora,
                    style: AppTheme.texto(
                      size: 14,
                      weight: FontWeight.w600,
                      color: selecionado ? Colors.black : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
