import 'dart:math' show min;

import 'package:flutter/material.dart';

/// Ritmo das animações de entrada: sutil e rápido.
class Animacoes {
  Animacoes._();

  /// Quanto cada elemento leva para entrar.
  static const duracao = Duration(milliseconds: 400);

  /// Intervalo entre um elemento e o próximo da cascata.
  static const intervalo = Duration(milliseconds: 60);

  /// Quanto os números (pontos) levam para contar até o valor.
  static const duracaoContagem = Duration(milliseconds: 800);

  static const curva = Curves.easeOutCubic;

  /// A partir deste item, os seguintes entram junto com ele, para uma lista
  /// longa não demorar a aparecer.
  static const maxEmCascata = 8;

  /// Distância, em pixels, que o elemento sobe ao entrar.
  static const deslocamento = 24.0;

  /// Se o aparelho pede para remover as animações (acessibilidade do
  /// Android), tudo aparece pronto.
  static bool desligadas(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Faz os [ItemDaCascata] abaixo dela entrarem um depois do outro, uma vez,
/// quando ela aparece. O relógio é um só: um item que só é montado depois
/// (ao rolar a lista, por exemplo) já aparece pronto, sem animar de novo.
class Cascata extends StatefulWidget {
  final Widget child;

  /// Intervalo entre um item e o próximo.
  final Duration intervalo;

  const Cascata({
    super.key,
    required this.child,
    this.intervalo = Animacoes.intervalo,
  });

  @override
  State<Cascata> createState() => _CascataState();
}

class _CascataState extends State<Cascata> with SingleTickerProviderStateMixin {
  late final AnimationController _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = AnimationController(
      vsync: this,
      duration: widget.intervalo * Animacoes.maxEmCascata + Animacoes.duracao,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Animacoes.desligadas(context)) {
      _relogio.value = 1;
    } else if (_relogio.isDismissed) {
      _relogio.forward();
    }
  }

  @override
  void dispose() {
    _relogio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EscopoDaCascata(
    relogio: _relogio,
    intervalo: widget.intervalo,
    child: widget.child,
  );
}

class _EscopoDaCascata extends InheritedWidget {
  final AnimationController relogio;
  final Duration intervalo;

  const _EscopoDaCascata({
    required this.relogio,
    required this.intervalo,
    required super.child,
  });

  @override
  bool updateShouldNotify(_EscopoDaCascata antigo) =>
      relogio != antigo.relogio || intervalo != antigo.intervalo;
}

/// Elemento que entra aparecendo e subindo um pouco, na posição [ordem] da
/// [Cascata] mais próxima. Fora de uma cascata, aparece pronto.
class ItemDaCascata extends StatelessWidget {
  final int ordem;
  final Widget child;

  /// Tamanho inicial (1 = sem crescer). O ícone da abertura começa menor.
  final double escalaInicial;

  const ItemDaCascata({
    super.key,
    required this.ordem,
    required this.child,
    this.escalaInicial = 1,
  });

  @override
  Widget build(BuildContext context) {
    final escopo = context
        .dependOnInheritedWidgetOfExactType<_EscopoDaCascata>();
    if (escopo == null) return child;

    final relogio = escopo.relogio;
    final total = relogio.duration!.inMicroseconds;
    final inicio =
        (escopo.intervalo * min(ordem, Animacoes.maxEmCascata)).inMicroseconds /
        total;
    final fim = min(1.0, inicio + Animacoes.duracao.inMicroseconds / total);
    final curva = Interval(inicio, fim, curve: Animacoes.curva);

    return AnimatedBuilder(
      animation: relogio,
      builder: (_, filho) {
        final t = curva.transform(relogio.value);
        // O deslocamento fica por fora: assim o toque acerta o elemento
        // onde ele está desenhado, mesmo no meio da animação. E o leitor de
        // tela o encontra mesmo antes de ele aparecer.
        return Transform.translate(
          offset: Offset(0, Animacoes.deslocamento * (1 - t)),
          child: Transform.scale(
            scale: escalaInicial + (1 - escalaInicial) * t,
            child: Opacity(
              opacity: t,
              alwaysIncludeSemantics: true,
              child: filho,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Número que conta até [valor] (de 0, na primeira vez, e do valor anterior
/// quando ele muda). O leitor de tela lê sempre o valor final.
class ContagemAnimada extends StatelessWidget {
  final int valor;
  final TextStyle? estilo;

  /// Texto mostrado para cada número (por exemplo, "150 pts").
  final String Function(int numero) formatar;

  const ContagemAnimada({
    super.key,
    required this.valor,
    this.estilo,
    this.formatar = _semFormato,
  });

  static String _semFormato(int numero) => '$numero';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: formatar(valor),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor.toDouble()),
        duration: Animacoes.desligadas(context)
            ? Duration.zero
            : Animacoes.duracaoContagem,
        curve: Animacoes.curva,
        builder: (_, numero, __) =>
            Text(formatar(numero.round()), style: estilo),
      ),
    );
  }
}

/// Barra de progresso que enche até [valor] (de 0 a 1).
class BarraDeProgressoAnimada extends StatelessWidget {
  final double valor;
  final double altura;
  final Color corDeFundo;
  final Color cor;

  const BarraDeProgressoAnimada({
    super.key,
    required this.valor,
    required this.altura,
    required this.corDeFundo,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor),
      duration: Animacoes.desligadas(context)
          ? Duration.zero
          : Animacoes.duracaoContagem,
      curve: Animacoes.curva,
      builder: (_, progresso, __) => LinearProgressIndicator(
        value: progresso,
        minHeight: altura,
        backgroundColor: corDeFundo,
        valueColor: AlwaysStoppedAnimation<Color>(cor),
      ),
    );
  }
}
