import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'database_service.dart';
import 'validators.dart';

/// Autenticação própria com sessão persistente (padrão Singleton).
///
/// A sessão guarda apenas o id do cliente em `shared_preferences`; os dados
/// são sempre relidos do banco.
class AuthService {
  AuthService._interno();

  static final AuthService instance = AuthService._interno();

  static const String chaveSessao = 'logged_user_id';

  Cliente? _usuarioAtual;

  /// Profissional logado, quando o acesso foi feito com credenciais de
  /// barbeiro em vez de cliente.
  Barbeiro? _barbeiroAtual;

  Cliente? get usuarioAtual => _usuarioAtual;

  Barbeiro? get barbeiroAtual => _barbeiroAtual;

  bool get estaLogado => _usuarioAtual != null;

  /// `true` quando quem está usando o app é um profissional da barbearia.
  bool get ehBarbeiro => _barbeiroAtual != null;

  /// Só a conta marcada como `admin` enxerga a área administrativa.
  /// Barbeiros veem apenas a própria agenda; clientes comuns, nada disso.
  bool get podeAdministrar => !ehBarbeiro && (_usuarioAtual?.admin ?? false);

  final DatabaseService _db = DatabaseService.instance;

  /// Restaura a sessão salva (chamado na inicialização do app).
  Future<Cliente?> carregarSessao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(chaveSessao);
      if (id == null) return null;
      final cliente = await _db.buscarClientePorId(id);
      if (cliente == null) {
        await prefs.remove(chaveSessao);
        return null;
      }
      _usuarioAtual = cliente;
      return cliente;
    } catch (_) {
      return null;
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
        _usuarioAtual = cliente;
        _barbeiroAtual = null;
        await _salvarSessao(cliente.id!);
        return (sucesso: true, erro: null);
      }

      // Não sendo cliente, tenta as credenciais de profissional.
      final barbeiro = await _db.autenticarBarbeiro(normalizado, senha);
      if (barbeiro != null) {
        _barbeiroAtual = barbeiro;
        // O barbeiro navega no app com um perfil derivado do seu cadastro.
        _usuarioAtual = Cliente(
          id: null,
          nome: barbeiro.nome,
          email: barbeiro.email,
          telefone: barbeiro.telefone,
          senhaHash: barbeiro.senhaHash,
          criadoEm: DateTime.now().toIso8601String(),
        );
        return (sucesso: true, erro: null);
      }

      return (sucesso: false, erro: 'E-mail ou senha incorretos');
    } catch (e) {
      return (sucesso: false, erro: 'Erro ao acessar os dados: $e');
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
        senhaHash: DatabaseService.hashSenha(senha),
        criadoEm: DateTime.now().toIso8601String(),
      );

      final id = await _db.cadastrarCliente(novo);
      _usuarioAtual = novo.copyWith(id: id);
      _barbeiroAtual = null;
      await _salvarSessao(id);
      return (sucesso: true, erro: null);
    } catch (e) {
      return (sucesso: false, erro: 'Erro ao salvar o cadastro: $e');
    }
  }

  Future<void> logout() async {
    _usuarioAtual = null;
    _barbeiroAtual = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(chaveSessao);
    } catch (_) {
      // Sem persistência disponível a sessão em memória já foi limpa.
    }
  }

  /// Recarrega o usuário logado a partir do banco.
  Future<void> recarregarUsuario() async {
    final id = _usuarioAtual?.id;
    if (id == null) return;
    final atualizado = await _db.buscarClientePorId(id);
    if (atualizado != null) _usuarioAtual = atualizado;
  }

  Future<void> _salvarSessao(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(chaveSessao, id);
    } catch (_) {
      // Ambiente sem shared_preferences (testes): sessão fica só em memória.
    }
  }
}
