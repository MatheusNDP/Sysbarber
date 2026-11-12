import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/animacoes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/paginacao.dart';
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

  /// A primeira aba, inteira. Para o cliente ("Próximos"), o que ainda vai
  /// acontecer. Para a barbearia ("Em aberto"), tudo o que ainda não teve
  /// desfecho — inclusive o que já passou do horário e precisa ser concluído
  /// ou marcado como falta. Cada agendamento já vem com o seu pagamento (uma
  /// consulta só).
  List<Agendamento> _emAberto = [];

  /// O histórico, de 10 em 10: ao chegar ao fim da lista, vem a próxima
  /// página. Na agenda geral, já com os filtros.
  late final _historico = Paginacao<Agendamento>(
    buscar: _buscarHistorico,
    chave: (a) => a.id,
  );

  /// Na agenda geral, com o histórico filtrado vazio: há histórico sem os
  /// filtros? Separa "Nada com esses filtros" de "Histórico vazio".
  bool _temHistoricoSemFiltro = false;

  /// Atendimentos de hoje do barbeiro (o número na faixa do topo), contados
  /// no banco: o histórico não vem inteiro.
  int _doDia = 0;

  bool _carregando = true;
  String? _erro;

  /// Barbeiros da barbearia, para o filtro da agenda geral.
  List<Barbeiro> _barbeiros = [];

  /// Filtros da agenda do barbeiro e da agenda geral. O barbeiro (só na
  /// agenda geral) e o período (de um dia até outro) valem nas duas abas;
  /// `null` mostra todos. O status vale só no histórico.
  int? _filtroBarbeiro;
  DateTimeRange? _periodo;
  FiltroDeStatus _filtroStatus = FiltroDeStatus.todos;

  @override
  void initState() {
    super.initState();
    _abas = TabController(length: 2, vsync: this);
    // O select de status só aparece na aba do histórico: a tela muda quando
    // a aba muda, e não a cada passo do deslizar entre elas.
    var aba = _abas.index;
    _abas.addListener(() {
      if (_abas.index == aba || !mounted) return;
      aba = _abas.index;
      setState(() {});
    });
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

  /// A barbearia filtra a agenda; o cliente, não.
  bool get _temFiltros => _pelaBarbearia;

  bool get _noHistorico => _abas.index == 1;

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
      final emAberto = await db.listarAgendaEmAberto(
        idCliente: _pelaBarbearia ? null : usuario!.id!,
        idBarbeiro: _modoBarbeiro ? idBarbeiro : null,
      );
      final barbeiros = _agendaGeral
          ? await db.listarBarbeiros()
          : const <Barbeiro>[];
      final doDia = _modoBarbeiro
          ? await db.contarAtendimentosDoDia(idBarbeiro!, DateTime.now())
          : 0;
      await _carregarHistorico();

      if (!mounted) return;
      setState(() {
        _emAberto = emAberto;
        _barbeiros = barbeiros;
        _doDia = doDia;
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

  /// Uma página do histórico de quem usa a tela; na agenda do barbeiro e na
  /// geral, com os filtros.
  Future<List<Agendamento>> _buscarHistorico(int deslocamento, int limite) {
    final auth = AuthService.instance;
    final periodo = _temFiltros ? _periodo : null;
    return DatabaseService.instance.listarHistoricoAgenda(
      idCliente: _pelaBarbearia ? null : auth.usuarioAtual?.id,
      idBarbeiro: _agendaGeral ? _filtroBarbeiro : auth.barbeiroAtual?.id,
      de: periodo?.start,
      ate: periodo?.end,
      status: _temFiltros ? _filtroStatus : FiltroDeStatus.todos,
      deslocamento: deslocamento,
      limite: limite,
    );
  }

  /// Volta o histórico à primeira página (ao abrir, depois de uma ação e ao
  /// trocar os filtros).
  Future<void> _carregarHistorico() async {
    await _historico.reiniciar();
    final filtrado =
        _temFiltros &&
        (_filtroBarbeiro != null ||
            _periodo != null ||
            _filtroStatus != FiltroDeStatus.todos);
    _temHistoricoSemFiltro =
        filtrado &&
        _historico.itens.isEmpty &&
        (await DatabaseService.instance.listarHistoricoAgenda(
          idBarbeiro: _modoBarbeiro
              ? AuthService.instance.barbeiroAtual?.id
              : null,
          limite: 1,
        )).isNotEmpty;
  }

  /// Os filtros mudaram: o histórico recomeça com eles.
  Future<void> _filtrar() async {
    setState(() {});
    try {
      await _carregarHistorico();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao carregar o histórico'));
    }
    if (mounted) setState(() {});
  }

  /// A rolagem do histórico chegou perto do fim: vem a próxima página.
  Future<void> _carregarMaisHistorico() async {
    try {
      if (await _historico.carregarMais() && mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao carregar o histórico'));
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
    final metodo = await _perguntarComoPagou(
      ehMulta
          ? 'Multa de ${formatarReal(pagamento.valor)} de '
                '${a.cliente?.nome ?? 'este cliente'} '
                '${_motivoDaMulta(a)}. Multa não gera pontos de '
                'fidelidade.'
          : '${formatarReal(pagamento.valor)} de '
                '${a.cliente?.nome ?? 'este cliente'}. '
                'Ao confirmar, o cliente recebe '
                '${pagamento.valor.round()} pontos de fidelidade.',
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

  /// Pergunta como o cliente pagou no balcão (Pix, Cartão ou Dinheiro), com
  /// o [texto] explicando o valor. `null` se a barbearia desistir.
  Future<MetodoPagamento?> _perguntarComoPagou(String texto) {
    return showDialog<MetodoPagamento>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Como o cliente pagou?', style: AppTheme.titulo(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              texto,
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
  }

  /// O serviço foi trocado por pontos (resgate), e não pago em dinheiro. Na
  /// desistência fora do prazo a penalidade é a perda dos pontos, não multa.
  static bool _pagoComPontos(Agendamento a) =>
      a.pagamento?.natureza == NaturezaPagamento.resgate;

  /// Por que a multa foi cobrada: a falta e o cancelamento fora do prazo
  /// têm a mesma penalidade (regra de negócio 8), mas são desfechos
  /// diferentes.
  static String _motivoDaMulta(Agendamento a) =>
      a.status == StatusAgendamento.faltou
      ? 'por não comparecer ao horário'
      : 'por cancelamento fora do prazo';

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

    // A multa sai do que o cliente já pagou (retida) ou fica para o balcão
    // (a pagar); quem ia pagar na barbearia não tem nada retido.
    final multaRetida = r.multa - r.multaAPagar;
    final linhas = <String>[
      if (r.estorno > 0) 'Estorno de ${formatarReal(r.estorno)}',
      if (multaRetida > 0) 'Multa retida: ${formatarReal(multaRetida)}',
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
        // Sair fica só no Perfil, como para o cliente e o administrador.
      ),
      body: Column(
        children: [
          if (_modoBarbeiro) _faixaProfissional(),
          // Abas com os cantos arredondados, como os filtros, e o estilo do
          // tema.
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
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
          if (_temFiltros && !_carregando && _erro == null) _filtros(),
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
                      _aba(_emAberto, primeiraAba: true),
                      _abaHistorico(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Filtros da agenda do barbeiro e da geral: na geral, o barbeiro num
  /// select; no histórico, o status; e, ao lado, o calendário do período.
  /// Com um período escolhido, ele aparece embaixo, com o botão de limpar.
  Widget _filtros() {
    final periodo = _periodo;
    final status = _noHistorico ? _selectStatus() : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_agendaGeral)
                Expanded(child: _selectBarbeiro())
              else if (status != null)
                Expanded(child: status)
              else
                const Spacer(),
              const SizedBox(width: 10),
              _botaoCalendario(),
            ],
          ),
          // Na agenda geral, o status vem embaixo do barbeiro.
          if (_agendaGeral && status != null) ...[
            const SizedBox(height: 10),
            status,
          ],
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
    return _caixaDeSelecao<int?>(
      valor: valor,
      opcoes: [
        (null, 'Todos os barbeiros', Icons.groups_outlined),
        for (final b in _barbeiros)
          (b.id, b.nome, Icons.person_outline_rounded),
      ],
      aoMudar: (id) {
        if (id == _filtroBarbeiro) return;
        _filtroBarbeiro = id;
        _filtrar();
      },
      dica: 'Filtrar por barbeiro',
    );
  }

  /// O status do histórico: todos, quem está devendo ou um desfecho.
  Widget _selectStatus() {
    return _caixaDeSelecao<FiltroDeStatus>(
      valor: _filtroStatus,
      opcoes: [
        for (final f in FiltroDeStatus.values)
          (
            f,
            f.label,
            switch (f) {
              FiltroDeStatus.todos => Icons.filter_list_rounded,
              FiltroDeStatus.devendo => Icons.payments_outlined,
              FiltroDeStatus.concluidos => Icons.check_circle_outline,
              FiltroDeStatus.cancelados => Icons.close_rounded,
              FiltroDeStatus.faltas => Icons.person_off_outlined,
            },
          ),
      ],
      aoMudar: (f) {
        if (f == null || f == _filtroStatus) return;
        _filtroStatus = f;
        _filtrar();
      },
      dica: 'Filtrar por status',
    );
  }

  /// Um select dos filtros, com um ícone em cada opção. O menu abre embaixo
  /// do campo, da mesma largura, com a opção escolhida marcada.
  Widget _caixaDeSelecao<T>({
    required T valor,
    required List<(T, String, IconData)> opcoes,
    required ValueChanged<T?> aoMudar,
    required String dica,
  }) {
    final (_, nomeAtual, iconeAtual) = opcoes.firstWhere(
      (o) => o.$1 == valor,
      orElse: () => opcoes.first,
    );
    // O efeito do toque fica no próprio campo, com os mesmos cantos
    // arredondados (antes vazava pelos cantos, de fora do campo).
    final cantos = BorderRadius.circular(16);
    return LayoutBuilder(
      builder: (_, limites) => Material(
        color: AppColors.card2,
        borderRadius: cantos,
        child: PopupMenuButton<T>(
          tooltip: dica,
          borderRadius: cantos,
          initialValue: valor,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: AppColors.card2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // A faixa da opção marcada não passa dos cantos arredondados.
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints.tightFor(width: limites.maxWidth),
          onSelected: aoMudar,
          itemBuilder: (_) => [
            for (final (opcao, nome, icone) in opcoes)
              PopupMenuItem<T>(
                value: opcao,
                child: Row(
                  children: [
                    Icon(icone, size: 18, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        nome,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.texto(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              children: [
                Icon(iconeAtual, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nomeAtual,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.texto(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
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
    _periodo = periodo;
    _filtrar();
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
            onPressed: () {
              _periodo = null;
              _filtrar();
            },
          ),
        ],
      ),
    );
  }

  /// A primeira aba. Na agenda do barbeiro e na geral, só com o barbeiro e
  /// o período escolhidos nos filtros.
  Widget _aba(List<Agendamento> itens, {required bool primeiraAba}) {
    if (!_temFiltros) return _lista(itens, primeiraAba: primeiraAba);

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

  /// O histórico, já filtrado pelo banco, de 10 em 10.
  Widget _abaHistorico() => _lista(
    _historico.itens,
    primeiraAba: false,
    vazioPeloFiltro: _temHistoricoSemFiltro && _historico.itens.isEmpty,
    paginado: true,
  );

  Widget _lista(
    List<Agendamento> itens, {
    required bool primeiraAba,
    bool vazioPeloFiltro = false,
    bool paginado = false,
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

    final temMais = paginado && _historico.temMais;
    final lista = RefreshIndicator(
      color: AppColors.amarelo,
      backgroundColor: AppColors.card,
      onRefresh: _carregar,
      child: Cascata(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          // Embaixo, o espaço da barra de navegação quando a tela é uma aba.
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          // No histórico, o indicador da próxima página vem por último.
          itemCount: itens.length + (temMais ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => i == itens.length
              ? FimDaPaginacao(temMais: temMais)
              : ItemDaCascata(ordem: i, child: _card(itens[i])),
        ),
      ),
    );
    if (!paginado) return lista;
    return CarregarAoChegarNoFim(
      aoChegarNoFim: _carregarMaisHistorico,
      child: lista,
    );
  }

  Widget _card(Agendamento a) {
    final agora = DateTime.now();
    final aguardando = a.aguardandoConclusao(agora);
    // O cliente vê o que falta da parte dele: pagar no balcão. A barbearia
    // vê o que falta da parte dela: concluir (e o "Receber", logo abaixo).
    final etiqueta = !_pelaBarbearia && a.aguardandoPagamento(agora)
        ? 'Aguardando pagamento'
        : aguardando
        ? 'Aguardando conclusão'
        : a.status.label;
    final faixaPagamento = _statusPagamento(a);
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
              // O nome e a etiqueta ficam lado a lado quando cabem; com a
              // fonte grande, a etiqueta desce para a linha de baixo, em vez
              // de espremer o nome até quebrá-lo no meio da palavra.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      a.servico?.nome ?? 'Serviço',
                      style: AppTheme.titulo(
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Etiqueta(texto: etiqueta, cor: corStatus),
                  ],
                ),
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
          if (faixaPagamento != null) ...[
            const SizedBox(height: 10),
            faixaPagamento,
          ],
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
          '${a.cliente?.nome ?? 'O cliente'} não compareceu ao horário das '
          '${formatarHora(a.data)}. $penalidade.',
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

    // O cliente não sai sem pagar (regra de negócio 13): o serviço de pagar
    // no balcão é recebido e concluído de uma vez.
    final pagamento = a.pagamento;
    if (pagamento != null &&
        pagamento.pendente &&
        pagamento.natureza == NaturezaPagamento.servico) {
      final metodo = await _perguntarComoPagou(
        '${formatarReal(pagamento.valor)} de '
        '${a.cliente?.nome ?? 'este cliente'}. Para concluir, registre o '
        'pagamento: o cliente recebe ${pagamento.valor.round()} pontos de '
        'fidelidade.',
      );
      if (metodo == null) return;
      try {
        await DatabaseService.instance.finalizarAgendamento(
          a.id!,
          metodo: metodo.label,
        );
        if (!mounted) return;
        mostrarSucesso(
          context,
          'Atendimento concluído · +${pagamento.valor.round()} pontos para '
          '${a.cliente?.nome ?? 'o cliente'}',
        );
        await _carregar();
      } catch (e) {
        if (!mounted) return;
        mostrarErro(
          context,
          mensagemDeErro(e, 'Erro ao concluir o atendimento'),
        );
      }
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Concluir atendimento?', style: AppTheme.titulo(size: 18)),
        content: Text(
          'O atendimento de ${a.cliente?.nome ?? 'este cliente'} será '
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
    final doDia = _doDia;

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
          AvatarIniciais(
            texto: b?.iniciais ?? '?',
            foto: b?.foto,
            tamanho: 44,
            large: true,
          ),
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

  /// Faixa com a situação do pagamento e, se pendente, o botão de quitar.
  /// Nula no serviço que o cliente vai pagar no balcão: para ele, a etiqueta
  /// "Aguardando pagamento" já diz isso, depois do horário.
  Widget? _statusPagamento(Agendamento a) {
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
    if (!_pelaBarbearia && !ehMulta) return null;
    // O serviço de um atendimento em aberto é recebido no Concluir (regra
    // de negócio 13); o Receber fica para as multas.
    final recebeAoConcluir = !ehMulta && a.emAberto;

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
                // O Concluir só aparece a partir do dia do atendimento.
                (true, false) when recebeAoConcluir =>
                  a.podeFinalizar(DateTime.now())
                      ? 'Pagamento no balcão — registre ao concluir'
                      : 'Pagamento no balcão, no dia do atendimento',
                (true, false) => 'Pagamento pendente — confirme ao receber',
                (false, _) =>
                  'Multa de ${formatarReal(p.valor)} ${_motivoDaMulta(a)}. '
                      'Pague no balcão.',
              },
              style: AppTheme.texto(
                size: 11,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ),
          if (_pelaBarbearia && !recebeAoConcluir) ...[
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
