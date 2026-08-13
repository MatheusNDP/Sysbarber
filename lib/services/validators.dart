/// Regras de validação do SysBarber.
///
/// Mantidas fora das telas e sem dependência de Flutter para que possam ser
/// exercitadas diretamente pelos testes unitários.
class Validators {
  Validators._();

  static final RegExp _regexEmail = RegExp(
    r'^[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}$',
  );

  static bool emailValido(String email) => _regexEmail.hasMatch(email.trim());

  static bool nomeValido(String nome) => nome.trim().length >= 3;

  static bool telefoneValido(String telefone) => telefone.trim().length >= 8;

  static bool senhaValida(String senha) => senha.length >= 6;

  /// Valida o formulário de cadastro completo.
  ///
  /// Retorna `null` quando todos os campos estão corretos ou a mensagem de
  /// erro correspondente à primeira regra violada.
  static String? validarCadastro({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) {
    if (nome.trim().isEmpty ||
        email.trim().isEmpty ||
        telefone.trim().isEmpty ||
        senha.isEmpty) {
      return 'Preencha todos os campos';
    }
    if (!nomeValido(nome)) return 'Nome deve ter pelo menos 3 caracteres';
    if (!emailValido(email)) return 'E-mail inválido';
    if (!telefoneValido(telefone)) return 'Telefone inválido';
    if (!senhaValida(senha)) return 'Senha deve ter no mínimo 6 caracteres';
    return null;
  }

  // -------------------------------------------------------------------------
  // BARBEIRO (área administrativa)
  // -------------------------------------------------------------------------

  static bool salarioValido(double salario) => salario > 0;

  static bool especialidadeValida(String v) => v.trim().length >= 3;

  /// Valida o formulário de cadastro/edição de barbeiro.
  ///
  /// [senhaObrigatoria] é `false` na edição: deixar o campo em branco mantém
  /// a senha atual do profissional.
  static String? validarBarbeiro({
    required String nome,
    required String especialidade,
    required String telefone,
    required String email,
    required String senha,
    required double salario,
    bool senhaObrigatoria = true,
  }) {
    if (!nomeValido(nome)) return 'Nome deve ter pelo menos 3 caracteres';
    if (!especialidadeValida(especialidade)) {
      return 'Especialidade deve ter pelo menos 3 caracteres';
    }
    if (!telefoneValido(telefone)) return 'Telefone inválido';
    if (!emailValido(email)) return 'E-mail inválido';
    if (senhaObrigatoria || senha.isNotEmpty) {
      if (!senhaValida(senha)) return 'Senha deve ter no mínimo 6 caracteres';
    }
    if (!salarioValido(salario)) return 'Salário deve ser maior que zero';
    return null;
  }

  // -------------------------------------------------------------------------
  // CARTÃO (simulação de pagamento)
  // -------------------------------------------------------------------------

  /// Valida o número pelo algoritmo de Luhn, o mesmo usado pelas bandeiras.
  static bool cartaoValido(String numero) {
    final d = numero.replaceAll(RegExp(r'\D'), '');
    if (d.length < 13 || d.length > 19) return false;

    var soma = 0;
    var alternar = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = int.parse(d[i]);
      if (alternar) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      soma += n;
      alternar = !alternar;
    }
    return soma % 10 == 0;
  }

  /// Aceita `MM/AA` de um mês que ainda não passou.
  static bool validadeCartaoValida(String validade, {DateTime? agora}) {
    final d = validade.replaceAll(RegExp(r'\D'), '');
    if (d.length != 4) return false;

    final mes = int.parse(d.substring(0, 2));
    final ano = 2000 + int.parse(d.substring(2));
    if (mes < 1 || mes > 12) return false;

    final referencia = agora ?? DateTime.now();
    // Vale até o último instante do mês informado.
    final expiraEm = DateTime(ano, mes + 1, 1);
    return expiraEm.isAfter(DateTime(referencia.year, referencia.month, 1));
  }

  static bool cvvValido(String cvv) {
    final d = cvv.replaceAll(RegExp(r'\D'), '');
    return d.length == 3 || d.length == 4;
  }

  /// Valida o formulário completo do cartão.
  static String? validarCartao({
    required String numero,
    required String nome,
    required String validade,
    required String cvv,
    DateTime? agora,
  }) {
    if (!cartaoValido(numero)) return 'Número de cartão inválido';
    if (!nomeValido(nome)) return 'Informe o nome impresso no cartão';
    if (!validadeCartaoValida(validade, agora: agora)) {
      return 'Validade inválida ou vencida';
    }
    if (!cvvValido(cvv)) return 'CVV inválido';
    return null;
  }
}
