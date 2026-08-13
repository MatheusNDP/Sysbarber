import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
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
  List<Agendamento> _agendamentos = [];

  /// Pagamento de cada agendamento, indexado pelo id do agendamento.
  Map<int, Pagamento> _pagamentos = {};
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

      final pagamentos = <int, Pagamento>{};
      for (final a in lista) {
        if (a.id == null) continue;
        final p = await db.buscarPagamentoDoAgendamento(a.id!);
        if (p != null) pagamentos[a.id!] = p;
      }

      if (!mounted) return;
      setState(() {
        _agendamentos = lista;
        _pagamentos = pagamentos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao carregar agendamentos: $e');
    }
  }

  /// Confirma o recebimento de um pagamento pendente ("pagar na barbearia").
  ///
  /// Exclusivo do profissional: é quem está no caixa que dá a baixa.
  Future<void> _quitar(Agendamento a) async {
    if (!_modoBarbeiro) return;

    final pagamento = _pagamentos[a.id];
    final idPagamento = pagamento?.id;
    if (pagamento == null || idPagamento == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Confirmar recebimento?', style: AppTheme.serif(size: 18)),
        content: Text(
          'Confirma o recebimento de ${formatarReal(pagamento.valor)} de '
          '${a.cliente?.nome ?? 'este cliente'}?\n\n'
          'O cliente receberá ${pagamento.valor.round()} pontos de '
          'fidelidade.',
          style: AppTheme.sans(size: 13, color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'AGORA NÃO',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'CONFIRMAR RECEBIMENTO',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await DatabaseService.instance.confirmarPagamento(idPagamento);
      if (!mounted) return;
      mostrarSucesso(
        context,
        'Recebimento confirmado · +${pagamento.valor.round()} pontos '
        'para ${a.cliente?.nome ?? 'o cliente'}',
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, 'Erro ao confirmar o pagamento: $e');
    }
  }

  List<Agendamento> get _proximos {
    final agora = DateTime.now();
    return _agendamentos
        .where(
          (a) =>
              a.status == StatusAgendamento.confirmado &&
              a.data.isAfter(agora),
        )
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  List<Agendamento> get _historico {
    final agora = DateTime.now();
    return _agendamentos
        .where(
          (a) =>
              a.status != StatusAgendamento.confirmado ||
              !a.data.isAfter(agora),
        )
        .toList()
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
        content: Text(
          'O horário voltará a ficar disponível para outros clientes.',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
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

    await DatabaseService.instance.atualizarStatusAgendamento(
      a.id!,
      StatusAgendamento.cancelado,
    );

    if (!mounted) return;
    mostrarInfo(context, 'Agendamento cancelado');
    await _carregar();
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
            tabs: const [Tab(text: 'Próximos'), Tab(text: 'Histórico')],
          ),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : TabBarView(
                    controller: _abas,
                    children: [
                      _lista(_proximos, podeCancelar: true),
                      _lista(_historico, podeCancelar: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Agendamento> itens, {required bool podeCancelar}) {
    if (itens.isEmpty) {
      return EstadoVazio(
        icone: podeCancelar ? '📅' : '🗂️',
        titulo: podeCancelar
            ? (_modoBarbeiro
                  ? 'Nenhum atendimento marcado'
                  : 'Nenhum agendamento futuro')
            : 'Histórico vazio',
        descricao: podeCancelar
            ? (_modoBarbeiro
                  ? 'Quando um cliente agendar com você, aparece aqui.'
                  : 'Agende um horário na aba de serviços.')
            : 'Atendimentos concluídos ou cancelados aparecem aqui.',
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
        itemBuilder: (_, i) => _card(itens[i], podeCancelar: podeCancelar),
      ),
    );
  }

  Widget _card(Agendamento a, {required bool podeCancelar}) {
    final corStatus = switch (a.status) {
      StatusAgendamento.confirmado => AppColors.green,
      StatusAgendamento.cancelado => AppColors.red,
      StatusAgendamento.finalizado => AppColors.gold,
    };

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
              GoldBadge(texto: a.status.label, cor: corStatus),
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
            formatarReal(a.servico?.preco ?? 0),
          ),
          const SizedBox(height: 10),
          _statusPagamento(a),
          if (podeCancelar) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancelar(a),
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.red,
                ),
                label: Text(
                  'Cancelar agendamento',
                  style: AppTheme.sans(size: 12, color: AppColors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
    final p = _pagamentos[a.id];

    if (p == null) {
      return Row(
        children: [
          const Icon(Icons.help_outline, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Text(
            'Sem pagamento registrado',
            style: AppTheme.sans(size: 12, color: AppColors.muted),
          ),
        ],
      );
    }

    if (p.confirmado) {
      return Row(
        children: [
          const Icon(Icons.verified, size: 15, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pago via ${p.metodo}'
              '${p.cartaoFinal != null ? ' ····${p.cartaoFinal}' : ''}',
              style: AppTheme.sans(size: 12, color: AppColors.green),
            ),
          ),
        ],
      );
    }

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
              _modoBarbeiro
                  ? 'Pagamento pendente — confirme ao receber'
                  : 'Pague no balcão no dia do atendimento. Os '
                        '${p.valor.round()} pontos entram após a confirmação.',
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
        Text(texto, style: AppTheme.sans(size: 13, color: AppColors.muted)),
      ],
    );
  }
}
