import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/widgets/animacoes.dart';

/// Testes das animações de entrada: a cascata, a contagem dos pontos e a
/// barra de progresso.
void main() {
  /// Monta [filho] num app; com [semAnimacoes], como no Android com
  /// "Remover animações" ligado.
  Widget app(Widget filho, {bool semAnimacoes = false}) => MaterialApp(
    builder: (context, tela) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: semAnimacoes),
      child: tela!,
    ),
    home: Scaffold(body: filho),
  );

  /// Opacidade do item que contém [texto].
  double opacidade(WidgetTester tester, String texto) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(texto), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  const lista = Cascata(
    child: Column(
      children: [
        ItemDaCascata(ordem: 0, child: Text('primeiro')),
        ItemDaCascata(ordem: 1, child: Text('segundo')),
        ItemDaCascata(ordem: 2, child: Text('terceiro')),
      ],
    ),
  );

  testWidgets('os itens da cascata entram um depois do outro e terminam '
      'visíveis', (tester) async {
    await tester.pumpWidget(app(lista));
    expect(opacidade(tester, 'primeiro'), 0);

    await tester.pump(const Duration(milliseconds: 200));
    final primeiro = opacidade(tester, 'primeiro');
    final segundo = opacidade(tester, 'segundo');
    final terceiro = opacidade(tester, 'terceiro');
    expect(primeiro, lessThan(1));
    expect(primeiro, greaterThan(segundo));
    expect(segundo, greaterThan(terceiro));

    await tester.pumpAndSettle();
    for (final texto in ['primeiro', 'segundo', 'terceiro']) {
      expect(opacidade(tester, texto), 1);
    }
  });

  testWidgets('fora de uma cascata, o item aparece pronto', (tester) async {
    await tester.pumpWidget(
      app(const ItemDaCascata(ordem: 3, child: Text('solto'))),
    );

    expect(
      find.ancestor(of: find.text('solto'), matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('um item montado depois que a cascata terminou (ao rolar a '
      'lista) já aparece pronto', (tester) async {
    var mostrar = false;
    late StateSetter atualizar;
    await tester.pumpWidget(
      app(
        Cascata(
          child: StatefulBuilder(
            builder: (_, setState) {
              atualizar = setState;
              return Column(
                children: [
                  const ItemDaCascata(ordem: 0, child: Text('primeiro')),
                  if (mostrar)
                    const ItemDaCascata(ordem: 9, child: Text('depois')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    atualizar(() => mostrar = true);
    await tester.pump();

    expect(opacidade(tester, 'depois'), 1);
  });

  testWidgets('com "Remover animações" ligado no aparelho, tudo aparece '
      'pronto', (tester) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            lista,
            ContagemAnimada(valor: 150),
            BarraDeProgressoAnimada(
              valor: 0.3,
              altura: 10,
              corDeFundo: Colors.black,
              cor: Colors.yellow,
            ),
          ],
        ),
        semAnimacoes: true,
      ),
    );

    for (final texto in ['primeiro', 'segundo', 'terceiro']) {
      expect(opacidade(tester, texto), 1);
    }
    expect(find.text('150'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      0.3,
    );
  });

  testWidgets('os pontos contam de 0 até o valor, e o leitor de tela lê o '
      'valor final', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      app(ContagemAnimada(valor: 150, formatar: (n) => '$n pts')),
    );
    expect(find.text('0 pts'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    final meio = tester.widget<Text>(find.textContaining('pts')).data;
    expect(meio, isNot('0 pts'));
    expect(meio, isNot('150 pts'));
    expect(find.bySemanticsLabel('150 pts'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('150 pts'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('quando os pontos mudam, a contagem parte do valor anterior', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ContagemAnimada(valor: 150)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(const ContagemAnimada(valor: 200)));
    expect(find.text('150'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('a barra de progresso enche até o valor', (tester) async {
    double valorDaBarra() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    await tester.pumpWidget(
      app(
        const BarraDeProgressoAnimada(
          valor: 0.3,
          altura: 10,
          corDeFundo: Colors.black,
          cor: Colors.yellow,
        ),
      ),
    );
    expect(valorDaBarra(), 0);

    await tester.pumpAndSettle();
    expect(valorDaBarra(), 0.3);
  });
}
