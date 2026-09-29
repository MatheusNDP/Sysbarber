import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Perfil do usuário logado (`/perfil`).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int _totalAgendamentos = 0;
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
    if (usuario?.id == null) {
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
      final agendamentos = await db.listarAgendamentosCliente(usuario!.id!);
      final pontos = await db.obterPontos(usuario.id!);
      if (!mounted) return;
      setState(() {
        _totalAgendamentos = agendamentos.length;
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
      builder: (_) => const _EditarDadosDialog(),
    );
    if (salvou != true || !mounted) return;
    setState(() {}); // o nome e o telefone exibidos vêm da sessão
    mostrarSucesso(context, 'Dados atualizados');
  }

  Future<void> _alterarSenha() async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => const _AlterarSenhaDialog(),
    );
    if (salvou != true || !mounted) return;
    mostrarSucesso(context, 'Senha alterada');
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Sair da conta?', style: AppTheme.serif(size: 18)),
        content: Text(
          'Você precisará entrar novamente para acessar seus agendamentos.',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'CANCELAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'SAIR',
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

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioAtual;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'PERFIL'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    children: [
                      Center(
                        child: GoldAvatar(
                          texto: usuario?.iniciais ?? '?',
                          tamanho: 92,
                          large: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        usuario?.nome ?? 'Visitante',
                        textAlign: TextAlign.center,
                        style: AppTheme.serif(size: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.email ?? '',
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(size: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 32),
                      _item(
                        Icons.phone_outlined,
                        'Telefone',
                        usuario?.telefone ?? '-',
                      ),
                      _item(
                        Icons.edit_outlined,
                        'Editar dados',
                        'Nome e telefone',
                        onTap: _editarDados,
                      ),
                      _item(
                        Icons.lock_outline,
                        'Alterar senha',
                        'Exige a senha atual',
                        onTap: _alterarSenha,
                      ),
                      _item(
                        Icons.calendar_today_outlined,
                        'Meus agendamentos',
                        '$_totalAgendamentos no total',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/agendamentos'),
                      ),
                      _item(
                        Icons.star_outline,
                        'Pontos de fidelidade',
                        '$_pontos pts',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/fidelidade'),
                      ),
                      if (AuthService.instance.podeAdministrar)
                        _item(
                          Icons.settings_outlined,
                          'Área administrativa',
                          'Painel de controle',
                          onTap: () =>
                              Navigator.of(context).pushNamed('/admin'),
                        ),
                      const SizedBox(height: 28),
                      GoldOutlineButton(texto: 'SAIR', onPressed: _sair),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    IconData icone,
    String rotulo,
    String valor, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icone, color: AppColors.gold, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    valor,
                    style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.gold),
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
    backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    title: Text(titulo, style: AppTheme.serif(size: 18)),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: campos),
    ),
    actions: [
      TextButton(
        onPressed: salvando ? null : () => Navigator.of(context).pop(false),
        child: Text(
          'CANCELAR',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
        ),
      ),
      TextButton(
        onPressed: salvando ? null : onSalvar,
        child: Text(
          salvando ? 'SALVANDO...' : 'SALVAR',
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
      style: AppTheme.sans(size: 14),
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
