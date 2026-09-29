import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Meus agendamentos (`/agendamentos`), separados em Próximos e Histórico.
class AgendamentosScreen extends StatefulWidget {
  const AgendamentosScreen({super.key});

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _abas;
  /// Cada agendamento já vem com o seu pagamento (uma consulta só).
  List<Agendamento> _agendamentos = [];
  bool _carregando = true;

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

  /// A mesma tela serve o cliente e o profissional; só muda a origem dos
  /// dados e os rótulos.
  bool get _modoBarbeiro => AuthService.instance.ehBarbeiro;

  Future<void> _carregar() async {
    final auth = AuthService.instance;
    final idBarbeiro = auth.barbeiroAtual?.id;
    final usuario = auth.usuarioAtual;

    if (_modoBarbeiro ? idBarbeiro == null : usuario?.id == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }

    try {
      final db = DatabaseService.instance;
      final lista = _modoBarbeiro
          ? await db.listarAgendamentosBarbeiro(idBarbeiro!)
          : await db.listarAgendamentosCliente(usuario!.id!);

      if (!mounted) return;
      setState(() {
        _agendamentos = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, mensagemDeErro(e, 'Erro ao carregar agendamentos'));
    }
  }

  /// Confirma o recebimento de um pagamento pendente ("pagar na barbearia").
  ///
  /// Exclusivo do profissional: é quem está no caixa que dá a baixa.
  Future<void> _quitar(Agendamento a) async {
    if (!_modoBarbeiro) return;

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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Como o cliente pagou?', style: AppTheme.serif(size: 18)),
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
              style: AppTheme.sans(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...MetodoPagamento.values.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  onTap: () => Navigator.of(ctx).pop(m),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        switch (m) {
                          MetodoPagamento.pix => '📱',
                          MetodoPagamento.cartao => '💳',
                          MetodoPagamento.dinheiro => '💵',
                        },
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        m.label,
                        style: AppTheme.sans(
                          size: 14,
                          weight: FontWeight.w700,
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
              'AGORA NÃO',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
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
  /// Para o cliente, o que ainda vai acontecer. Para o profissional, tudo o
  /// que ainda não teve desfecho — inclusive o que já passou do horário e
  /// precisa ser concluído ou marcado como falta. Antes esses atendimentos
  /// caíam no histórico sem nenhuma ação e ficavam "confirmados" para sempre.
  bool _naPrimeiraAba(Agendamento a, DateTime agora) =>
      _modoBarbeiro ? a.emAberto : a.emAberto && !a.jaComecou(agora);

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

  Future<void> _cancelar(Agendamento a) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Cancelar agendamento?', style: AppTheme.serif(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _modoBarbeiro
                  ? 'O horário voltará a ficar disponível. Como o '
                        'cancelamento parte da barbearia, o cliente não paga '
                        'multa e recebe de volta o que já tiver pago.'
                  : 'O horário voltará a ficar disponível para outros '
                        'clientes.',
              style: AppTheme.sans(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            // O cliente precisa saber da multa antes de decidir, não depois.
            // O barbeiro é isento: a falta é da barbearia.
            if (!_modoBarbeiro && !DatabaseService.dentroDoPrazo(a.data)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red),
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
                        'Falta menos de 1 hora para o atendimento. Será '
                        'cobrada multa de '
                        '${formatarReal(a.valor * DatabaseService.percentualMulta)}'
                        ' (50% do serviço).',
                        style: AppTheme.sans(
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
              'VOLTAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'CANCELAR AGENDAMENTO',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
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
        porBarbeiro: _modoBarbeiro,
      );
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
    if (!r.comMulta && r.estorno <= 0 && r.pontosAjustados == 0) {
      mostrarInfo(context, 'Agendamento cancelado');
      return;
    }

    final linhas = <String>[
      if (r.estorno > 0) 'Estorno de ${formatarReal(r.estorno)}',
      if (r.multa > 0) 'Multa retida: ${formatarReal(r.multa)}',
      if (r.multaAPagar > 0)
        'Multa de ${formatarReal(r.multaAPagar)} a pagar na barbearia',
      if (r.pontosAjustados > 0) '${r.pontosAjustados} pontos devolvidos',
      if (r.pontosAjustados < 0)
        '${r.pontosAjustados.abs()} pontos estornados',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          titulo ??
              (r.comMulta ? 'Cancelado com multa' : 'Agendamento cancelado'),
          style: AppTheme.serif(size: 18),
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
                      const Text('•  ', style: TextStyle(color: AppColors.gold)),
                      Expanded(
                        child: Text(
                          l,
                          style: AppTheme.sans(size: 13, height: 1.4),
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
              'ENTENDI',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarberAppBar(
        titulo: _modoBarbeiro ? 'MINHA AGENDA' : 'MEUS AGENDAMENTOS',
        acoes: _modoBarbeiro
            ? [
                IconButton(
                  tooltip: 'Sair',
                  icon: const Icon(Icons.logout, color: AppColors.gold),
                  onPressed: _sair,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          const GoldDivider(),
          if (_modoBarbeiro) _faixaProfissional(),
          TabBar(
            controller: _abas,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            labelStyle: AppTheme.sans(size: 13, weight: FontWeight.w700),
            unselectedLabelStyle: AppTheme.sans(size: 13),
            tabs: [
              Tab(text: _modoBarbeiro ? 'Em aberto' : 'Próximos'),
              const Tab(text: 'Histórico'),
            ],
          ),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : TabBarView(
                    controller: _abas,
                    children: [
                      _lista(_proximos, primeiraAba: true),
                      _lista(_historico, primeiraAba: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Agendamento> itens, {required bool primeiraAba}) {
    if (itens.isEmpty) {
      return EstadoVazio(
        icone: primeiraAba ? '📅' : '🗂️',
        titulo: primeiraAba
            ? (_modoBarbeiro
                  ? 'Nenhum atendimento marcado'
                  : 'Nenhum agendamento futuro')
            : 'Histórico vazio',
        descricao: primeiraAba
            ? (_modoBarbeiro
                  ? 'Quando um cliente agendar com você, aparece aqui.'
                  : 'Agende um horário na aba de serviços.')
            : 'Atendimentos concluídos, cancelados ou com falta aparecem '
                  'aqui.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: _carregar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
        aguardando ? AppColors.gold : AppColors.green,
      StatusAgendamento.cancelado => AppColors.red,
      StatusAgendamento.finalizado => AppColors.gold,
      StatusAgendamento.faltou => AppColors.red,
    };

    // As ações vêm das regras do próprio agendamento, não da aba em que ele
    // está — assim nada some da tela no minuto em que o horário chega.
    final acoes = <Widget>[
      // Concluir e registrar falta são atribuições do profissional.
      if (_modoBarbeiro && a.podeFinalizar(agora))
        _acao(
          'Finalizar',
          Icons.check_circle_outline,
          AppColors.gold,
          () => _finalizar(a),
        ),
      if (_modoBarbeiro && a.podeRegistrarFalta(agora))
        _acao(
          'Não compareceu',
          Icons.person_off_outlined,
          AppColors.red,
          () => _registrarFalta(a),
        ),
      if (a.podeCancelar(agora))
        _acao(
          _modoBarbeiro ? 'Cancelar' : 'Cancelar agendamento',
          Icons.close,
          AppColors.red,
          () => _cancelar(a),
        ),
    ];

    return GoldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                a.servico?.icone ?? '💈',
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.servico?.nome ?? 'Serviço',
                  style: AppTheme.serif(size: 17),
                ),
              ),
              GoldBadge(
                texto: aguardando ? 'Aguardando conclusão' : a.status.label,
                cor: corStatus,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _linha(
            _modoBarbeiro ? Icons.face_outlined : Icons.person_outline,
            _modoBarbeiro
                ? (a.cliente?.nome ?? '-')
                : (a.barbeiro?.nome ?? '-'),
          ),
          if (_modoBarbeiro && (a.cliente?.telefone.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            _linha(Icons.phone_outlined, a.cliente!.telefone),
          ],
          const SizedBox(height: 6),
          _linha(Icons.event_outlined, formatarDataHora(a.data)),
          const SizedBox(height: 6),
          _linha(
            Icons.payments_outlined,
            formatarReal(a.valor),
          ),
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
      label: Text(texto, style: AppTheme.sans(size: 12, color: cor)),
    );
  }

  /// O cliente não veio: aplica a política de cancelamento fora do prazo.
  Future<void> _registrarFalta(Agendamento a) async {
    if (!_modoBarbeiro || a.id == null) return;

    final multa = a.valor * DatabaseService.percentualMulta;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Registrar falta?', style: AppTheme.serif(size: 18)),
        content: Text(
          '${a.cliente?.nome ?? 'O cliente'} não compareceu ao horário de '
          '${formatarHora(a.data)}. Será aplicada a multa de '
          '${formatarReal(multa)} (50% do serviço), como num cancelamento '
          'fora do prazo.',
          style: AppTheme.sans(size: 13, color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'VOLTAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'REGISTRAR FALTA',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
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
    if (!_modoBarbeiro || a.id == null) return;

    final pendente = a.pagamento?.pendente ?? false;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Finalizar atendimento?', style: AppTheme.serif(size: 18)),
        content: Text(
          pendente
              ? 'O pagamento deste atendimento ainda está pendente. '
                    'Finalize apenas se já registrou o recebimento.'
              : 'O atendimento de ${a.cliente?.nome ?? 'este cliente'} será '
                    'marcado como concluído e sairá da lista de próximos.',
          style: AppTheme.sans(size: 13, color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'VOLTAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'FINALIZAR',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.gold,
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
      mostrarSucesso(context, 'Atendimento finalizado');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao finalizar'));
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
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GoldAvatar(texto: b?.iniciais ?? '?', tamanho: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Profissional'),
                const SizedBox(height: 3),
                Text(
                  b?.nome ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$doDia',
                style: AppTheme.serif(size: 22, color: AppColors.gold),
              ),
              Text(
                'hoje',
                style: AppTheme.sans(size: 10, color: AppColors.muted),
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
              style: AppTheme.sans(size: 12, color: AppColors.muted),
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
                  style: AppTheme.sans(size: 12, color: AppColors.green),
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
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
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
              style: AppTheme.sans(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    final ehMulta = p.natureza == NaturezaPagamento.multa;

    // Só o profissional confirma o recebimento: quem está no caixa é quem
    // dá a baixa. O cliente apenas acompanha a situação.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              switch ((_modoBarbeiro, ehMulta)) {
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
              style: AppTheme.sans(
                size: 11,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ),
          if (_modoBarbeiro) ...[
            const SizedBox(width: 6),
            GoldButton(
              texto: 'RECEBER',
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
            style: AppTheme.sans(size: 13, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
