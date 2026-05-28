/// Validadores reutilizáveis e testáveis do sistema.
/// Separados em uma classe própria para facilitar testes unitários.
class Validators {
  /// Valida formato de e-mail.
  static bool emailValido(String email) {
    final r = RegExp(r'^[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}$');
    return r.hasMatch(email.trim());
  }

  /// Valida nome (mínimo 3 caracteres).
  static bool nomeValido(String nome) => nome.trim().length >= 3;

  /// Valida telefone (mínimo 8 dígitos).
  static bool telefoneValido(String tel) => tel.trim().length >= 8;

  /// Valida senha (mínimo 6 caracteres).
  static bool senhaValida(String senha) => senha.length >= 6;

  /// Retorna mensagem de erro de validação ou null se tudo ok.
  static String? validarCadastro({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) {
    if (!nomeValido(nome)) {
      return 'Nome deve ter pelo menos 3 caracteres';
    }
    if (!emailValido(email)) {
      return 'E-mail inválido';
    }
    if (!telefoneValido(telefone)) {
      return 'Telefone inválido';
    }
    if (!senhaValida(senha)) {
      return 'Senha deve ter no mínimo 6 caracteres';
    }
    return null;
  }
}
