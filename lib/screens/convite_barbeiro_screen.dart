import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// "Tenho um convite de barbeiro" (`/convite-barbeiro`, regra de negócio
/// 10). Primeiro o barbeiro digita o código que o administrador enviou;
/// depois cria a conta com e-mail, telefone e senha e já entra.
class ConviteBarbeiroScreen extends StatefulWidget {
  const ConviteBarbeiroScreen({super.key});

  @override
  State<ConviteBarbeiroScreen> createState() => _ConviteBarbeiroScreenState();
}

class _ConviteBarbeiroScreenState extends State<ConviteBarbeiroScreen> {
  final _codigoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmacaoCtrl = TextEditingController();

  /// O convite do código digitado, depois de conferido.
  ConviteBarbeiro? _convite;
  bool _ocultarSenha = true;
  bool _carregando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _conferir() async {
    setState(() => _carregando = true);
    final r = await AuthService.instance.conferirConvite(_codigoCtrl.text);
    if (!mounted) return;
    setState(() {
      _carregando = false;
      _convite = r.convite;
    });
    if (r.convite == null) {
      mostrarErro(context, r.erro ?? 'Não foi possível conferir o convite');
    }
  }

  Future<void> _criarConta() async {
    if (_senhaCtrl.text != _confirmacaoCtrl.text) {
      mostrarErro(context, 'A confirmação não confere com a senha');
      return;
    }
    setState(() => _carregando = true);
    final r = await AuthService.instance.aceitarConvite(
      codigo: _codigoCtrl.text,
      email: _emailCtrl.text,
      telefone: _telefoneCtrl.text,
      senha: _senhaCtrl.text,
    );
    if (!mounted) return;
    if (!r.sucesso) {
      setState(() => _carregando = false);
      mostrarErro(context, r.erro ?? 'Não foi possível criar a conta');
      return;
    }
    mostrarSucesso(context, 'Conta criada! Bem-vindo à equipe');
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AuthService.instance.rotaInicial, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Convite de barbeiro'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: _convite == null ? _etapaCodigo() : _etapaConta(_convite!),
      ),
    );
  }

  Widget _etapaCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: IconeCirculo(
            icone: Icons.mark_email_read_outlined,
            tamanho: 72,
            destaque: true,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Entrar na equipe',
          textAlign: TextAlign.center,
          style: AppTheme.titulo(size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          'Digite o código do convite que o administrador da barbearia '
          'enviou para você.',
          textAlign: TextAlign.center,
          style: AppTheme.texto(size: 13, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 28),
        _campo(
          rotulo: 'Código do convite',
          controller: _codigoCtrl,
          hint: 'ABCD-EFGH',
          icone: Icons.vpn_key_outlined,
          formatters: [CodigoConviteInputFormatter()],
          maiusculas: true,
          aoEnviar: _conferir,
        ),
        const SizedBox(height: 8),
        BotaoPrincipal(
          texto: _carregando ? 'Conferindo...' : 'Continuar',
          onPressed: _carregando ? null : _conferir,
        ),
      ],
    );
  }

  Widget _etapaConta(ConviteBarbeiro c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Cartao(
          child: Row(
            children: [
              AvatarIniciais(texto: c.iniciais, tamanho: 46, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convite para ${c.nome}',
                      style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.especialidade,
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Crie a sua conta. Com o e-mail e a senha, você entra no app e vê a '
          'sua agenda.',
          style: AppTheme.texto(size: 13, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 24),
        _campo(
          rotulo: 'E-mail',
          controller: _emailCtrl,
          hint: 'seu@email.com',
          icone: Icons.mail_outline,
          tipo: TextInputType.emailAddress,
        ),
        _campo(
          rotulo: 'Telefone',
          controller: _telefoneCtrl,
          hint: '(67) 99999-0000',
          icone: Icons.phone_outlined,
          tipo: TextInputType.phone,
          formatters: [TelefoneInputFormatter()],
        ),
        _campo(
          rotulo: 'Senha (mín. 6 caracteres)',
          controller: _senhaCtrl,
          hint: '••••••••',
          icone: Icons.lock_outline,
          obscuro: _ocultarSenha,
          sufixo: IconButton(
            tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
            icon: Icon(
              _ocultarSenha
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.muted,
              size: 20,
            ),
            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
          ),
        ),
        _campo(
          rotulo: 'Confirme a senha',
          controller: _confirmacaoCtrl,
          hint: '••••••••',
          icone: Icons.lock_outline,
          obscuro: _ocultarSenha,
        ),
        const SizedBox(height: 8),
        BotaoPrincipal(
          texto: _carregando ? 'Criando a conta...' : 'Criar conta e entrar',
          onPressed: _carregando ? null : _criarConta,
        ),
      ],
    );
  }

  Widget _campo({
    required String rotulo,
    required TextEditingController controller,
    required String hint,
    required IconData icone,
    TextInputType tipo = TextInputType.text,
    bool obscuro = false,
    bool maiusculas = false,
    Widget? sufixo,
    List<TextInputFormatter>? formatters,
    VoidCallback? aoEnviar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotuloCampo(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: obscuro,
            inputFormatters: formatters,
            autocorrect: false,
            textCapitalization: maiusculas
                ? TextCapitalization.characters
                : TextCapitalization.none,
            onSubmitted: aoEnviar == null ? null : (_) => aoEnviar(),
            style: AppTheme.texto(size: 14),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icone, color: AppColors.muted, size: 20),
              suffixIcon: sufixo,
            ),
          ),
        ],
      ),
    );
  }
}
