import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
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
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }
    try {
      final lista = await _db.listarServicos();
      if (!mounted) return;
      setState(() {
        _servicos = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar os serviços');
      });
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
        title: Text('Excluir serviço?', style: AppTheme.titulo(size: 18)),
        content: Text(
          '"${s.nome}" será removido permanentemente.',
          style: AppTheme.texto(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Excluir',
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
      await _db.excluirServico(s.id!);
      if (!mounted) return;
      mostrarInfo(context, 'Serviço excluído');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao excluir'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarberAppBar(
        titulo: 'Serviços',
        acoes: [
          BotaoVidro(
            icone: Icons.add_rounded,
            dica: 'Novo serviço',
            corIcone: AppColors.amarelo,
            onPressed: () => _abrirFormulario(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                : _servicos.isEmpty
                ? const EstadoVazio(
                    icone: Icons.content_cut_rounded,
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
                      return Cartao(
                        onTap: () => _abrirFormulario(servico: s),
                        child: Row(
                          children: [
                            IconeCirculo(
                              icone: iconeDoServico(s.icone),
                              tamanho: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.nome,
                                    style: AppTheme.texto(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${formatarReal(s.preco)}  ·  '
                                    '${s.duracaoMinutos} min',
                                    style: AppTheme.texto(
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
                                Icons.delete_outline_rounded,
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

  /// Valor gravado na coluna `icone` (veja [iconesDeServico]).
  late String _icone;

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
    _icone = s?.icone ?? iconesDeServico.first.$1;
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _preco.dispose();
    _duracao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final descricao = _descricao.text.trim();
    final preco = moedaParaDouble(_preco.text);
    final duracao = int.tryParse(somenteDigitos(_duracao.text)) ?? 0;

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
        icone: _icone,
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
      mostrarErro(context, mensagemDeErro(e, 'Erro ao salvar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _editando ? 'Editar serviço' : 'Novo serviço',
        style: AppTheme.titulo(size: 18),
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
            _campo(
              _duracao,
              'Duração (minutos)',
              teclado: TextInputType.number,
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: RotuloCampo('Ícone'),
            ),
            const SizedBox(height: 10),
            _escolhaDeIcone(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: AppTheme.texto(size: 13, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(
            _salvando ? 'Salvando...' : 'Salvar',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
        ),
      ],
    );
  }

  /// Os ícones de [iconesDeServico], com o escolhido em amarelo.
  Widget _escolhaDeIcone() {
    return Wrap(
      spacing: 6,
      runSpacing: 10,
      children: [
        for (final (valor, icone, nome) in iconesDeServico)
          Semantics(
            button: true,
            selected: valor == _icone,
            label: 'Ícone $nome',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _icone = valor),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    IconeCirculo(
                      icone: icone,
                      tamanho: 44,
                      destaque: valor == _icone,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.texto(
                        size: 10,
                        color: valor == _icone
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
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
        style: AppTheme.texto(size: 14),
        decoration: InputDecoration(labelText: rotulo),
      ),
    );
  }
}
