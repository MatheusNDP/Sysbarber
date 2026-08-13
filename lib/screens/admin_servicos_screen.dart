import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// CRUD completo de serviços (`/admin` → Gerenciar Serviços).
class AdminServicosScreen extends StatefulWidget {
  const AdminServicosScreen({super.key});

  @override
  State<AdminServicosScreen> createState() => _AdminServicosScreenState();
}

class _AdminServicosScreenState extends State<AdminServicosScreen> {
  final _db = DatabaseService.instance;

  List<Servico> _servicos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _db.listarServicos();
      if (!mounted) return;
      setState(() {
        _servicos = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao carregar serviços: $e');
    }
  }

  Future<void> _abrirFormulario({Servico? servico}) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioServico(servico: servico),
    );
    if (salvou == true && mounted) await _carregar();
  }

  Future<void> _excluir(Servico s) async {
    if (s.id == null) return;

    // Mesmo motivo dos barbeiros: o INNER JOIN da listagem de agendamentos
    // faria os atendimentos sumirem do histórico do cliente.
    final vinculados = await _db.contarAgendamentosDoServico(s.id!);
    if (!mounted) return;

    if (vinculados > 0) {
      mostrarErro(
        context,
        '${s.nome} tem $vinculados agendamento(s) e não pode ser excluído',
      );
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Excluir serviço?', style: AppTheme.serif(size: 18)),
        content: Text(
          '"${s.nome}" será removido permanentemente.',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCELAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'EXCLUIR',
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
      await _db.excluirServico(s.id!);
      if (!mounted) return;
      mostrarInfo(context, 'Serviço excluído');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, 'Erro ao excluir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarberAppBar(
        titulo: 'SERVIÇOS',
        acoes: [
          IconButton(
            tooltip: 'Novo serviço',
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _abrirFormulario(),
          ),
        ],
      ),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _servicos.isEmpty
                ? const EstadoVazio(
                    icone: '💈',
                    titulo: 'Nenhum serviço',
                    descricao: 'Use o botão + para cadastrar o primeiro.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: _servicos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = _servicos[i];
                      return GoldCard(
                        onTap: () => _abrirFormulario(servico: s),
                        child: Row(
                          children: [
                            Text(s.icone, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.nome,
                                    style: AppTheme.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${formatarReal(s.preco)}  ·  '
                                    '${s.duracaoMinutos} min',
                                    style: AppTheme.sans(
                                      size: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.red,
                                size: 20,
                              ),
                              onPressed: () => _excluir(s),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de cadastro/edição de serviço.
class _FormularioServico extends StatefulWidget {
  final Servico? servico;

  const _FormularioServico({this.servico});

  @override
  State<_FormularioServico> createState() => _FormularioServicoState();
}

class _FormularioServicoState extends State<_FormularioServico> {
  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _preco;
  late final TextEditingController _duracao;
  late final TextEditingController _icone;

  bool _salvando = false;

  bool get _editando => widget.servico != null;

  @override
  void initState() {
    super.initState();
    final s = widget.servico;
    _nome = TextEditingController(text: s?.nome ?? '');
    _descricao = TextEditingController(text: s?.descricao ?? '');
    _preco = TextEditingController(
      text: s == null ? '' : formatarMoedaDeCentavos((s.preco * 100).round()),
    );
    _duracao = TextEditingController(
      text: s == null ? '' : '${s.duracaoMinutos}',
    );
    _icone = TextEditingController(text: s?.icone ?? '💈');
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _preco.dispose();
    _duracao.dispose();
    _icone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final descricao = _descricao.text.trim();
    final preco = moedaParaDouble(_preco.text);
    final duracao = int.tryParse(somenteDigitos(_duracao.text)) ?? 0;
    final icone = _icone.text.trim().isEmpty ? '💈' : _icone.text.trim();

    if (nome.length < 3) {
      mostrarErro(context, 'Nome deve ter pelo menos 3 caracteres');
      return;
    }
    if (descricao.isEmpty) {
      mostrarErro(context, 'Informe a descrição do serviço');
      return;
    }
    if (preco <= 0) {
      mostrarErro(context, 'Preço deve ser maior que zero');
      return;
    }
    if (duracao <= 0) {
      mostrarErro(context, 'Duração deve ser maior que zero');
      return;
    }

    setState(() => _salvando = true);

    try {
      final db = DatabaseService.instance;
      final registro = Servico(
        id: widget.servico?.id,
        nome: nome,
        descricao: descricao,
        preco: preco,
        duracaoMinutos: duracao,
        icone: icone,
      );

      if (_editando) {
        await db.atualizarServico(registro);
      } else {
        await db.cadastrarServico(registro);
      }

      if (!mounted) return;
      mostrarSucesso(
        context,
        _editando ? 'Serviço atualizado' : 'Serviço cadastrado',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, 'Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        _editando ? 'Editar serviço' : 'Novo serviço',
        style: AppTheme.serif(size: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(_nome, 'Nome', capitalizar: true),
            _campo(_descricao, 'Descrição', capitalizar: true),
            _campo(
              _preco,
              'Preço (R\$)',
              teclado: TextInputType.number,
              formatters: [MoedaInputFormatter()],
            ),
            _campo(_duracao, 'Duração (minutos)', teclado: TextInputType.number),
            _campo(_icone, 'Ícone (emoji)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'CANCELAR',
            style: AppTheme.sans(size: 13, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(
            _salvando ? 'SALVANDO...' : 'SALVAR',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controller,
    String rotulo, {
    TextInputType teclado = TextInputType.text,
    List<dynamic>? formatters,
    bool capitalizar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        textCapitalization: capitalizar
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        inputFormatters: formatters?.cast(),
        style: AppTheme.sans(size: 14),
        decoration: InputDecoration(labelText: rotulo),
      ),
    );
  }
}
