import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/sms.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// "Esqueci minha senha" (`/recuperar-senha`, regra de negócio 16).
///
/// Em duas etapas: a pessoa informa o e-mail e o celular da conta e recebe
/// um código por SMS (simulado); com ele, cria uma senha nova e já entra.
///
/// Com [codigoDaBarbearia], a tela abre direto na criação da senha: é quem
/// entrou no login com o código provisório liberado pelo administrador.
class RecuperarSenhaScreen extends StatefulWidget {
  /// E-mail de quem entrou com o código da barbearia.
  final String? email;

  /// Código provisório digitado no login, no lugar da senha.
  final String? codigoDaBarbearia;

  const RecuperarSenhaScreen({super.key, this.email, this.codigoDaBarbearia});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmacaoCtrl = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;

  /// Celular para onde o código foi enviado; preenchido, a tela passa para a
  /// segunda etapa.
  String? _telefoneEnviado;

  bool get _comCodigoDaBarbearia => widget.codigoDaBarbearia != null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    setState(() => _carregando = true);
    final r = await AuthService.instance.pedirCodigoPorSms(
      email: _emailCtrl.text,
      telefone: _telefoneCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (r.sucesso) _telefoneEnviado = r.telefone;
    });
    if (r.sucesso) {
      mostrarSucesso(context, 'Código enviado por SMS');
    } else {
      mostrarErro(context, r.erro ?? 'Não foi possível enviar o código');
    }
  }

  Future<void> _salvar() async {
    if (_senhaCtrl.text != _confirmacaoCtrl.text) {
      mostrarErro(context, 'A confirmação não confere com a nova senha');
      return;
    }
    setState(() => _carregando = true);
    final r = await AuthService.instance.redefinirSenha(
      email: widget.email ?? _emailCtrl.text,
      codigo: widget.codigoDaBarbearia ?? _codigoCtrl.text,
      novaSenha: _senhaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _carregando = false);

    if (r.sucesso) {
      mostrarSucesso(context, 'Senha alterada');
      Navigator.of(context).pushNamedAndRemoveUntil(
        AuthService.instance.rotaInicial,
        (_) => false,
      );
    } else {
      mostrarErro(context, r.erro ?? 'Não foi possível criar a nova senha');
    }
  }

  @override
  Widget build(BuildContext context) {
    final criandoSenha = _comCodigoDaBarbearia || _telefoneEnviado != null;

    return Scaffold(
      appBar: BarberAppBar(
        titulo: _comCodigoDaBarbearia ? 'NOVA SENHA' : 'RECUPERAR SENHA',
      ),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: criandoSenha ? _etapaNovaSenha() : _etapaPedido(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _etapaPedido() {
    return [
      ..._cabecalho(
        'Esqueceu a senha?',
        'Digite o e-mail e o celular da sua conta. Vamos enviar um código '
            'por SMS para você criar uma senha nova.',
      ),
      _campo(
        rotulo: 'E-mail',
        controller: _emailCtrl,
        hint: 'seu@email.com',
        icone: Icons.mail_outline,
        tipo: TextInputType.emailAddress,
      ),
      _campo(
        rotulo: 'Celular cadastrado',
        controller: _telefoneCtrl,
        hint: '(67) 99999-0000',
        icone: Icons.phone_outlined,
        tipo: TextInputType.phone,
        formatters: [TelefoneInputFormatter()],
      ),
      const SizedBox(height: 8),
      GoldButton(
        texto: _carregando ? 'ENVIANDO...' : 'ENVIAR CÓDIGO',
        onPressed: _carregando ? null : _enviarCodigo,
      ),
      const SizedBox(height: 24),
      Text(
        'A barbearia liberou um código para você? Use-o no lugar da senha, '
        'na tela de login.',
        textAlign: TextAlign.center,
        style: AppTheme.sans(size: 12, color: AppColors.muted),
      ),
    ];
  }

  List<Widget> _etapaNovaSenha() {
    final telefone = _telefoneEnviado;
    return [
      if (_comCodigoDaBarbearia)
        ..._cabecalho(
          'Crie sua nova senha',
          'Você entrou com o código provisório da barbearia. Para continuar, '
              'crie uma senha só sua.',
        )
      else ...[
        const _SmsSimuladoCard(),
        const SizedBox(height: 24),
        ..._cabecalho(
          'Digite o código',
          'Enviamos um código por SMS para '
              '${mascararTelefone(telefone ?? '')}. Ele vale por '
              '${DatabaseService.validadeCodigoSms.inMinutes} minutos.',
        ),
        _campo(
          rotulo: 'Código do SMS',
          controller: _codigoCtrl,
          hint: '000000',
          icone: Icons.sms_outlined,
          tipo: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      ],
      _campo(
        rotulo: 'Nova senha (mín. 6 caracteres)',
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
        rotulo: 'Confirme a nova senha',
        controller: _confirmacaoCtrl,
        hint: '••••••••',
        icone: Icons.lock_outline,
        obscuro: _ocultarSenha,
      ),
      const SizedBox(height: 8),
      GoldButton(
        texto: _carregando ? 'SALVANDO...' : 'SALVAR E ENTRAR',
        onPressed: _carregando ? null : _salvar,
      ),
      if (!_comCodigoDaBarbearia) ...[
        const SizedBox(height: 12),
        TextButton(
          onPressed: _carregando ? null : _enviarCodigo,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(
            'Reenviar código',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _cabecalho(String titulo, String texto) => [
    Text(titulo, textAlign: TextAlign.center, style: AppTheme.serif(size: 22)),
    const SizedBox(height: 6),
    Text(
      texto,
      textAlign: TextAlign.center,
      style: AppTheme.sans(size: 13, color: AppColors.muted),
    ),
    const SizedBox(height: 28),
  ];

  Widget _campo({
    required String rotulo,
    required TextEditingController controller,
    required String hint,
    required IconData icone,
    TextInputType tipo = TextInputType.text,
    bool obscuro = false,
    Widget? sufixo,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: obscuro,
            inputFormatters: formatters,
            autocorrect: false,
            style: AppTheme.sans(size: 14),
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

/// O SMS que chegaria no celular, mostrado na tela porque o envio é
/// simulado (ver [SmsSimulado]).
class _SmsSimuladoCard extends StatelessWidget {
  const _SmsSimuladoCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SmsEnviado?>(
      valueListenable: SmsSimulado.instance.ultima,
      builder: (_, sms, __) {
        if (sms == null) return const SizedBox.shrink();
        return GoldCard(
          cor: AppColors.card2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GoldBadge(texto: 'SMS SIMULADO'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'para ${mascararTelefone(sms.telefone)}',
                      style: AppTheme.sans(size: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(sms.mensagem, style: AppTheme.sans(size: 14)),
              const SizedBox(height: 12),
              Text(
                'O app não envia SMS de verdade: a mensagem aparece aqui, '
                'como acontece com o Pix e o cartão.',
                style: AppTheme.sans(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
