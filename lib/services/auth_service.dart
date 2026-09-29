import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'booking_flow.dart';
import 'database_service.dart';
import 'erros.dart';
import 'senhas.dart';
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
  static const Set<String> _rotasPublicas = {'/', '/login', '/cadastro'};

  /// Rotas da área do cliente (inclui o administrador, que é um cliente).
  static const Set<String> _rotasCliente = {
    '/home',
    '/servicos',
    '/barbeiro',
    '/horario',
    '/confirmacao',
    '/pagamento',
    '/fidelidade',
    '/perfil',
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

  /// Nome de quem está logado, seja cliente ou barbeiro.
  String? get nomeLogado => _usuarioAtual?.nome ?? _barbeiroAtual?.nome;

  /// Primeira tela depois de entrar: o barbeiro vai direto para a agenda.
  String get rotaInicial => ehBarbeiro ? '/agendamentos' : '/home';

  /// Quem está logado pode abrir [rota]?
  ///
  /// Esconder um botão não protege uma tela; as rotas passam por aqui antes
  /// de serem construídas (ver `onGenerateRoute` em `main.dart`).
  bool podeAcessar(String rota) {
    if (_rotasPublicas.contains(rota)) return true;
    if (rota == '/agendamentos') return estaLogado;
    if (rota == '/admin') return podeAdministrar;
    if (_rotasCliente.contains(rota)) return _usuarioAtual != null;
    return false;
  }

  final DatabaseService _db = DatabaseService.instance;

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

  Future<({bool sucesso, String? erro})> login(
    String email,
    String senha,
  ) async {
    if (email.trim().isEmpty || senha.isEmpty) {
      return (sucesso: false, erro: 'Preencha todos os campos');
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
        return (sucesso: true, erro: null);
      }

      // Não sendo cliente, tenta as credenciais de profissional.
      final barbeiro = await _db.autenticarBarbeiro(normalizado, senha);
      if (barbeiro != null) {
        BookingFlow.limpar();
        _barbeiroAtual = barbeiro;
        _usuarioAtual = null;
        await _salvarSessao(barbeiro.id!, _tipoBarbeiro);
        return (sucesso: true, erro: null);
      }

      return (sucesso: false, erro: 'E-mail ou senha incorretos');
    } catch (e) {
      return (
        sucesso: false,
        erro: mensagemDeErro(e, 'Não foi possível entrar'),
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

  /// Troca a senha do cliente logado, conferindo a atual.
  Future<({bool sucesso, String? erro})> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final id = _usuarioAtual?.id;
    if (id == null) {
      return (sucesso: false, erro: 'Entre na sua conta para trocar a senha');
    }
    try {
      await _db.alterarSenhaCliente(
        id,
        senhaAtual: senhaAtual,
        novaSenha: novaSenha,
      );
      await recarregarUsuario();
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
