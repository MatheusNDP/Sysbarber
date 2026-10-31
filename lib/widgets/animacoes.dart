import 'dart:math' show cos, min, pi;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

  /// O corte da abertura do app: uma pausa curta, a tesoura atravessando a
  /// tela e as duas metades se abrindo.
  static const duracaoCorte = Duration(milliseconds: 1600);

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

/// Abertura do app: uma tesoura atravessa a tela na horizontal, deixando um
/// risco amarelo, e as duas metades da tela se abrem, mostrando o [child].
/// O [child] só é montado quando as metades começam a se abrir, para a
/// cascata dele começar nessa hora. Com "Remover animações", ele aparece
/// direto.
class CorteDeAbertura extends StatefulWidget {
  final Widget child;

  /// Chamado quando as metades terminam de se abrir (ou logo, sem animação).
  final VoidCallback? aoTerminar;

  const CorteDeAbertura({super.key, required this.child, this.aoTerminar});

  /// A tesoura espera um pouco antes de entrar: do Android 12 em diante, a
  /// tela de abertura do sistema ainda some por cima do app nesse começo.
  static const inicioDoCorte = 0.2;

  /// Parte do tempo em que a tesoura termina de atravessar a tela.
  static const fimDoCorte = 0.62;

  /// A partir daqui, as metades se abrem e o [child] aparece.
  static const inicioDaAbertura = 0.66;

  @override
  State<CorteDeAbertura> createState() => _CorteDeAberturaState();
}

class _CorteDeAberturaState extends State<CorteDeAbertura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _relogio;

  @override
  void initState() {
    super.initState();
    _relogio =
        AnimationController(vsync: this, duration: Animacoes.duracaoCorte)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.aoTerminar?.call();
          });
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _relogio,
      builder: (_, conteudo) {
        final t = _relogio.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (t >= CorteDeAbertura.inicioDaAbertura)
              KeyedSubtree(key: const ValueKey('conteudo'), child: conteudo!),
            if (t < 1)
              IgnorePointer(
                key: const ValueKey('corte'),
                child: ExcludeSemantics(child: _TesouraCortando(progresso: t)),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Desenho do corte em [progresso] (de 0 a 1): as metades da tela, o risco
/// e a tesoura.
class _TesouraCortando extends StatelessWidget {
  final double progresso;

  const _TesouraCortando({required this.progresso});

  static const _tamanhoDaTesoura = 40.0;
  static const _espessuraDoRisco = 2.0;

  /// Quantas vezes a tesoura fecha enquanto atravessa a tela.
  static const _cortes = 4;

  @override
  Widget build(BuildContext context) {
    final corte =
        ((progresso - CorteDeAbertura.inicioDoCorte) /
                (CorteDeAbertura.fimDoCorte - CorteDeAbertura.inicioDoCorte))
            .clamp(0.0, 1.0);
    final abertura = Curves.easeInOutCubic.transform(
      ((progresso - CorteDeAbertura.inicioDaAbertura) /
              (1 - CorteDeAbertura.inicioDaAbertura))
          .clamp(0.0, 1.0),
    );
    // 0 com a tesoura aberta, 1 com ela fechada.
    final fechada = (1 - cos(corte * 2 * pi * _cortes)) / 2;

    return LayoutBuilder(
      builder: (_, limites) {
        final largura = limites.maxWidth;
        final meio = limites.maxHeight / 2;
        final afastamento = meio * abertura;
        // A ponta da tesoura entra pela esquerda e sai pela direita.
        final x =
            -_tamanhoDaTesoura +
            (largura + 2 * _tamanhoDaTesoura) *
                Curves.easeInOut.transform(corte);
        // Depois do corte, o risco vira a borda das duas metades.
        final borda = corte < 1
            ? Colors.transparent
            : AppColors.amarelo.withValues(alpha: 1 - abertura);

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -afastamento,
              height: meio,
              child: _Metade(borda: borda, bordaEmCima: false),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: meio + afastamento,
              height: meio,
              child: _Metade(borda: borda, bordaEmCima: true),
            ),
            if (corte < 1) ...[
              Positioned(
                left: 0,
                top: meio - _espessuraDoRisco / 2,
                width: x.clamp(0.0, largura),
                height: _espessuraDoRisco,
                child: const ColoredBox(color: AppColors.amarelo),
              ),
              Positioned(
                left: x - _tamanhoDaTesoura / 2,
                top: meio - _tamanhoDaTesoura / 2,
                width: _tamanhoDaTesoura,
                height: _tamanhoDaTesoura,
                child: Transform.scale(
                  scaleX: 1,
                  scaleY: 1 - 0.35 * fechada,
                  child: const Icon(
                    Icons.content_cut_rounded,
                    size: _tamanhoDaTesoura,
                    color: AppColors.amarelo,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Uma das metades da tela, com a borda do corte.
class _Metade extends StatelessWidget {
  final Color borda;
  final bool bordaEmCima;

  const _Metade({required this.borda, required this.bordaEmCima});

  @override
  Widget build(BuildContext context) {
    final linha = BorderSide(
      color: borda,
      width: _TesouraCortando._espessuraDoRisco / 2,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: bordaEmCima ? Border(top: linha) : Border(bottom: linha),
      ),
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
