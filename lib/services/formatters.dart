import 'package:flutter/services.dart';

/// Máscaras de entrada do SysBarber.
///
/// Implementadas como [TextInputFormatter] próprios para não depender de
/// pacotes externos — o app não faz nenhuma requisição de rede.

/// Mantém só os dígitos de um texto.
String somenteDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

/// Aplica uma máscara posicional onde `#` representa um dígito.
class _MascaraDigitos extends TextInputFormatter {
  final String mascara;

  const _MascaraDigitos(this.mascara);

  int get _maxDigitos => '#'.allMatches(mascara).length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final digitos = somenteDigitos(novo.text);
    if (digitos.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final limitados = digitos.length > _maxDigitos
        ? digitos.substring(0, _maxDigitos)
        : digitos;

    final buffer = StringBuffer();
    var indice = 0;
    for (final caractere in mascara.split('')) {
      if (indice >= limitados.length) break;
      if (caractere == '#') {
        buffer.write(limitados[indice]);
        indice++;
      } else {
        buffer.write(caractere);
      }
    }

    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Telefone brasileiro: `(67) 99999-9999`.
///
/// Aceita fixo (10 dígitos) e celular (11) — a máscara acompanha conforme o
/// usuário digita.
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final d = somenteDigitos(novo.text);
    if (d.isEmpty) return const TextEditingValue(text: '');

    final limitado = d.length > 11 ? d.substring(0, 11) : d;
    final buffer = StringBuffer();

    for (var i = 0; i < limitado.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      // Celular quebra depois do 5º dígito; fixo, depois do 4º.
      if (limitado.length > 10 ? i == 7 : i == 6) buffer.write('-');
      buffer.write(limitado[i]);
    }

    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Valor monetário: o usuário digita centavos e o campo monta `1.234,56`.
class MoedaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final d = somenteDigitos(novo.text);
    if (d.isEmpty) return const TextEditingValue(text: '');

    final limitado = d.length > 9 ? d.substring(0, 9) : d;
    final centavos = int.parse(limitado);
    final texto = formatarMoedaDeCentavos(centavos);

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// `12345` → `123,45`, com separador de milhar.
String formatarMoedaDeCentavos(int centavos) {
  final inteiro = (centavos ~/ 100).toString();
  final resto = (centavos % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buffer.write('.');
    buffer.write(inteiro[i]);
  }
  return '${buffer.toString()},$resto';
}

/// Converte o texto de um campo com [MoedaInputFormatter] de volta para double.
double moedaParaDouble(String texto) {
  final d = somenteDigitos(texto);
  if (d.isEmpty) return 0;
  return int.parse(d) / 100;
}

/// Cartão: `0000 0000 0000 0000`.
class CartaoInputFormatter extends _MascaraDigitos {
  const CartaoInputFormatter() : super('#### #### #### ####');
}

/// Validade do cartão: `MM/AA`.
class ValidadeCartaoInputFormatter extends _MascaraDigitos {
  const ValidadeCartaoInputFormatter() : super('##/##');
}

/// CVV: 3 ou 4 dígitos.
class CvvInputFormatter extends _MascaraDigitos {
  const CvvInputFormatter() : super('####');
}
