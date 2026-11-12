import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../services/formatters.dart';
import '../services/fotos.dart';
import '../services/suporte.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Perfil de quem está logado (`/perfil`). O cliente vê a foto e os pontos;
/// o administrador, os dados e o Suporte; o barbeiro, a foto, os dados, a
/// troca de senha e sair (sem Suporte).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    this.abrirLink = abrirForaDoApp,
    this.escolherFoto = escolherFotoDoAparelho,
  });

  /// Abre o WhatsApp e o e-mail do suporte (os testes trocam por um falso).
  final AbrirLink abrirLink;

  /// Abre a câmera ou a galeria para a foto do cliente ou do barbeiro (os
  /// testes trocam por uma falsa).
  final EscolherFoto escolherFoto;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int _pontos = 0;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final usuario = AuthService.instance.usuarioAtual;
    // Só o cliente tem pontos para mostrar.
    if (!AuthService.instance.ehCliente || usuario?.id == null) {
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
      final pontos = await DatabaseService.instance.obterPontos(usuario!.id!);
      if (!mounted) return;
      setState(() {
        _pontos = pontos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar o perfil');
      });
    }
  }

  Future<void> _editarDados() async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => AuthService.instance.ehBarbeiro
          ? const _EditarContatoBarbeiroDialog()
          : const _EditarDadosDialog(),
    );
    if (salvou != true || !mounted) return;
    setState(() {}); // o nome e o telefone exibidos vêm da sessão
    mostrarSucesso(context, 'Dados atualizados');
  }

  /// Pede a senha, explica o que se perde e, confirmado, exclui a conta e
  /// volta à abertura do app.
  Future<void> _excluirConta() async {
    final excluiu = await showDialog<bool>(
      context: context,
      builder: (_) => _ExcluirContaDialog(pontos: _pontos),
    );
    if (excluiu != true || !mounted) return;
    mostrarInfo(context, 'Conta excluída');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _alterarSenha() async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => const _AlterarSenhaDialog(),
    );
    if (salvou != true || !mounted) return;
    mostrarSucesso(context, 'Senha alterada');
  }

  /// O cliente e o barbeiro põem, trocam ou removem a própria foto (regras
  /// de negócio 22 e 23): o sheet pergunta se a foto vem da câmera ou da
  /// galeria.
  Future<void> _alterarFoto() async {
    final auth = AuthService.instance;
    final barbeiro = auth.barbeiroAtual;
    final opcao = await showModalBottomSheet<_OpcaoDaFoto>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FotoSheet(
        temFoto: (barbeiro?.foto ?? auth.usuarioAtual?.foto) != null,
        explicacao: barbeiro != null
            ? 'Os clientes veem a sua foto na hora de escolher o '
                  'profissional.'
            : 'A sua foto aparece aqui no Perfil e no Início.',
      ),
    );
    if (opcao == null || !mounted) return;

    Uint8List? foto;
    if (opcao != _OpcaoDaFoto.remover) {
      final camera = opcao == _OpcaoDaFoto.camera;
      try {
        foto = await widget.escolherFoto(
          camera ? OrigemDaFoto.camera : OrigemDaFoto.galeria,
        );
      } catch (e) {
        if (!mounted) return;
        mostrarErro(
          context,
          mensagemDeErro(
            e,
            camera
                ? 'Não foi possível abrir a câmera'
                : 'Não foi possível abrir a galeria',
          ),
        );
        return;
      }
      // Desistiu na câmera ou na galeria: fica a foto de antes.
      if (foto == null || !mounted) return;
    }

    final r = barbeiro != null
        ? await auth.atualizarFotoBarbeiro(foto)
        : await auth.atualizarFotoCliente(foto);
    if (!mounted) return;
    if (!r.sucesso) {
      mostrarErro(context, r.erro!);
      return;
    }
    setState(() {}); // a foto exibida vem da sessão
    mostrarSucesso(context, foto == null ? 'Foto removida' : 'Foto atualizada');
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sair da conta?', style: AppTheme.titulo(size: 18)),
        content: Text(
          'Você precisará entrar novamente para usar o app.',
          style: AppTheme.texto(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sair',
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

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  /// Mensagem pronta ao suporte, com o nome e o perfil de quem pede ajuda.
  String get _mensagemAoSuporte => mensagemAoSuporte(
    nome: AuthService.instance.usuarioAtual?.nome ?? 'Visitante',
    administrador: AuthService.instance.podeAdministrar,
  );

  Future<void> _whatsappDoSuporte() async {
    final abriu = await widget.abrirLink(linkDoWhatsApp(_mensagemAoSuporte));
    if (abriu || !mounted) return;
    mostrarErro(
      context,
      'Não foi possível abrir o WhatsApp. Tente falar com o suporte por '
      'e-mail.',
    );
  }

  Future<void> _emailDoSuporte() async {
    final abriu = await widget.abrirLink(linkDoEmail(_mensagemAoSuporte));
    if (abriu || !mounted) return;
    mostrarErro(
      context,
      'Não há app de e-mail neste aparelho. Escreva para '
      '${ContatoSuporte.email} ou use o WhatsApp.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final usuario = auth.usuarioAtual;
    final barbeiro = auth.barbeiroAtual;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Perfil'),
      body: Column(
        children: [
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                : ListView(
                    // Embaixo, o espaço da barra de navegação quando a tela é uma aba.
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      28 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      // O cliente e o barbeiro põem a própria foto (regras
                      // de negócio 22 e 23); o administrador tem as
                      // iniciais.
                      Center(
                        child: barbeiro != null
                            ? _fotoEditavel(barbeiro.iniciais, barbeiro.foto)
                            : auth.ehCliente && usuario != null
                            ? _fotoEditavel(usuario.iniciais, usuario.foto)
                            : AvatarIniciais(
                                texto: usuario?.iniciais ?? '?',
                                tamanho: 92,
                                large: true,
                              ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        auth.nomeLogado ?? 'Visitante',
                        textAlign: TextAlign.center,
                        style: AppTheme.titulo(size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.email ?? barbeiro?.email ?? '',
                        textAlign: TextAlign.center,
                        style: AppTheme.texto(size: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      if (auth.ehCliente) ...[
                        _cartaoDosPontos(),
                        const SizedBox(height: 24),
                      ],
                      // Nome e especialidade do barbeiro são do administrador,
                      // em Gerenciar Barbeiros; o e-mail e o telefone, dele,
                      // no Editar dados.
                      if (barbeiro != null)
                        _item(
                          Icons.content_cut_rounded,
                          'Especialidade',
                          barbeiro.especialidade,
                        ),
                      _acao(Icons.edit_outlined, 'Editar dados', _editarDados),
                      _acao(
                        Icons.lock_outline_rounded,
                        'Alterar senha',
                        _alterarSenha,
                      ),
                      _acao(
                        Icons.description_outlined,
                        'Termos de uso e política de privacidade',
                        () => Navigator.of(context)
                            .pushNamed(AuthService.rotaTermos),
                      ),
                      const SizedBox(height: 28),
                      BotaoSecundario(
                        texto: 'Sair',
                        icone: Icons.logout_rounded,
                        onPressed: _sair,
                      ),
                      // Só o cliente exclui a própria conta (regra de
                      // negócio 18).
                      if (auth.ehCliente) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _excluirConta,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              'Excluir minha conta',
                              style: AppTheme.texto(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.red,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ),
                      ],
                      // O barbeiro não tem Suporte: ele fala com o
                      // administrador.
                      if (barbeiro == null) ...[
                        const SizedBox(height: 36),
                        _suporte(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Seção "Suporte", no fim da tela: fala com o suporte do SysBarber pelo
  /// WhatsApp ou por e-mail.
  Widget _suporte() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSecao('Suporte'),
        const SizedBox(height: 6),
        Text(
          'Dúvidas ou problemas com o app? Fale com o suporte do SysBarber.',
          style: AppTheme.texto(size: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: BotaoSecundario(
                texto: 'WhatsApp',
                icone: Icons.chat_outlined,
                onPressed: _whatsappDoSuporte,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BotaoSecundario(
                texto: 'E-mail',
                icone: Icons.email_outlined,
                onPressed: _emailDoSuporte,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Os pontos do cliente; tocar abre a Fidelidade.
  Widget _cartaoDosPontos() {
    return Cartao(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Semantics(
        button: true,
        label: 'Pontos: $_pontos',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed('/fidelidade'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                const Icon(
                  Icons.star_outline_rounded,
                  color: AppColors.amarelo,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pontos',
                  style: AppTheme.texto(size: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text('$_pontos', style: AppTheme.titulo(size: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A foto do cliente ou do barbeiro (ou as iniciais, sem ela), com o selo
  /// da câmera: tocar abre as opções da foto. O administrador não tem foto.
  Widget _fotoEditavel(String iniciais, Uint8List? foto) {
    return Tooltip(
      message: 'Alterar foto',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _alterarFoto,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarIniciais(
                texto: iniciais,
                foto: foto,
                tamanho: 92,
                large: true,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amarelo,
                    // O contorno da cor do fundo separa o selo do avatar.
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 15,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de uma ação do Perfil, com um texto só.
  Widget _acao(IconData icone, String texto, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Cartao(
        onTap: onTap,
        child: Row(
          children: [
            IconeCirculo(icone: icone, tamanho: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texto,
                style: AppTheme.texto(size: 14, weight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// Card de um dado, com o nome dele e o valor.
  Widget _item(IconData icone, String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Cartao(
        child: Row(
          children: [
            IconeCirculo(icone: icone, tamanho: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: AppTheme.texto(size: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    valor,
                    style: AppTheme.texto(size: 14, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FOTO DE PERFIL (CLIENTE E BARBEIRO)
// ---------------------------------------------------------------------------

enum _OpcaoDaFoto { camera, galeria, remover }

/// Opções da foto do cliente ou do barbeiro: tirar com a câmera, escolher
/// da galeria e, se já tem uma, remover.
class _FotoSheet extends StatelessWidget {
  final bool temFoto;

  /// Quem vê a foto, embaixo do título.
  final String explicacao;

  const _FotoSheet({required this.temFoto, required this.explicacao});

  @override
  Widget build(BuildContext context) {
    Widget opcao(
      IconData icone,
      String texto,
      _OpcaoDaFoto valor, {
      Color? cor,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Cartao(
          onTap: () => Navigator.of(context).pop(valor),
          child: Row(
            children: [
              IconeCirculo(icone: icone, tamanho: 42, cor: cor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  texto,
                  style: AppTheme.texto(
                    size: 14,
                    weight: FontWeight.w600,
                    color: cor ?? AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Foto de perfil', style: AppTheme.titulo(size: 20)),
            const SizedBox(height: 6),
            Text(
              explicacao,
              style: AppTheme.texto(
                size: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            opcao(
              Icons.photo_camera_outlined,
              'Tirar foto',
              _OpcaoDaFoto.camera,
            ),
            opcao(
              Icons.photo_library_outlined,
              'Escolher da galeria',
              _OpcaoDaFoto.galeria,
            ),
            if (temFoto)
              opcao(
                Icons.delete_outline_rounded,
                'Remover foto',
                _OpcaoDaFoto.remover,
                cor: AppColors.red,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DIÁLOGOS
// ---------------------------------------------------------------------------

/// Moldura comum aos dois diálogos do perfil.
AlertDialog _dialogo({
  required BuildContext context,
  required String titulo,
  required List<Widget> campos,
  required bool salvando,
  required VoidCallback onSalvar,
}) {
  return AlertDialog(
    title: Text(titulo, style: AppTheme.titulo(size: 18)),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: campos),
    ),
    actions: [
      TextButton(
        onPressed: salvando ? null : () => Navigator.of(context).pop(false),
        child: Text(
          'Cancelar',
          style: AppTheme.texto(size: 13, color: AppColors.muted),
        ),
      ),
      TextButton(
        onPressed: salvando ? null : onSalvar,
        child: Text(
          salvando ? 'Salvando...' : 'Salvar',
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
  bool obscuro = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: teclado,
      inputFormatters: formatters,
      obscureText: obscuro,
      style: AppTheme.texto(size: 14),
      decoration: InputDecoration(labelText: rotulo),
    ),
  );
}

class _EditarDadosDialog extends StatefulWidget {
  const _EditarDadosDialog();

  @override
  State<_EditarDadosDialog> createState() => _EditarDadosDialogState();
}

class _EditarDadosDialogState extends State<_EditarDadosDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final usuario = AuthService.instance.usuarioAtual;
    _nome = TextEditingController(text: usuario?.nome ?? '');
    _telefone = TextEditingController(text: usuario?.telefone ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final r = await AuthService.instance.atualizarPerfil(
      nome: _nome.text,
      telefone: _telefone.text,
    );
    if (!mounted) return;
    if (r.sucesso) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _salvando = false);
      mostrarErro(context, r.erro ?? 'Não foi possível salvar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _dialogo(
      context: context,
      titulo: 'Editar dados',
      salvando: _salvando,
      onSalvar: _salvar,
      campos: [
        _campo(_nome, 'Nome completo', teclado: TextInputType.name),
        _campo(
          _telefone,
          'Telefone',
          teclado: TextInputType.phone,
          formatters: [TelefoneInputFormatter()],
        ),
      ],
    );
  }
}

/// O barbeiro muda o próprio e-mail e telefone (regra de negócio 10). O
/// nome e a especialidade ficam com o administrador.
class _EditarContatoBarbeiroDialog extends StatefulWidget {
  const _EditarContatoBarbeiroDialog();

  @override
  State<_EditarContatoBarbeiroDialog> createState() =>
      _EditarContatoBarbeiroDialogState();
}

class _EditarContatoBarbeiroDialogState
    extends State<_EditarContatoBarbeiroDialog> {
  late final TextEditingController _email;
  late final TextEditingController _telefone;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final barbeiro = AuthService.instance.barbeiroAtual;
    _email = TextEditingController(text: barbeiro?.email ?? '');
    _telefone = TextEditingController(text: barbeiro?.telefone ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final r = await AuthService.instance.atualizarContatoBarbeiro(
      email: _email.text,
      telefone: _telefone.text,
    );
    if (!mounted) return;
    if (r.sucesso) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _salvando = false);
      mostrarErro(context, r.erro ?? 'Não foi possível salvar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _dialogo(
      context: context,
      titulo: 'Editar dados',
      salvando: _salvando,
      onSalvar: _salvar,
      campos: [
        _campo(_email, 'E-mail', teclado: TextInputType.emailAddress),
        _campo(
          _telefone,
          'Telefone',
          teclado: TextInputType.phone,
          formatters: [TelefoneInputFormatter()],
        ),
      ],
    );
  }
}

/// Confirmação da exclusão da conta: diz o que se perde e pede a senha
/// (regra de negócio 18). O banco é quem recusa com agendamento em aberto ou
/// valor pendente, e a mensagem aparece aqui.
class _ExcluirContaDialog extends StatefulWidget {
  final int pontos;

  const _ExcluirContaDialog({required this.pontos});

  @override
  State<_ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends State<_ExcluirContaDialog> {
  final _senha = TextEditingController();
  bool _excluindo = false;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    setState(() => _excluindo = true);
    final r = await AuthService.instance.excluirConta(_senha.text);
    if (!mounted) return;
    if (r.sucesso) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _excluindo = false);
      mostrarErro(context, r.erro ?? 'Não foi possível excluir a conta');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pontos = widget.pontos == 1 ? '1 ponto' : '${widget.pontos} pontos';
    final estilo = AppTheme.texto(
      size: 13,
      color: AppColors.muted,
      height: 1.4,
    );
    return AlertDialog(
      title: Text('Excluir a sua conta?', style: AppTheme.titulo(size: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ao excluir a conta:', style: estilo),
            const SizedBox(height: 6),
            ItemDeLista(
              'seu nome, e-mail, telefone e senha são apagados;',
              estilo: estilo,
            ),
            if (widget.pontos > 0)
              ItemDeLista('seus $pontos são perdidos;', estilo: estilo),
            ItemDeLista(
              'os atendimentos que já aconteceram ficam só nos relatórios da '
              'barbearia, sem o seu nome.',
              estilo: estilo,
            ),
            const SizedBox(height: 10),
            Text(
              'Não dá para desfazer. Com agendamento em aberto ou valor '
              'pendente com a barbearia, resolva isso antes.',
              style: estilo,
            ),
            const SizedBox(height: 16),
            _campo(_senha, 'Sua senha', obscuro: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _excluindo ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: AppTheme.texto(size: 13, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: _excluindo ? null : _excluir,
          child: Text(
            _excluindo ? 'Excluindo...' : 'Excluir conta',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.red,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlterarSenhaDialog extends StatefulWidget {
  const _AlterarSenhaDialog();

  @override
  State<_AlterarSenhaDialog> createState() => _AlterarSenhaDialogState();
}

class _AlterarSenhaDialogState extends State<_AlterarSenhaDialog> {
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nova.text != _confirmacao.text) {
      mostrarErro(context, 'A confirmação não confere com a nova senha');
      return;
    }
    setState(() => _salvando = true);
    final r = await AuthService.instance.alterarSenha(
      senhaAtual: _atual.text,
      novaSenha: _nova.text,
    );
    if (!mounted) return;
    if (r.sucesso) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _salvando = false);
      mostrarErro(context, r.erro ?? 'Não foi possível trocar a senha');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _dialogo(
      context: context,
      titulo: 'Alterar senha',
      salvando: _salvando,
      onSalvar: _salvar,
      campos: [
        _campo(_atual, 'Senha atual', obscuro: true),
        _campo(_nova, 'Nova senha (mín. 6 caracteres)', obscuro: true),
        _campo(_confirmacao, 'Confirme a nova senha', obscuro: true),
      ],
    );
  }
}
