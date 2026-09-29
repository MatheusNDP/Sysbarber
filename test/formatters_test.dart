import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/formatters.dart';
import 'package:sysbarber/widgets/common_widgets.dart';

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

    test('aceita até 19 dígitos, como o validador (Luhn)', () {
      // Antes a máscara parava em 16 e cortava cartões válidos.
      expect(
        aplicar(const CartaoInputFormatter(), '6011000990139424123'),
        '6011 0009 9013 9424 123',
      );
    });

    test('Amex (34/37) usa o agrupamento 4-6-5', () {
      expect(
        aplicar(const CartaoInputFormatter(), '378282246310005'),
        '3782 822463 10005',
      );
    });
  });

  group('formatarReal', () {
    test('usa separador de milhar e vírgula decimal', () {
      // Antes: "R\$ 2800,00", diferente dos campos, que mostram 2.800,00.
      expect(formatarReal(2800), 'R\$ 2.800,00');
      expect(formatarReal(35), 'R\$ 35,00');
      expect(formatarReal(1234567.891), 'R\$ 1.234.567,89');
      expect(formatarReal(0.5), 'R\$ 0,50');
    });

    test('valor negativo leva o sinal antes do símbolo', () {
      expect(formatarReal(-27.5), '-R\$ 27,50');
    });
  });
}
