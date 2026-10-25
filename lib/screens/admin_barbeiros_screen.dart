import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Abre o menu de compartilhar do aparelho com [texto].
typedef Compartilhar = Future<void> Function(String texto);

Future<void> _compartilharPeloAparelho(String texto) async {
  await SharePlus.instance.share(ShareParams(text: texto));
}

/// Equipe da barbearia (`/admin` → Gerenciar Barbeiros).
///
/// O administrador convida o barbeiro (regra de negócio 10): informa nome,
/// especialidade e salário e envia o código do convite, com o qual o
/// barbeiro cria a própria conta. Enquanto o convite não é usado, ele
/// aparece só aqui, em "Convites pendentes".
class AdminBarbeirosScreen extends StatefulWidget {
  /// Quem abre o menu de compartilhar; os testes trocam por um falso.
  final Compartilhar compartilhar;

  const AdminBarbeirosScreen({
    super.key,
    this.compartilhar = _compartilharPeloAparelho,
  });

  @override
  State<AdminBarbeirosScreen> createState() => _AdminBarbeirosScreenState();
}

/// O que o administrador escolheu no formulário de edição.
enum _ResultadoEdicao { salvou, liberarSenha }

class _AdminBarbeirosScreenState extends State<AdminBarbeirosScreen> {
  final _db = DatabaseService.instance;

  List<Barbeiro> _barbeiros = [];
  List<ConviteBarbeiro> _convites = [];
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
      final barbeiros = await _db.listarBarbeiros();
      final convites = await _db.listarConvitesBarbeiro();
      if (!mounted) return;
      setState(() {
        _barbeiros = barbeiros;
        _convites = convites;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar os barbeiros');
      });
    }
  }

  Future<void> _abrirSheet({
    ({ConviteBarbeiro convite, String codigo})? gerado,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ConviteSheet(gerado: gerado, compartilhar: widget.compartilhar),
    );
    // O convite já foi gravado ao gerar o código: recarrega mesmo se o sheet
    // foi fechado pelo voltar ou por um toque fora, sem "Concluir".
    if (mounted) await _carregar();
  }

  /// Outro código para o convite: o anterior deixa de valer.
  Future<void> _novoCodigo(ConviteBarbeiro c) async {
    final confirmou = await _confirmar(
      titulo: 'Gerar outro código?',
      texto:
          'O código anterior do convite de ${c.nome} deixa de valer, e o '
          'novo vale por ${DatabaseService.validadeConviteBarbeiro.inDays} '
          'dias.',
      acao: 'Gerar',
    );
    if (!confirmou || !mounted) return;
    try {
      final gerado = await _db.gerarNovoCodigoDoConvite(c.id!);
      if (!mounted) return;
      await _abrirSheet(gerado: gerado);
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao gerar o código'));
    }
  }

  Future<void> _cancelarConvite(ConviteBarbeiro c) async {
    final confirmou = await _confirmar(
      titulo: 'Cancelar o convite?',
      texto: 'O código enviado a ${c.nome} deixa de valer.',
      acao: 'Cancelar convite',
      perigo: true,
    );
    if (!confirmou || !mounted) return;
    try {
      await _db.cancelarConviteBarbeiro(c.id!);
      if (!mounted) return;
      mostrarInfo(context, 'Convite cancelado');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao cancelar o convite'));
    }
  }

  Future<void> _editar(Barbeiro b) async {
    final resultado = await showDialog<_ResultadoEdicao>(
      context: context,
      builder: (_) => _FormularioBarbeiro(barbeiro: b),
    );
    if (!mounted) return;
    if (resultado == _ResultadoEdicao.salvou) {
      mostrarSucesso(context, 'Barbeiro atualizado');
      await _carregar();
    } else if (resultado == _ResultadoEdicao.liberarSenha) {
      await liberarNovaSenhaNoBalcao(
        context,
        nome: b.nome,
        email: b.email,
        quem: 'o barbeiro',
        horas: DatabaseService.validadeCodigoBarbearia.inHours,
        liberar: () => AuthService.instance.liberarNovaSenhaDoBarbeiro(b.id!),
      );
    }
  }

  /// Liga/desliga o profissional para novos agendamentos.
  Future<void> _alternarDisponibilidade(Barbeiro b) async {
    if (b.id == null) return;
    try {
      await _db.definirBarbeiroAtivo(b.id!, !b.ativo);
      if (!mounted) return;
      mostrarInfo(
        context,
        b.ativo
            ? '${b.nome} não receberá novos agendamentos'
            : '${b.nome} voltou a receber agendamentos',
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(
        context,
        mensagemDeErro(e, 'Erro ao alterar disponibilidade'),
      );
    }
  }

  Future<void> _excluir(Barbeiro b) async {
    if (b.id == null) return;

    // Excluir um barbeiro com agendamentos faria esses registros sumirem da
    // tela do cliente, porque a listagem usa INNER JOIN.
    final vinculados = await _db.contarAgendamentosDoBarbeiro(b.id!);
    if (!mounted) return;

    if (vinculados > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Não é possível excluir',
            style: AppTheme.titulo(size: 18),
          ),
          content: Text(
            '${b.nome} possui $vinculados agendamento(s) registrado(s). '
            'Excluí-lo faria esses atendimentos desaparecerem do histórico '
            'dos clientes.',
            style: AppTheme.texto(
              size: 13,
              color: AppColors.muted,
              height: 1.4,
            ),
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
      return;
    }

    final confirmou = await _confirmar(
      titulo: 'Excluir barbeiro?',
      texto: '"${b.nome}" será removido permanentemente da equipe.',
      acao: 'Excluir',
      perigo: true,
    );
    if (!confirmou) return;

    try {
      await _db.excluirBarbeiro(b.id!);
      if (!mounted) return;
      mostrarInfo(context, 'Barbeiro excluído');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, mensagemDeErro(e, 'Erro ao excluir'));
    }
  }

  Future<bool> _confirmar({
    required String titulo,
    required String texto,
    required String acao,
    bool perigo = false,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: AppTheme.titulo(size: 18)),
        content: Text(
          texto,
          style: AppTheme.texto(size: 13, color: AppColors.muted),
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
              acao,
              style: AppTheme.texto(
                size: 13,
                weight: FontWeight.w600,
                color: perigo ? AppColors.red : AppColors.amarelo,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmou == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarberAppBar(
        titulo: 'Barbeiros',
        acoes: [
          BotaoVidro(
            icone: Icons.add_rounded,
            dica: 'Convidar barbeiro',
            corIcone: AppColors.amarelo,
            onPressed: () => _abrirSheet(),
          ),
        ],
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amarelo),
            )
          : _erro != null
          ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
          : _barbeiros.isEmpty && _convites.isEmpty
          ? const EstadoVazio(
              icone: Icons.content_cut_rounded,
              titulo: 'Nenhum barbeiro',
              descricao: 'Use o botão + para convidar o primeiro.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                if (_convites.isNotEmpty) ...[
                  const TituloSecao('Convites pendentes'),
                  const SizedBox(height: 12),
                  for (final c in _convites) ...[
                    _cardConvite(c),
                    const SizedBox(height: 12),
                  ],
                  if (_barbeiros.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const TituloSecao('Equipe'),
                    const SizedBox(height: 12),
                  ],
                ],
                for (final b in _barbeiros) ...[
                  _card(b),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _cardConvite(ConviteBarbeiro c) {
    final validade = DateTime.parse(c.expiraEm);
    final vencido = c.vencido(DateTime.now());
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarIniciais(texto: c.iniciais, tamanho: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nome,
                      style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.especialidade,
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Etiqueta(
                      texto: vencido ? 'Convite vencido' : 'Convite pendente',
                      cor: vencido ? AppColors.red : AppColors.amarelo,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _linha(
            Icons.schedule_outlined,
            '${vencido ? 'Venceu' : 'Vale até'} ${formatarDataCurta(validade)} '
            'às ${formatarHora(validade)}',
          ),
          const SizedBox(height: 6),
          _linha(Icons.payments_outlined, formatarReal(c.salario)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              _acaoConvite(
                'Gerar outro código',
                Icons.refresh_rounded,
                AppColors.amarelo,
                () => _novoCodigo(c),
              ),
              _acaoConvite(
                'Cancelar convite',
                Icons.close_rounded,
                AppColors.red,
                () => _cancelarConvite(c),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acaoConvite(
    String texto,
    IconData icone,
    Color cor,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 18),
      label: Text(
        texto,
        style: AppTheme.texto(size: 13, weight: FontWeight.w600, color: cor),
      ),
      style: TextButton.styleFrom(
        foregroundColor: cor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _card(Barbeiro b) {
    return Cartao(
      onTap: () => _editar(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarIniciais(texto: b.iniciais, tamanho: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.nome,
                      style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      b.especialidade,
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                    if (!b.ativo) ...[
                      const SizedBox(height: 6),
                      const Etiqueta(
                        texto: 'Indisponível',
                        cor: AppColors.muted,
                      ),
                    ],
                  ],
                ),
              ),
              Tooltip(
                message: b.ativo
                    ? 'Marcar como indisponível'
                    : 'Marcar como disponível',
                child: Switch(
                  value: b.ativo,
                  onChanged: (_) => _alternarDisponibilidade(b),
                ),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.red,
                  size: 20,
                ),
                onPressed: () => _excluir(b),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _linha(Icons.phone_outlined, b.telefone.isEmpty ? '—' : b.telefone),
          const SizedBox(height: 6),
          _linha(Icons.mail_outline, b.email.isEmpty ? '—' : b.email),
          const SizedBox(height: 6),
          _linha(Icons.payments_outlined, formatarReal(b.salario)),
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String texto) {
    return Row(
      children: [
        Icon(icone, size: 15, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.texto(size: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CONVITE
// ---------------------------------------------------------------------------

/// Sheet do convite: primeiro o administrador informa nome, especialidade e
/// salário; depois vê o código e o compartilha. Com [gerado], já abre no
/// código (outro código para um convite pendente).
class _ConviteSheet extends StatefulWidget {
  final ({ConviteBarbeiro convite, String codigo})? gerado;
  final Compartilhar compartilhar;

  const _ConviteSheet({this.gerado, required this.compartilhar});

  @override
  State<_ConviteSheet> createState() => _ConviteSheetState();
}

class _ConviteSheetState extends State<_ConviteSheet> {
  final _nome = TextEditingController();
  final _especialidade = TextEditingController();
  final _salario = TextEditingController();

  ({ConviteBarbeiro convite, String codigo})? _gerado;
  bool _gerando = false;

  @override
  void initState() {
    super.initState();
    _gerado = widget.gerado;
  }

  @override
  void dispose() {
    _nome.dispose();
    _especialidade.dispose();
    _salario.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    setState(() => _gerando = true);
    try {
      final gerado = await DatabaseService.instance.criarConviteBarbeiro(
        nome: _nome.text,
        especialidade: _especialidade.text,
        salario: moedaParaDouble(_salario.text),
      );
      if (!mounted) return;
      setState(() {
        _gerado = gerado;
        _gerando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gerando = false);
      mostrarErro(context, mensagemDeErro(e, 'Erro ao gerar o convite'));
    }
  }

  String _validade(ConviteBarbeiro c) {
    final d = DateTime.parse(c.expiraEm);
    return '${formatarDataCurta(d)} às ${formatarHora(d)}';
  }

  /// Mensagem pronta para o administrador enviar ao barbeiro.
  String _mensagem(ConviteBarbeiro c, String codigo) {
    final primeiroNome = c.nome.split(' ').first;
    return 'Olá, $primeiroNome! Você foi convidado para a equipe da '
        'barbearia no SysBarber. No app, toque em Entrar e depois em '
        '"Tenho um convite de barbeiro" e digite o código '
        '${formatarCodigoConvite(codigo)}. Ele vale até ${_validade(c)}, '
        'uma vez só.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sobe junto com o teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: _gerado == null ? _formulario() : _codigo(_gerado!),
      ),
    );
  }

  Widget _formulario() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Convidar barbeiro', style: AppTheme.titulo(size: 20)),
        const SizedBox(height: 6),
        Text(
          'Informe o nome, a especialidade e o salário. O barbeiro recebe um '
          'código e cria a própria conta, com e-mail, telefone e senha.',
          style: AppTheme.texto(size: 13, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        _campo(_nome, 'Nome completo', capitalizar: true),
        _campo(_especialidade, 'Especialidade'),
        _campo(
          _salario,
          'Salário (R\$)',
          teclado: TextInputType.number,
          formatters: [MoedaInputFormatter()],
        ),
        const SizedBox(height: 8),
        BotaoPrincipal(
          texto: _gerando ? 'Gerando...' : 'Gerar convite',
          icone: Icons.send_outlined,
          onPressed: _gerando ? null : _gerar,
        ),
      ],
    );
  }

  Widget _codigo(({ConviteBarbeiro convite, String codigo}) g) {
    final c = g.convite;
    final codigo = formatarCodigoConvite(g.codigo);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Convite para ${c.nome}', style: AppTheme.titulo(size: 20)),
        const SizedBox(height: 6),
        Text(
          c.especialidade,
          style: AppTheme.texto(size: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            codigo,
            textAlign: TextAlign.center,
            style: AppTheme.texto(
              size: 30,
              weight: FontWeight.w700,
              color: AppColors.amarelo,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Vale até ${_validade(c)}, uma vez só. No app, o barbeiro toca em '
          'Entrar e em "Tenho um convite de barbeiro", digita este código e '
          'cria a conta.',
          style: AppTheme.texto(size: 13, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(
          'O código não aparece de novo. Se ele se perder, gere outro em '
          'Convites pendentes.',
          style: AppTheme.texto(size: 12, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        BotaoPrincipal(
          texto: 'Compartilhar',
          icone: Icons.share_outlined,
          onPressed: () => widget.compartilhar(_mensagem(c, g.codigo)),
        ),
        const SizedBox(height: 12),
        BotaoSecundario(
          texto: 'Copiar código',
          icone: Icons.copy_rounded,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: codigo));
            if (!mounted) return;
            mostrarInfo(context, 'Código copiado');
          },
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Concluir',
            style: AppTheme.texto(size: 14, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controller,
    String rotulo, {
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool capitalizar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        textCapitalization: capitalizar
            ? TextCapitalization.words
            : TextCapitalization.none,
        inputFormatters: formatters,
        style: AppTheme.texto(size: 14),
        decoration: InputDecoration(labelText: rotulo),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIÇÃO
// ---------------------------------------------------------------------------

/// Diálogo de edição: o administrador muda só nome, especialidade e salário
/// (regra de negócio 10). E-mail, telefone e senha são do barbeiro; quando
/// ele esquece a senha, o administrador libera uma nova.
class _FormularioBarbeiro extends StatefulWidget {
  final Barbeiro barbeiro;

  const _FormularioBarbeiro({required this.barbeiro});

  @override
  State<_FormularioBarbeiro> createState() => _FormularioBarbeiroState();
}

class _FormularioBarbeiroState extends State<_FormularioBarbeiro> {
  late final TextEditingController _nome;
  late final TextEditingController _especialidade;
  late final TextEditingController _salario;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final b = widget.barbeiro;
    _nome = TextEditingController(text: b.nome);
    _especialidade = TextEditingController(text: b.especialidade);
    _salario = TextEditingController(
      text: formatarMoedaDeCentavos((b.salario * 100).round()),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _especialidade.dispose();
    _salario.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await DatabaseService.instance.atualizarDadosDoBarbeiro(
        widget.barbeiro.id!,
        nome: _nome.text,
        especialidade: _especialidade.text,
        salario: moedaParaDouble(_salario.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(_ResultadoEdicao.salvou);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, mensagemDeErro(e, 'Erro ao salvar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar barbeiro', style: AppTheme.titulo(size: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(_nome, 'Nome completo', capitalizar: true),
            _campo(_especialidade, 'Especialidade'),
            _campo(
              _salario,
              'Salário (R\$)',
              teclado: TextInputType.number,
              formatters: [MoedaInputFormatter()],
            ),
            Text(
              'O e-mail, o telefone e a senha são do barbeiro: ele muda no '
              'Perfil. Se ele esqueceu a senha, libere uma nova.',
              style: AppTheme.texto(
                size: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _salvando
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(_ResultadoEdicao.liberarSenha),
                icon: const Icon(Icons.key_outlined, size: 18),
                label: Text(
                  'Liberar nova senha',
                  style: AppTheme.texto(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.amarelo,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amarelo,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
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

  Widget _campo(
    TextEditingController controller,
    String rotulo, {
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool capitalizar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        textCapitalization: capitalizar
            ? TextCapitalization.words
            : TextCapitalization.none,
        inputFormatters: formatters,
        style: AppTheme.texto(size: 14),
        decoration: InputDecoration(labelText: rotulo),
      ),
    );
  }
}
