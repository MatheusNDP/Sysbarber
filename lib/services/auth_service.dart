import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'booking_flow.dart';
import 'database_service.dart';
import 'email.dart';
import 'erros.dart';
import 'senhas.dart';
import 'sms.dart';
import 'validators.dart';

/// Autenticação própria com sessão persistente (padrão Singleton).
///
/// A sessão guarda apenas o id e o tipo de conta (cliente ou barbeiro) em
/// `shared_preferences`; os dados são sempre relidos do banco.
class AuthService {
  AuthService._interno();

  static final AuthService instance = AuthService._interno();

  static const String chaveSessao = 'logged_user_id';

  /// `cliente` ou `barbeiro`. Sessões gravadas antes desta chave existir são
  /// sempre de cliente.
  static const String chaveTipoSessao = 'logged_user_tipo';

  static const String _tipoCliente = 'cliente';
  static const String _tipoBarbeiro = 'barbeiro';

  /// Rotas abertas a quem ainda não entrou.
  static const Set<String> _rotasPublicas = {
    '/',
    '/login',
    '/cadastro',
    rotaRecuperarSenha,
  };

  /// "Esqueci minha senha" (regra de negócio 16).
  static const String rotaRecuperarSenha = '/recuperar-senha';

  /// Tela da configuração inicial, a única aberta antes de existir o
  /// administrador (regra de negócio 15).
  static const String rotaConfiguracao = '/configuracao';

  /// Rotas de quem está logado, em qualquer perfil: a área principal (com as
  /// abas de cada perfil) e o Perfil.
  static const Set<String> _rotasLogado = {'/home', '/perfil'};

  /// Rotas só do cliente: agendar e acompanhar os pontos. O administrador
  /// não entra, porque só gerencia a barbearia.
  static const Set<String> _rotasCliente = {
    '/servicos',
    '/barbeiro',
    '/horario',
    '/confirmacao',
    '/pagamento',
    '/fidelidade',
  };

  Cliente? _usuarioAtual;

  /// Profissional logado, quando o acesso foi feito com credenciais de
  /// barbeiro em vez de cliente.
  Barbeiro? _barbeiroAtual;

  /// Cliente logado. É `null` para o barbeiro, que não tem cadastro de
  /// cliente (antes ganhava um "cliente" improvisado, com id nulo).
  Cliente? get usuarioAtual => _usuarioAtual;

  Barbeiro? get barbeiroAtual => _barbeiroAtual;

  bool get estaLogado => _usuarioAtual != null || _barbeiroAtual != null;

  /// `true` quando quem está usando o app é um profissional da barbearia.
  bool get ehBarbeiro => _barbeiroAtual != null;

  /// Só a conta marcada como `admin` enxerga a área administrativa.
  /// Barbeiros veem apenas a própria agenda; clientes comuns, nada disso.
  bool get podeAdministrar => _usuarioAtual?.admin ?? false;

  /// Cliente da barbearia: agenda, tem pontos e Fidelidade. O administrador
  /// também é uma conta da tabela de clientes, mas não é cliente.
  bool get ehCliente => _usuarioAtual != null && !podeAdministrar;

  /// Nome de quem está logado, seja cliente ou barbeiro.
  String? get nomeLogado => _usuarioAtual?.nome ?? _barbeiroAtual?.nome;

  /// Primeira tela depois de entrar: a área principal, com as abas do perfil
  /// de quem entrou.
  String get rotaInicial => '/home';

  bool _barbeariaConfigurada = false;

  /// Já existe o administrador? Lido do banco na abertura do app
  /// ([carregarConfiguracao]) e atualizado por [configurarBarbearia].
  bool get barbeariaConfigurada => _barbeariaConfigurada;

  /// Quem está logado pode abrir [rota]?
  ///
  /// Esconder um botão não protege uma tela; as rotas passam por aqui antes
  /// de serem construídas (ver `onGenerateRoute` em `main.dart`).
  bool podeAcessar(String rota) {
    // Antes da configuração inicial não há contas para entrar: só a abertura
    // e a própria configuração. Depois dela, a configuração não abre mais.
    if (!_barbeariaConfigurada) return rota == '/' || rota == rotaConfiguracao;
    if (rota == rotaConfiguracao) return false;
    if (_rotasPublicas.contains(rota)) return true;
    if (_rotasLogado.contains(rota)) return estaLogado;
    // Os próprios agendamentos: do cliente ou do barbeiro. O administrador
    // vê todos na agenda geral, que fica no painel.
    if (rota == '/agendamentos') return ehCliente || ehBarbeiro;
    if (rota == '/admin') return podeAdministrar;
    if (_rotasCliente.contains(rota)) return ehCliente;
    return false;
  }

  final DatabaseService _db = DatabaseService.instance;

  /// Por onde sai o código de "Esqueci minha senha". Simulado, como o Pix e
  /// o cartão; um provedor real entra trocando esta linha (ver [EnvioSms]).
  final EnvioSms _sms = SmsSimulado.instance;

  /// Por onde sai o código pedido por e-mail: o EmailJS, quando configurado
  /// no build, ou o e-mail simulado (ver [envioEmailPadrao]).
  EnvioEmail _email = envioEmailPadrao();

  /// O e-mail da recuperação de senha é simulado neste build? Nesse caso a
  /// tela mostra a mensagem, como faz com o SMS.
  bool get emailSimulado => _email is EmailSimulado;

  /// Troca o envio de e-mail (os testes simulam falhas por aqui).
  @visibleForTesting
  set envioEmail(EnvioEmail envio) => _email = envio;

  /// Lê do banco se a barbearia já foi configurada (chamado na abertura do
  /// app, antes da primeira tela).
  Future<void> carregarConfiguracao() async {
    _barbeariaConfigurada = await _db.barbeariaConfigurada();
  }

  /// Configuração inicial: cria o administrador (e, se pedido, os dados de
  /// exemplo) e já entra com ele (regra de negócio 15).
  Future<({bool sucesso, String? erro})> configurarBarbearia({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
    required bool dadosDeExemplo,
  }) async {
    try {
      final admin = await _db.configurarBarbearia(
        nome: nome,
        email: email,
        telefone: telefone,
        senha: senha,
        dadosDeExemplo: dadosDeExemplo,
      );
      _barbeariaConfigurada = true;
      BookingFlow.limpar();
      _usuarioAtual = admin;
      _barbeiroAtual = null;
      await _salvarSessao(admin.id!, _tipoCliente);
      return (sucesso: true, erro: null);
    } catch (e) {
      // Se outra configuração terminou antes, a tela precisa saber.
      try {
        await carregarConfiguracao();
      } catch (_) {}
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível configurar a barbearia'),
      );
    }
  }

  /// Restaura a sessão salva (chamado na inicialização do app).
  Future<void> carregarSessao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(chaveSessao);
      if (id == null) return;

      if (prefs.getString(chaveTipoSessao) == _tipoBarbeiro) {
        final barbeiro = await _db.buscarBarbeiroPorId(id);
        if (barbeiro != null) {
          _barbeiroAtual = barbeiro;
          _usuarioAtual = null;
          return;
        }
      } else {
        final cliente = await _db.buscarClientePorId(id);
        if (cliente != null) {
          _usuarioAtual = cliente;
          _barbeiroAtual = null;
          return;
        }
      }
      // A conta salva não existe mais.
      await _limparSessaoSalva(prefs);
    } catch (_) {
      // Sem sessão restaurada o app simplesmente começa deslogado.
    }
  }

  /// Entra com e-mail e senha.
  ///
  /// [criarNovaSenha] é `true` quando, no lugar da senha, veio o código
  /// provisório que a barbearia liberou (regra de negócio 16): a pessoa ainda
  /// não entrou e precisa criar uma senha nova ([redefinirSenha]).
  Future<({bool sucesso, String? erro, bool criarNovaSenha})> login(
    String email,
    String senha,
  ) async {
    if (email.trim().isEmpty || senha.isEmpty) {
      return (
        sucesso: false,
        erro: 'Preencha todos os campos',
        criarNovaSenha: false,
      );
    }

    final normalizado = email.trim().toLowerCase();

    try {
      final cliente = await _db.autenticar(normalizado, senha);
      if (cliente != null) {
        // Um rascunho de agendamento nunca passa de uma conta para outra.
        BookingFlow.limpar();
        _usuarioAtual = cliente;
        _barbeiroAtual = null;
        await _salvarSessao(cliente.id!, _tipoCliente);
        return (sucesso: true, erro: null, criarNovaSenha: false);
      }

      // Não sendo cliente, tenta as credenciais de profissional.
      final barbeiro = await _db.autenticarBarbeiro(normalizado, senha);
      if (barbeiro != null) {
        BookingFlow.limpar();
        _barbeiroAtual = barbeiro;
        _usuarioAtual = null;
        await _salvarSessao(barbeiro.id!, _tipoBarbeiro);
        return (sucesso: true, erro: null, criarNovaSenha: false);
      }

      // No lugar da senha pode ter vindo o código que a barbearia liberou.
      if (await _db.codigoDaBarbeariaConfere(normalizado, senha)) {
        return (sucesso: false, erro: null, criarNovaSenha: true);
      }

      return (
        sucesso: false,
        erro: 'E-mail ou senha incorretos',
        criarNovaSenha: false,
      );
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível entrar'),
        criarNovaSenha: false,
      );
    }
  }

  /// "Esqueci minha senha": gera o código e o envia por SMS para o celular
  /// cadastrado (regra de negócio 16). Devolve esse celular, para a tela
  /// dizer para onde o código foi.
  Future<({bool sucesso, String? erro, String? telefone})> pedirCodigoPorSms({
    required String email,
    required String telefone,
  }) async {
    if (email.trim().isEmpty || telefone.trim().isEmpty) {
      return (
        sucesso: false,
        erro: 'Preencha o e-mail e o celular',
        telefone: null,
      );
    }
    try {
      final gerado = await _db.gerarCodigoPorSms(
        email: email,
        telefone: telefone,
      );
      final minutos = DatabaseService.validadeCodigoEnviado.inMinutes;
      await _sms.enviar(
        telefone: gerado.telefone,
        mensagem:
            'SysBarber: seu código para criar uma nova senha é '
            '${gerado.codigo}. Ele vale por $minutos minutos. Não o '
            'compartilhe com ninguém.',
      );
      return (sucesso: true, erro: null, telefone: gerado.telefone);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível enviar o código'),
        telefone: null,
      );
    }
  }

  /// "Esqueci minha senha" por e-mail: gera o código e o envia para o
  /// próprio [email] da conta (regra de negócio 16). Devolve o e-mail para
  /// onde o código foi.
  ///
  /// Se o envio falhar (sem internet, por exemplo), o código é descartado:
  /// ele não chegou a ninguém e não pode segurar o intervalo entre envios.
  Future<({bool sucesso, String? erro, String? email})> pedirCodigoPorEmail({
    required String email,
  }) async {
    if (email.trim().isEmpty) {
      return (sucesso: false, erro: 'Preencha o e-mail', email: null);
    }
    final ({String codigo, String nome, String email}) gerado;
    try {
      gerado = await _db.gerarCodigoPorEmail(email: email);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível gerar o código'),
        email: null,
      );
    }
    try {
      await _email.enviarCodigo(
        email: gerado.email,
        nome: gerado.nome,
        codigo: gerado.codigo,
        minutos: DatabaseService.validadeCodigoEnviado.inMinutes,
      );
    } catch (e) {
      try {
        await _db.descartarCodigo(
          email: gerado.email,
          origem: OrigemCodigo.email,
        );
      } catch (_) {
        // Sem o descarte, o código só vence sozinho em 10 minutos.
      }
      return (
        sucesso: false,
        erro: mensagemDeErro(
          e,
          'Não foi possível enviar o e-mail. Confira a conexão com a internet',
        ),
        email: null,
      );
    }
    return (sucesso: true, erro: null, email: gerado.email);
  }

  /// Cria a senha nova com o código (do SMS, do e-mail ou da barbearia) e já
  /// entra (regra de negócio 16).
  Future<({bool sucesso, String? erro})> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    if (codigo.trim().isEmpty || novaSenha.isEmpty) {
      return (sucesso: false, erro: 'Preencha todos os campos');
    }
    try {
      await _db.redefinirSenhaComCodigo(
        email: email,
        codigo: codigo,
        novaSenha: novaSenha,
      );
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível criar a nova senha'),
      );
    }
    final entrada = await login(email, novaSenha);
    return (sucesso: entrada.sucesso, erro: entrada.erro);
  }

  /// O administrador libera uma nova senha para o cliente [idCliente]
  /// (regra de negócio 16). Devolve o código provisório, que ele entrega ao
  /// cliente no balcão.
  Future<({bool sucesso, String? erro, String? codigo})> liberarNovaSenha(
    int idCliente,
  ) async {
    if (!podeAdministrar) {
      return (
        sucesso: false,
        erro: 'Só o administrador pode liberar uma nova senha',
        codigo: null,
      );
    }
    try {
      final codigo = await _db.liberarCodigoDaBarbearia(idCliente);
      return (sucesso: true, erro: null, codigo: codigo);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível liberar a nova senha'),
        codigo: null,
      );
    }
  }

  /// Cadastra o cliente e já o deixa logado.
  Future<({bool sucesso, String? erro})> cadastrar({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    final erro = Validators.validarCadastro(
      nome: nome,
      email: email,
      telefone: telefone,
      senha: senha,
    );
    if (erro != null) return (sucesso: false, erro: erro);

    final emailNormalizado = email.trim().toLowerCase();

    try {
      if (await _db.emailExiste(emailNormalizado)) {
        return (sucesso: false, erro: 'Este e-mail já está cadastrado');
      }
      // O e-mail também não pode colidir com o acesso de um profissional.
      if (await _db.emailBarbeiroExiste(emailNormalizado)) {
        return (sucesso: false, erro: 'Este e-mail já está cadastrado');
      }

      final novo = Cliente(
        nome: nome.trim(),
        email: emailNormalizado,
        telefone: telefone.trim(),
        senhaHash: await Senhas.gerarHashEmSegundoPlano(senha),
        criadoEm: DateTime.now().toIso8601String(),
      );

      final id = await _db.cadastrarCliente(novo);
      BookingFlow.limpar();
      _usuarioAtual = novo.copyWith(id: id);
      _barbeiroAtual = null;
      await _salvarSessao(id, _tipoCliente);
      return (sucesso: true, erro: null);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível salvar o cadastro'),
      );
    }
  }

  Future<void> logout() async {
    esquecerSessaoEmMemoria();
    try {
      await _limparSessaoSalva(await SharedPreferences.getInstance());
    } catch (_) {
      // Sem persistência disponível a sessão em memória já foi limpa.
    }
  }

  /// Limpa só a memória — o equivalente a fechar o app. Os testes usam isto
  /// para simular um reinício e conferir o que [carregarSessao] restaura.
  @visibleForTesting
  void esquecerSessaoEmMemoria() {
    _usuarioAtual = null;
    _barbeiroAtual = null;
    BookingFlow.limpar();
  }

  /// Atualiza nome e telefone do cliente logado.
  Future<({bool sucesso, String? erro})> atualizarPerfil({
    required String nome,
    required String telefone,
  }) async {
    final id = _usuarioAtual?.id;
    if (id == null) {
      return (sucesso: false, erro: 'Entre na sua conta para editar o perfil');
    }
    if (!Validators.nomeValido(nome)) {
      return (sucesso: false, erro: 'Nome deve ter pelo menos 3 caracteres');
    }
    if (!Validators.telefoneValido(telefone)) {
      return (sucesso: false, erro: 'Telefone inválido');
    }
    try {
      await _db.atualizarContatoCliente(id, nome: nome, telefone: telefone);
      await recarregarUsuario();
      return (sucesso: true, erro: null);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível salvar seus dados'),
      );
    }
  }

  /// Troca a senha de quem está logado (cliente, administrador ou
  /// barbeiro), conferindo a atual.
  Future<({bool sucesso, String? erro})> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final idCliente = _usuarioAtual?.id;
    final idBarbeiro = _barbeiroAtual?.id;
    if (idCliente == null && idBarbeiro == null) {
      return (sucesso: false, erro: 'Entre na sua conta para trocar a senha');
    }
    try {
      if (idCliente != null) {
        await _db.alterarSenhaCliente(
          idCliente,
          senhaAtual: senhaAtual,
          novaSenha: novaSenha,
        );
        await recarregarUsuario();
      } else {
        await _db.alterarSenhaBarbeiro(
          idBarbeiro!,
          senhaAtual: senhaAtual,
          novaSenha: novaSenha,
        );
        _barbeiroAtual = await _db.buscarBarbeiroPorId(idBarbeiro);
      }
      return (sucesso: true, erro: null);
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível trocar a senha'),
      );
    }
  }

  /// Recarrega o usuário logado a partir do banco.
  Future<void> recarregarUsuario() async {
    final id = _usuarioAtual?.id;
    if (id == null) return;
    final atualizado = await _db.buscarClientePorId(id);
    if (atualizado != null) _usuarioAtual = atualizado;
  }

  Future<void> _salvarSessao(int id, String tipo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(chaveSessao, id);
      await prefs.setString(chaveTipoSessao, tipo);
    } catch (_) {
      // Ambiente sem shared_preferences: sessão fica só em memória.
    }
  }

  Future<void> _limparSessaoSalva(SharedPreferences prefs) async {
    await prefs.remove(chaveSessao);
    await prefs.remove(chaveTipoSessao);
  }
}
