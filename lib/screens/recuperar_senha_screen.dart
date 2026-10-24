import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/email.dart';
import '../services/formatters.dart';
import '../services/sms.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// "Esqueci minha senha" (`/recuperar-senha`, regra de negócio 16).
///
/// Em duas etapas: a pessoa informa o e-mail da conta e recebe um código por
/// e-mail ou por SMS (para o SMS, informa também o celular); com ele, cria
/// uma senha nova e já entra.
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

/// Por onde o código é enviado.
enum _Canal { email, sms }

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmacaoCtrl = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;
  _Canal _canal = _Canal.email;

  /// E-mail ou celular para onde o código foi enviado; preenchido, a tela
  /// passa para a segunda etapa.
  String? _destino;

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
    final auth = AuthService.instance;
    String? destino;
    String? erro;
    if (_canal == _Canal.email) {
      final r = await auth.pedirCodigoPorEmail(email: _emailCtrl.text);
      destino = r.email;
      erro = r.erro;
    } else {
      final r = await auth.pedirCodigoPorSms(
        email: _emailCtrl.text,
        telefone: _telefoneCtrl.text,
      );
      destino = r.telefone;
      erro = r.erro;
    }
    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (destino != null) _destino = destino;
    });
    if (destino != null) {
      mostrarSucesso(
        context,
        _canal == _Canal.email
            ? 'Código enviado por e-mail'
            : 'Código enviado por SMS',
      );
    } else {
      mostrarErro(context, erro ?? 'Não foi possível enviar o código');
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
    final criandoSenha = _comCodigoDaBarbearia || _destino != null;

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
        'Digite o e-mail da sua conta e escolha como receber o código para '
            'criar uma senha nova.',
      ),
      _campo(
        rotulo: 'E-mail',
        controller: _emailCtrl,
        hint: 'seu@email.com',
        icone: Icons.mail_outline,
        tipo: TextInputType.emailAddress,
      ),
      const TituloSecao('Receber o código'),
      const SizedBox(height: 8),
      Row(
        children: [
          _opcaoCanal(_Canal.email, Icons.mail_outline, 'Por e-mail'),
          const SizedBox(width: 12),
          _opcaoCanal(_Canal.sms, Icons.sms_outlined, 'Por SMS'),
        ],
      ),
      const SizedBox(height: 18),
      if (_canal == _Canal.sms)
        _campo(
          rotulo: 'Celular cadastrado',
          controller: _telefoneCtrl,
          hint: '(67) 99999-0000',
          icone: Icons.phone_outlined,
          tipo: TextInputType.phone,
          formatters: [TelefoneInputFormatter()],
        ),
      const SizedBox(height: 8),
      BotaoPrincipal(
        texto: _carregando ? 'ENVIANDO...' : 'ENVIAR CÓDIGO',
        onPressed: _carregando ? null : _enviarCodigo,
      ),
      const SizedBox(height: 24),
      Text(
        'A barbearia liberou um código para você? Use-o no lugar da senha, '
        'na tela de login.',
        textAlign: TextAlign.center,
        style: AppTheme.texto(size: 12, color: AppColors.muted),
      ),
    ];
  }

  Widget _opcaoCanal(_Canal canal, IconData icone, String rotulo) {
    final selecionado = _canal == canal;
    final cor = selecionado ? AppColors.amarelo : AppColors.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selecionado,
        child: Cartao(
          selected: selecionado,
          onTap: () => setState(() => _canal = canal),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 20, color: cor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rotulo,
                  style: AppTheme.texto(
                    size: 14,
                    weight: FontWeight.w700,
                    color: selecionado ? AppColors.amarelo : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Para onde o código foi e quanto tempo ele vale.
  String _textoDoEnvio() {
    final minutos = DatabaseService.validadeCodigoEnviado.inMinutes;
    if (_canal == _Canal.sms) {
      return 'Enviamos um código por SMS para '
          '${mascararTelefone(_destino ?? '')}. Ele vale por $minutos minutos.';
    }
    final spam = AuthService.instance.emailSimulado
        ? ''
        : ' Se não encontrar o e-mail, confira a caixa de spam.';
    return 'Enviamos um código por e-mail para '
        '${mascararEmail(_destino ?? '')}. Ele vale por $minutos minutos.$spam';
  }

  List<Widget> _etapaNovaSenha() {
    final porEmail = _canal == _Canal.email;
    final simulado = !porEmail || AuthService.instance.emailSimulado;
    return [
      if (_comCodigoDaBarbearia)
        ..._cabecalho(
          'Crie sua nova senha',
          'Você entrou com o código provisório da barbearia. Para continuar, '
              'crie uma senha só sua.',
        )
      else ...[
        if (simulado) ...[
          porEmail ? const _EmailSimuladoCard() : const _SmsSimuladoCard(),
          const SizedBox(height: 24),
        ],
        ..._cabecalho('Digite o código', _textoDoEnvio()),
        _campo(
          rotulo: porEmail ? 'Código do e-mail' : 'Código do SMS',
          controller: _codigoCtrl,
          hint: '000000',
          icone: porEmail ? Icons.mail_outline : Icons.sms_outlined,
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
      BotaoPrincipal(
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
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.amarelo,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _cabecalho(String titulo, String texto) => [
    Text(titulo, textAlign: TextAlign.center, style: AppTheme.titulo(size: 22)),
    const SizedBox(height: 6),
    Text(
      texto,
      textAlign: TextAlign.center,
      style: AppTheme.texto(size: 13, color: AppColors.muted),
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
          TituloSecao(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: obscuro,
            inputFormatters: formatters,
            autocorrect: false,
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
        return Cartao(
          cor: AppColors.card2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Etiqueta(texto: 'SMS SIMULADO'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'para ${mascararTelefone(sms.telefone)}',
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(sms.mensagem, style: AppTheme.texto(size: 14)),
              const SizedBox(height: 12),
              Text(
                'O app não envia SMS de verdade: a mensagem aparece aqui, '
                'como acontece com o Pix e o cartão.',
                style: AppTheme.texto(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// O e-mail que chegaria na caixa de entrada, mostrado na tela quando o
/// envio é simulado (ver [EmailSimulado]).
class _EmailSimuladoCard extends StatelessWidget {
  const _EmailSimuladoCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EmailEnviado?>(
      valueListenable: EmailSimulado.instance.ultimo,
      builder: (_, email, __) {
        if (email == null) return const SizedBox.shrink();
        return Cartao(
          cor: AppColors.card2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Etiqueta(texto: 'E-MAIL SIMULADO'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'para ${mascararEmail(email.email)}',
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                email.assunto,
                style: AppTheme.texto(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(email.texto, style: AppTheme.texto(size: 14)),
              const SizedBox(height: 12),
              Text(
                'Este aparelho não está configurado para enviar e-mails: a '
                'mensagem aparece aqui, como acontece com o SMS.',
                style: AppTheme.texto(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
