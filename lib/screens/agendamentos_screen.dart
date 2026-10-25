import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'acesso_negado_screen.dart';

/// Agendamentos, separados em duas abas: em aberto (ou próximos) e histórico.
///
/// A mesma tela tem três modos: os agendamentos do cliente e a agenda do
/// barbeiro logado (ambos em `/agendamentos`) e, com [agendaGeral], a agenda
/// de todos os barbeiros, aberta pelo administrador a partir do painel.
class AgendamentosScreen extends StatefulWidget {
  const AgendamentosScreen({
    super.key,
    this.agendaGeral = false,
    this.escolherPeriodo = escolherPeriodoNoCalendario,
  });

  /// Agenda geral do administrador: todos os atendimentos, de todos os
  /// barbeiros, com as mesmas ações do barbeiro.
  final bool agendaGeral;

  /// Abre o calendário do filtro de período da agenda geral (os testes
  /// trocam por um falso).
  final EscolherPeriodo escolherPeriodo;

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

/// Escolhe um período, de um dia até outro, a partir do [atual].
typedef EscolherPeriodo = Future<DateTimeRange?> Function(
  BuildContext context,
  DateTimeRange? atual,
);

/// Calendário do Material, em português: vai até o último dia que aceita
/// reserva.
Future<DateTimeRange?> escolherPeriodoNoCalendario(
  BuildContext context,
  DateTimeRange? atual,
) {
  final hoje = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DatabaseService.ultimoDiaDaAgenda(hoje),
    currentDate: hoje,
    initialDateRange: atual,
    helpText: 'Escolha o período',
    saveText: 'Filtrar',
  );
}

class _AgendamentosScreenState extends State<AgendamentosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _abas;

  /// Cada agendamento já vem com o seu pagamento (uma consulta só).
  List<Agendamento> _agendamentos = [];
  bool _carregando = true;
  String? _erro;

  /// Barbeiros da barbearia, para o filtro da agenda geral.
  List<Barbeiro> _barbeiros = [];

  /// Filtros da agenda geral, nas duas abas: o barbeiro e o período (de um
  /// dia até outro). `null` mostra todos.
  int? _filtroBarbeiro;
  DateTimeRange? _periodo;

  @override
  void initState() {
    super.initState();
    _abas = TabController(length: 2, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  /// A mesma tela serve o cliente, o profissional e o administrador; muda a
  /// origem dos dados, os rótulos e as ações.
  bool get _modoBarbeiro => AuthService.instance.ehBarbeiro;

  bool get _agendaGeral => widget.agendaGeral;

  /// Quem usa a tela fala pela barbearia — o barbeiro ou o administrador na
  /// agenda geral: recebe pagamentos, conclui, registra falta e cancela sem
  /// multa.
  bool get _pelaBarbearia => _modoBarbeiro || _agendaGeral;

  Future<void> _carregar() async {
    final auth = AuthService.instance;
    final idBarbeiro = auth.barbeiroAtual?.id;
    final usuario = auth.usuarioAtual;

    final semConta = _agendaGeral
        ? !auth.podeAdministrar
        : _modoBarbeiro
        ? idBarbeiro == null
        : usuario?.id == null;
    if (semConta) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }

    try {
      final db = DatabaseService.instance;
      final lista = _agendaGeral
          ? await db.listarTodosAgendamentos()
          : _modoBarbeiro
          ? await db.listarAgendamentosBarbeiro(idBarbeiro!)
          : await db.listarAgendamentosCliente(usuario!.id!);
      final barbeiros = _agendaGeral
          ? await db.listarBarbeiros()
          : const <Barbeiro>[];

      if (!mounted) return;
      setState(() {
        _agendamentos = lista;
        _barbeiros = barbeiros;
        _carregando = false;
      });
    } catch (e) {
      // Antes só aparecia um aviso rápido, e a lista vazia passava por
      // "Nenhum agendamento futuro".
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar os agendamentos');
      });
    }
  }

  /// Confirma o recebimento de um pagamento pendente ("pagar na barbearia").
  ///
  /// Exclusivo da barbearia (barbeiro ou administrador): é quem está no caixa
  /// que dá a baixa.
  Future<void> _quitar(Agendamento a) async {
    if (!_pelaBarbearia) return;

    final pagamento = a.pagamento;
    final idPagamento = pagamento?.id;
    // Só o que está pendente pode ser recebido: um pagamento cancelado não
    // é dívida de ninguém.
    if (pagamento == null || idPagamento == null || !pagamento.pendente) {
      return;
    }
    final ehMulta = pagamento.natureza == NaturezaPagamento.multa;

    // O balcão é o único momento em que se sabe como o cliente pagou.
    final metodo = await showDialog<MetodoPagamento>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Como o cliente pagou?', style: AppTheme.titulo(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ehMulta
                  ? 'Multa de ${formatarReal(pagamento.valor)} de '
                        '${a.cliente?.nome ?? 'este cliente'} por '
                        'cancelamento fora do prazo. Multa não gera pontos '
                        'de fidelidade.'
                  : '${formatarReal(pagamento.valor)} de '
                        '${a.cliente?.nome ?? 'este cliente'}. '
                        'Ao confirmar, o cliente recebe '
                        '${pagamento.valor.round()} pontos de fidelidade.',
              style: AppTheme.texto(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...MetodoPagamento.values.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Cartao(
                  cor: AppColors.card2,
                  onTap: () => Navigator.of(ctx).pop(m),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconeCirculo(
                        icone: switch (m) {
                          MetodoPagamento.pix => Icons.pix,
                          MetodoPagamento.cartao => Icons.credit_card_rounded,
                          MetodoPagamento.dinheiro => Icons.payments_outlined,
                        },
                        tamanho: 40,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        m.label,
                        style: AppTheme.texto(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Agora não',
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );

    if (metodo == null) return;

    try {
      final recebido = await DatabaseService.instance.confirmarPagamento(
        idPagamento,
        metodo: metodo.label,
      );
      if (!mounted) return;
      if (!recebido) {
        mostrarErro(context, 'Este pagamento não está mais pendente');
      } else {
        mostrarSucesso(
          context,
          ehMulta
              ? 'Multa recebida de ${a.cliente?.nome ?? 'o cliente'}'
              : 'Recebimento confirmado · +${pagamento.valor.round()} '
                    'pontos para ${a.cliente?.nome ?? 'o cliente'}',
        );
      }
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao confirmar o pagamento'));
    }
  }

  /// Primeira aba.
  ///
  /// Para o cliente, o que ainda vai acontecer. Para a barbearia, tudo o que
  /// ainda não teve desfecho — inclusive o que já passou do horário e precisa
  /// ser concluído ou marcado como falta. Antes esses atendimentos caíam no
  /// histórico sem nenhuma ação e ficavam "confirmados" para sempre.
  bool _naPrimeiraAba(Agendamento a, DateTime agora) =>
      _pelaBarbearia ? a.emAberto : a.emAberto && !a.jaComecou(agora);

  List<Agendamento> get _proximos {
    final agora = DateTime.now();
    return _agendamentos.where((a) => _naPrimeiraAba(a, agora)).toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<Agendamento> get _historico {
    final agora = DateTime.now();
    return _agendamentos.where((a) => !_naPrimeiraAba(a, agora)).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  /// O serviço foi trocado por pontos (resgate), e não pago em dinheiro. Na
  /// desistência fora do prazo a penalidade é a perda dos pontos, não multa.
  static bool _pagoComPontos(Agendamento a) =>
      a.pagamento?.natureza == NaturezaPagamento.resgate;

  /// Leva o cliente à escolha do profissional e do horário, com o serviço
  /// do agendamento. Na volta, reagendado ou não, a lista é relida.
  Future<void> _reagendar(Agendamento a) async {
    BookingFlow.iniciarReagendamento(a);
    await Navigator.of(context).pushNamed('/barbeiro');
    BookingFlow.limpar();
    if (mounted) await _carregar();
  }

  Future<void> _cancelar(Agendamento a) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancelar agendamento?', style: AppTheme.titulo(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pelaBarbearia
                  ? 'O horário voltará a ficar disponível. Como o '
                        'cancelamento parte da barbearia, o cliente não paga '
                        'multa e recebe de volta o que já tiver pago.'
                  : 'O horário voltará a ficar disponível para outros '
                        'clientes.',
              style: AppTheme.texto(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            // O cliente precisa saber da penalidade antes de decidir, não
            // depois. A barbearia é isenta: a falta é dela.
            if (!_pelaBarbearia && !DatabaseService.dentroDoPrazo(a.data)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pagoComPontos(a)
                            ? 'Falta menos de 1 hora para o atendimento. Os '
                                  '${DatabaseService.pontosParaPremio} pontos '
                                  'usados no resgate não serão devolvidos.'
                            : 'Falta menos de 1 hora para o atendimento. Será '
                                  'cobrada multa de '
                                  '${formatarReal(a.valor * DatabaseService.percentualMulta)}'
                                  ' (50% do serviço).',
                        style: AppTheme.texto(
                          size: 12,
                          color: AppColors.text,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Voltar',
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancelar agendamento',
              style: AppTheme.texto(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || a.id == null) return;

    try {
      final r = await DatabaseService.instance.cancelarAgendamento(
        a.id!,
        porBarbeiro: _pelaBarbearia,
      );
      // Cancelado, o horário perde o lembrete (regra de negócio 20).
      await AuthService.instance.atualizarLembretes();
      if (!mounted) return;
      await _mostrarDesfecho(r);
      if (!mounted) return;
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao cancelar'));
    }
  }

  /// Explica o acerto financeiro do cancelamento.
  Future<void> _mostrarDesfecho(
    ResultadoCancelamento r, {
    String? titulo,
  }) async {
    if (!r.comMulta &&
        r.estorno <= 0 &&
        r.pontosAjustados == 0 &&
        r.pontosRetidos == 0) {
      mostrarInfo(context, 'Agendamento cancelado');
      return;
    }

    final linhas = <String>[
      if (r.estorno > 0) 'Estorno de ${formatarReal(r.estorno)}',
      if (r.multa > 0) 'Multa retida: ${formatarReal(r.multa)}',
      if (r.multaAPagar > 0)
        'Multa de ${formatarReal(r.multaAPagar)} a pagar na barbearia',
      if (r.pontosAjustados > 0) '${r.pontosAjustados} pontos devolvidos',
      if (r.pontosAjustados < 0) '${r.pontosAjustados.abs()} pontos estornados',
      if (r.pontosRetidos > 0)
        '${r.pontosRetidos} pontos do resgate não devolvidos',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          titulo ??
              (r.comMulta
                  ? 'Cancelado com multa'
                  : r.pontosRetidos > 0
                  ? 'Cancelado fora do prazo'
                  : 'Agendamento cancelado'),
          style: AppTheme.titulo(size: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: linhas
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(color: AppColors.amarelo),
                      ),
                      Expanded(
                        child: Text(
                          l,
                          style: AppTheme.texto(size: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Entendi',
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
  }

  @override
  Widget build(BuildContext context) {
    // A agenda geral abre por navegação direta a partir do painel, sem passar
    // pelas rotas nomeadas: a permissão é conferida aqui também.
    if (_agendaGeral && !AuthService.instance.podeAdministrar) {
      return const AcessoNegadoScreen();
    }

    return Scaffold(
      appBar: BarberAppBar(
        titulo: _agendaGeral
            ? 'Agenda geral'
            : _modoBarbeiro
            ? 'Minha agenda'
            : 'Meus agendamentos',
        acoes: _modoBarbeiro
            ? [
                BotaoVidro(
                  icone: Icons.logout_rounded,
                  dica: 'Sair',
                  onPressed: _sair,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (_modoBarbeiro) _faixaProfissional(),
          // Abas em pílula, com o estilo do tema.
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(4),
            decoration: const ShapeDecoration(
              color: AppColors.card,
              shape: StadiumBorder(),
            ),
            child: TabBar(
              controller: _abas,
              tabs: [
                Tab(
                  height: 40,
                  text: _pelaBarbearia ? 'Em aberto' : 'Próximos',
                ),
                const Tab(height: 40, text: 'Histórico'),
              ],
            ),
          ),
          if (_agendaGeral && !_carregando && _erro == null) _filtros(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                : TabBarView(
                    controller: _abas,
                    children: [
                      _aba(_proximos, primeiraAba: true),
                      _aba(_historico, primeiraAba: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Filtros da agenda geral: o barbeiro num select e, ao lado, o calendário
  /// do período. Com um período escolhido, ele aparece embaixo, com o botão
  /// de limpar.
  Widget _filtros() {
    final periodo = _periodo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _selectBarbeiro()),
              const SizedBox(width: 10),
              _botaoCalendario(),
            ],
          ),
          if (periodo != null) ...[
            const SizedBox(height: 10),
            _etiquetaPeriodo(periodo),
          ],
        ],
      ),
    );
  }

  Widget _selectBarbeiro() {
    // Um barbeiro que saiu da lista volta o filtro para todos.
    final valor = _barbeiros.any((b) => b.id == _filtroBarbeiro)
        ? _filtroBarbeiro
        : null;
    final opcoes = <(int?, String)>[
      (null, 'Todos os barbeiros'),
      for (final b in _barbeiros) (b.id, b.nome),
    ];
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: valor,
          isExpanded: true,
          dropdownColor: AppColors.card2,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.muted,
          ),
          style: AppTheme.texto(size: 14, weight: FontWeight.w600),
          items: [
            for (final (id, nome) in opcoes)
              DropdownMenuItem(
                value: id,
                child: Row(
                  children: [
                    Icon(
                      id == null
                          ? Icons.groups_outlined
                          : Icons.person_outline_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(nome, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (id) => setState(() => _filtroBarbeiro = id),
        ),
      ),
    );
  }

  /// Fica amarelo enquanto há um período escolhido.
  Widget _botaoCalendario() {
    final ativo = _periodo != null;
    return Tooltip(
      message: 'Escolher período',
      child: Semantics(
        button: true,
        label: 'Escolher período',
        excludeSemantics: true,
        child: Material(
          color: ativo ? AppColors.amarelo : AppColors.card2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _escolherPeriodo,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.calendar_month_outlined,
                color: ativo ? Colors.black : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _escolherPeriodo() async {
    final periodo = await widget.escolherPeriodo(context, _periodo);
    if (periodo == null || !mounted) return;
    setState(() => _periodo = periodo);
  }

  /// "24/10/2026 até 27/10/2026" (ou só a data, num dia só) e o botão de
  /// limpar o período.
  Widget _etiquetaPeriodo(DateTimeRange periodo) {
    final inicio = formatarDataCurta(periodo.start);
    final fim = formatarDataCurta(periodo.end);
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: ShapeDecoration(
        color: AppColors.amarelo.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.date_range_outlined,
            size: 16,
            color: AppColors.amarelo,
          ),
          const SizedBox(width: 8),
          Text(
            inicio == fim ? inicio : '$inicio até $fim',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
          IconButton(
            tooltip: 'Limpar período',
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.amarelo,
            ),
            onPressed: () => setState(() => _periodo = null),
          ),
        ],
      ),
    );
  }

  /// Uma aba da agenda. Na agenda geral, só com o barbeiro e o período
  /// escolhidos nos filtros.
  Widget _aba(List<Agendamento> itens, {required bool primeiraAba}) {
    if (!_agendaGeral) return _lista(itens, primeiraAba: primeiraAba);

    final periodo = _periodo;
    final filtrados = itens.where((a) {
      if (_filtroBarbeiro != null && a.idBarbeiro != _filtroBarbeiro) {
        return false;
      }
      if (periodo == null) return true;
      final dia = _dia(a.data);
      return !dia.isBefore(_dia(periodo.start)) &&
          !dia.isAfter(_dia(periodo.end));
    }).toList();

    return _lista(
      filtrados,
      primeiraAba: primeiraAba,
      vazioPeloFiltro: itens.isNotEmpty && filtrados.isEmpty,
    );
  }

  Widget _lista(
    List<Agendamento> itens, {
    required bool primeiraAba,
    bool vazioPeloFiltro = false,
  }) {
    if (vazioPeloFiltro) {
      return const EstadoVazio(
        icone: Icons.filter_alt_off_outlined,
        titulo: 'Nada com esses filtros',
        descricao: 'Escolha outro barbeiro ou outro período.',
      );
    }
    if (itens.isEmpty) {
      return EstadoVazio(
        icone: primeiraAba
            ? Icons.event_available_outlined
            : Icons.history_rounded,
        titulo: primeiraAba
            ? (_pelaBarbearia
                  ? 'Nenhum atendimento marcado'
                  : 'Nenhum agendamento futuro')
            : 'Histórico vazio',
        descricao: primeiraAba
            ? (_agendaGeral
                  ? 'Os agendamentos de todos os barbeiros aparecem aqui.'
                  : _modoBarbeiro
                  ? 'Quando um cliente agendar com você, aparece aqui.'
                  : 'Agende um horário na aba de serviços.')
            : 'Atendimentos concluídos, cancelados ou com falta aparecem '
                  'aqui.',
      );
    }

    return RefreshIndicator(
      color: AppColors.amarelo,
      backgroundColor: AppColors.card,
      onRefresh: _carregar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Embaixo, o espaço da barra de navegação quando a tela é uma aba.
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: itens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(itens[i]),
      ),
    );
  }

  Widget _card(Agendamento a) {
    final agora = DateTime.now();
    final aguardando = a.aguardandoConclusao(agora);
    final corStatus = switch (a.status) {
      StatusAgendamento.confirmado =>
        aguardando ? AppColors.amarelo : AppColors.green,
      StatusAgendamento.cancelado => AppColors.red,
      StatusAgendamento.finalizado => AppColors.amarelo,
      StatusAgendamento.faltou => AppColors.red,
    };

    // As ações vêm das regras do próprio agendamento, não da aba em que ele
    // está — assim nada some da tela no minuto em que o horário chega.
    final acoes = <Widget>[
      // Concluir e registrar falta são atribuições da barbearia.
      if (_pelaBarbearia && a.podeFinalizar(agora))
        _acao(
          'Concluir',
          Icons.check_circle_outline,
          AppColors.amarelo,
          () => _finalizar(a),
        ),
      if (_pelaBarbearia && a.podeRegistrarFalta(agora))
        _acao(
          'Não compareceu',
          Icons.person_off_outlined,
          AppColors.red,
          () => _registrarFalta(a),
        ),
      // O cliente reagenda até 1 hora antes (regra de negócio 19); a
      // barbearia cancela.
      if (!_pelaBarbearia &&
          a.podeReagendar(agora, prazo: DatabaseService.prazoCancelamento))
        _acao(
          'Reagendar',
          Icons.edit_calendar_outlined,
          AppColors.amarelo,
          () => _reagendar(a),
        ),
      if (a.podeCancelar(agora))
        _acao(
          _pelaBarbearia ? 'Cancelar' : 'Cancelar agendamento',
          Icons.close,
          AppColors.red,
          () => _cancelar(a),
        ),
    ];

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconeCirculo(
                icone: iconeDoServico(a.servico?.icone ?? ''),
                tamanho: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.servico?.nome ?? 'Serviço',
                  style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                ),
              ),
              Etiqueta(
                texto: aguardando ? 'Aguardando conclusão' : a.status.label,
                cor: corStatus,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // O cliente vê quem vai atendê-lo; a barbearia vê quem será
          // atendido. Na agenda geral aparecem os dois.
          _linha(
            _pelaBarbearia ? Icons.face_outlined : Icons.person_outline,
            _pelaBarbearia
                ? (a.cliente?.nome ?? '-')
                : (a.barbeiro?.nome ?? '-'),
          ),
          if (_pelaBarbearia && (a.cliente?.telefone.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            _linha(Icons.phone_outlined, a.cliente!.telefone),
          ],
          if (_agendaGeral) ...[
            const SizedBox(height: 6),
            _linha(
              Icons.content_cut_outlined,
              'com ${a.barbeiro?.nome ?? '-'}',
            ),
          ],
          const SizedBox(height: 6),
          _linha(Icons.event_outlined, formatarDataHora(a.data)),
          const SizedBox(height: 6),
          _linha(Icons.payments_outlined, formatarReal(a.valor)),
          const SizedBox(height: 10),
          _statusPagamento(a),
          if (acoes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 4),
            Wrap(alignment: WrapAlignment.end, children: acoes),
          ],
        ],
      ),
    );
  }

  Widget _acao(String texto, IconData icone, Color cor, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 16, color: cor),
      label: Text(texto, style: AppTheme.texto(size: 12, color: cor)),
    );
  }

  /// O cliente não veio: aplica a política de cancelamento fora do prazo.
  Future<void> _registrarFalta(Agendamento a) async {
    if (!_pelaBarbearia || a.id == null) return;

    final penalidade = _pagoComPontos(a)
        ? 'Os ${DatabaseService.pontosParaPremio} pontos usados no resgate '
              'não serão devolvidos'
        : 'Será aplicada a multa de '
              '${formatarReal(a.valor * DatabaseService.percentualMulta)} '
              '(50% do serviço)';
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar falta?', style: AppTheme.titulo(size: 18)),
        content: Text(
          '${a.cliente?.nome ?? 'O cliente'} não compareceu ao horário de '
          '${formatarHora(a.data)}. $penalidade, como num cancelamento '
          'fora do prazo.',
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
              'Registrar falta',
              style: AppTheme.texto(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      final r = await DatabaseService.instance.registrarFalta(a.id!);
      if (!mounted) return;
      await _mostrarDesfecho(r, titulo: 'Falta registrada');
      if (!mounted) return;
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao registrar a falta'));
    }
  }

  /// Conclui o atendimento, atribuindo o status `finalizado`.
  ///
  /// É o único caminho que dá esse status a um agendamento — sem ele o
  /// indicador de concluídos dos relatórios nunca sai de zero.
  Future<void> _finalizar(Agendamento a) async {
    if (!_pelaBarbearia || a.id == null) return;

    final pendente = a.pagamento?.pendente ?? false;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Concluir atendimento?', style: AppTheme.titulo(size: 18)),
        content: Text(
          pendente
              ? 'O pagamento deste atendimento ainda está pendente. '
                    'Conclua apenas se já registrou o recebimento.'
              : 'O atendimento de ${a.cliente?.nome ?? 'este cliente'} será '
                    'marcado como concluído e sairá da lista de próximos.',
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
              'Concluir',
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

    if (confirmou != true) return;

    try {
      await DatabaseService.instance.finalizarAgendamento(a.id!);
      if (!mounted) return;
      mostrarSucesso(context, 'Atendimento concluído');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao concluir o atendimento'));
    }
  }

  /// Cabeçalho com o profissional logado e o movimento de hoje.
  Widget _faixaProfissional() {
    final b = AuthService.instance.barbeiroAtual;
    final hoje = DateTime.now();
    final doDia = _agendamentos
        .where(
          (a) =>
              a.status != StatusAgendamento.cancelado &&
              a.data.year == hoje.year &&
              a.data.month == hoje.month &&
              a.data.day == hoje.day,
        )
        .length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          AvatarIniciais(texto: b?.iniciais ?? '?', tamanho: 44, large: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RotuloCampo('Profissional'),
                const SizedBox(height: 3),
                Text(
                  b?.nome ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.texto(size: 14, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$doDia',
                style: AppTheme.titulo(size: 22, color: AppColors.amarelo),
              ),
              Text(
                'hoje',
                style: AppTheme.texto(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sair() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  /// Faixa com a situação do pagamento e, se pendente, o botão de quitar.
  Widget _statusPagamento(Agendamento a) {
    final p = a.pagamento;

    if (p == null) {
      return Row(
        children: [
          const Icon(Icons.help_outline, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sem pagamento registrado',
              style: AppTheme.texto(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    // Resgate de um atendimento que não aconteceu (falta ou cancelamento fora
    // do prazo): os pontos ficaram retidos.
    final pontosRetidos =
        p.confirmado &&
        p.natureza == NaturezaPagamento.resgate &&
        (a.status == StatusAgendamento.cancelado ||
            a.status == StatusAgendamento.faltou);
    if (pontosRetidos) {
      return Row(
        children: [
          const Icon(Icons.block, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DatabaseService.pontosParaPremio} pontos do resgate não '
              'devolvidos',
              style: AppTheme.texto(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    if (p.confirmado) {
      final descricao = switch (p.natureza) {
        NaturezaPagamento.resgate => 'Resgatado com pontos de fidelidade',
        NaturezaPagamento.multa => 'Multa paga via ${p.metodo}',
        _ =>
          'Pago via ${p.metodo}'
              '${p.cartaoFinal != null ? ' ····${p.cartaoFinal}' : ''}',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, size: 15, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  descricao,
                  style: AppTheme.texto(size: 12, color: AppColors.green),
                ),
              ),
            ],
          ),
          // O estorno aparece como complemento do pagamento original, e não
          // no lugar dele ("Pago via Estorno").
          if (a.valorEstornado > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.undo, size: 15, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estornado ${formatarReal(a.valorEstornado)}'
                    '${a.valorEstornado < p.valor ? ' (multa retida)' : ''}',
                    style: AppTheme.texto(size: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    if (p.cancelado) {
      return Row(
        children: [
          const Icon(Icons.block, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pagamento cancelado — nada a pagar',
              style: AppTheme.texto(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    final ehMulta = p.natureza == NaturezaPagamento.multa;

    // Só a barbearia confirma o recebimento: quem está no caixa é quem dá a
    // baixa. O cliente apenas acompanha a situação.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amarelo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.amarelo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              switch ((_pelaBarbearia, ehMulta)) {
                (true, true) =>
                  'Multa de ${formatarReal(p.valor)} pendente — confirme '
                      'ao receber',
                (true, false) => 'Pagamento pendente — confirme ao receber',
                (false, true) =>
                  'Multa de ${formatarReal(p.valor)} por cancelamento fora '
                      'do prazo. Pague no balcão.',
                (false, false) =>
                  'Pague no balcão no dia do atendimento. Os '
                      '${p.valor.round()} pontos entram após a confirmação.',
              },
              style: AppTheme.texto(
                size: 11,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ),
          if (_pelaBarbearia) ...[
            const SizedBox(width: 6),
            BotaoPrincipal(
              texto: 'Receber',
              expandido: false,
              onPressed: () => _quitar(a),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String texto) {
    return Row(
      children: [
        Icon(icone, size: 15, color: AppColors.muted),
        const SizedBox(width: 8),
        // Nome ou telefone longo quebra a linha em vez de estourar o card.
        Expanded(
          child: Text(
            texto,
            style: AppTheme.texto(size: 13, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
