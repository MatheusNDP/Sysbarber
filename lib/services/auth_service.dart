import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'validators.dart';

/// Gerencia a sessão do usuário logado.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _kUserId = 'logged_user_id';

  Cliente? _atual;
  Cliente? get usuarioAtual => _atual;
  bool get estaLogado => _atual != null;

  /// Carrega o usuário salvo (mantém sessão entre execuções)
  Future<Cliente?> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    if (id == null) return null;
    final c = await DatabaseService.instance.buscarClientePorId(id);
    _atual = c;
    return c;
  }

  /// Faz login validando email e senha contra o banco
  Future<({bool sucesso, String? erro})> login(
      String email, String senha) async {
    if (email.trim().isEmpty || senha.isEmpty) {
      return (sucesso: false, erro: 'Preencha todos os campos');
    }
    final c = await DatabaseService.instance.autenticar(email.trim(), senha);
    if (c == null) {
      return (sucesso: false, erro: 'E-mail ou senha incorretos');
    }
    _atual = c;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, c.id!);
    return (sucesso: true, erro: null);
  }

  /// Cadastra um novo cliente. Já faz login se sucesso.
  Future<({bool sucesso, String? erro})> cadastrar({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    // Validações (delegadas à classe Validators - testável)
    final erroValidacao = Validators.validarCadastro(
      nome: nome,
      email: email,
      telefone: telefone,
      senha: senha,
    );
    if (erroValidacao != null) {
      return (sucesso: false, erro: erroValidacao);
    }
    if (await DatabaseService.instance.emailExiste(email.trim())) {
      return (sucesso: false, erro: 'Este e-mail já está cadastrado');
    }

    final senhaHash = DatabaseService.hashSenha(senha);
    final c = Cliente(
      nome: nome.trim(),
      email: email.trim(),
      telefone: telefone.trim(),
      senhaHash: senhaHash,
    );
    final id = await DatabaseService.instance.cadastrarCliente(c);

    // Loga automaticamente
    final salvo = await DatabaseService.instance.buscarClientePorId(id);
    _atual = salvo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, id);
    return (sucesso: true, erro: null);
  }

  Future<void> logout() async {
    _atual = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
  }

}
