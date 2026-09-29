import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hash de senhas com PBKDF2-HMAC-SHA256 e salt individual.
///
/// Formato gravado: `pbkdf2-sha256$<iterações>$<salt>$<hash>` (salt e hash
/// em base64). Guardar as iterações no próprio hash permite aumentá-las no
/// futuro sem invalidar as senhas antigas.
///
/// Até a v5 o app usava SHA-256 com um salt fixo, igual para todos: a mesma
/// senha gerava o mesmo hash em qualquer conta e o cálculo era rápido demais
/// para resistir a força bruta. Esse formato ainda é aceito no login e é
/// trocado pelo novo assim que a senha é conferida.
class Senhas {
  Senhas._();

  static const String _prefixo = 'pbkdf2-sha256';

  /// Iterações de novos hashes. PBKDF2 em Dart puro custa ~85 ms com 50 mil
  /// iterações num computador; por isso login e cadastro calculam o hash em
  /// outro isolate ([gerarHashEmSegundoPlano]), sem travar a tela.
  ///
  /// Os testes reduzem este valor só para rodar rápido — o formato é o mesmo.
  static int iteracoes = 50000;

  static String gerarHash(String senha) {
    final salt = _saltAleatorio();
    final hash = pbkdf2(utf8.encode(senha), salt, iteracoes, 32);
    return '$_prefixo\$$iteracoes\$${base64Url.encode(salt)}'
        '\$${base64Url.encode(hash)}';
  }

  /// Confere a senha contra um hash no formato novo ou no legado.
  static bool conferir(String senha, String armazenado) {
    if (!armazenado.startsWith('$_prefixo\$')) {
      return _iguais(utf8.encode(hashLegado(senha)), utf8.encode(armazenado));
    }
    final partes = armazenado.split(r'$');
    if (partes.length != 4) return false;
    final iteracoesGravadas = int.tryParse(partes[1]);
    if (iteracoesGravadas == null || iteracoesGravadas < 1) return false;
    try {
      final salt = base64Url.decode(partes[2]);
      final esperado = base64Url.decode(partes[3]);
      final obtido = pbkdf2(
        utf8.encode(senha),
        salt,
        iteracoesGravadas,
        esperado.length,
      );
      return _iguais(obtido, esperado);
    } on FormatException {
      return false;
    }
  }

  /// O hash está num formato (ou custo) mais fraco que o atual?
  static bool precisaAtualizar(String armazenado) {
    if (!armazenado.startsWith('$_prefixo\$')) return true;
    final partes = armazenado.split(r'$');
    final gravadas = partes.length == 4 ? int.tryParse(partes[1]) : null;
    return gravadas == null || gravadas < iteracoes;
  }

  /// [gerarHash] fora da thread da interface.
  static Future<String> gerarHashEmSegundoPlano(String senha) {
    final custo = iteracoes;
    return Isolate.run(() {
      iteracoes = custo;
      return gerarHash(senha);
    });
  }

  /// [conferir] fora da thread da interface.
  static Future<bool> conferirEmSegundoPlano(String senha, String armazenado) =>
      Isolate.run(() => conferir(senha, armazenado));

  /// Formato usado até a v5: SHA-256 com salt fixo. Só serve para aceitar
  /// senhas antigas no login.
  static String hashLegado(String senha) =>
      sha256.convert(utf8.encode('sysbarber_salt_$senha')).toString();

  /// PBKDF2-HMAC-SHA256 (RFC 8018).
  static List<int> pbkdf2(
    List<int> senha,
    List<int> salt,
    int iteracoes,
    int tamanho,
  ) {
    final hmac = Hmac(sha256, senha);
    final saida = <int>[];
    for (var bloco = 1; saida.length < tamanho; bloco++) {
      var u = hmac.convert([
        ...salt,
        (bloco >> 24) & 0xff,
        (bloco >> 16) & 0xff,
        (bloco >> 8) & 0xff,
        bloco & 0xff,
      ]).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < iteracoes; i++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      saida.addAll(t);
    }
    return saida.sublist(0, tamanho);
  }

  static List<int> _saltAleatorio() {
    final aleatorio = Random.secure();
    return List<int>.generate(16, (_) => aleatorio.nextInt(256));
  }

  /// Comparação em tempo constante: não revela, pelo tempo de resposta,
  /// quantos bytes iniciais coincidiram.
  static bool _iguais(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diferenca = 0;
    for (var i = 0; i < a.length; i++) {
      diferenca |= a[i] ^ b[i];
    }
    return diferenca == 0;
  }
}
