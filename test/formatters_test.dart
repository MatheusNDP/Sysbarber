import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/formatters.dart';

/// Testes unitários das máscaras de entrada.
void main() {
  /// Simula a digitação de um texto num campo com o formatador.
  String aplicar(TextInputFormatter f, String digitado) {
    return f
        .formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: digitado),
        )
        .text;
  }

  group('TelefoneInputFormatter', () {
    test('formata celular com 11 dígitos', () {
      expect(
        aplicar(TelefoneInputFormatter(), '67999990000'),
        '(67) 99999-0000',
      );
    });

    test('formata fixo com 10 dígitos', () {
      expect(aplicar(TelefoneInputFormatter(), '6733334444'), '(67) 3333-4444');
    });

    test('descarta letras e limita a 11 dígitos', () {
      expect(
        aplicar(TelefoneInputFormatter(), 'abc679999900001234'),
        '(67) 99999-0000',
      );
    });
  });

  group('MoedaInputFormatter', () {
    test('monta o valor a partir dos centavos digitados', () {
      expect(aplicar(MoedaInputFormatter(), '3500'), '35,00');
      expect(aplicar(MoedaInputFormatter(), '5'), '0,05');
    });

    test('insere separador de milhar', () {
      expect(aplicar(MoedaInputFormatter(), '250000'), '2.500,00');
    });
  });

  group('Conversão de moeda', () {
    test('moedaParaDouble desfaz a máscara', () {
      expect(moedaParaDouble('2.500,00'), 2500.00);
      expect(moedaParaDouble('35,00'), 35.00);
      expect(moedaParaDouble(''), 0);
    });

    test('ida e volta preserva o valor', () {
      const valor = 2800.55;
      final texto = formatarMoedaDeCentavos((valor * 100).round());
      expect(moedaParaDouble(texto), valor);
    });
  });

  group('Máscaras de cartão', () {
    test('agrupa o número de 4 em 4', () {
      expect(
        aplicar(const CartaoInputFormatter(), '4111111111111111'),
        '4111 1111 1111 1111',
      );
    });

    test('validade vira MM/AA', () {
      expect(aplicar(const ValidadeCartaoInputFormatter(), '1230'), '12/30');
    });
  });
}
