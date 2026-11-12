import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Uma lista que vem do banco em páginas de
/// [DatabaseService.tamanhoDaPagina] itens: a tela mostra o que já veio e,
/// ao chegar ao fim ([CarregarAoChegarNoFim]), pede a próxima página.
///
/// [buscar] recebe o deslocamento e o limite da página. [chave] identifica
/// cada item: um item que entrou no começo da lista entre uma página e
/// outra empurra os seguintes, e o que vier repetido é descartado.
class Paginacao<T> {
  Paginacao({required this.buscar, required this.chave});

  final Future<List<T>> Function(int deslocamento, int limite) buscar;
  final Object? Function(T item) chave;

  /// O que já foi carregado, na ordem do banco.
  final List<T> itens = [];

  /// Ainda há páginas para buscar: a última veio cheia.
  bool get temMais => _temMais;
  bool _temMais = true;

  bool get carregando => _carregando;
  bool _carregando = false;

  /// Quantos itens o banco já entregou, contando os repetidos descartados.
  int _deslocamento = 0;

  /// Muda a cada [reiniciar]: uma página pedida antes dele é descartada.
  int _geracao = 0;

  /// Volta à primeira página e a busca.
  Future<void> reiniciar() {
    _geracao++;
    itens.clear();
    _deslocamento = 0;
    _temMais = true;
    _carregando = false;
    return carregarMais();
  }

  /// Busca a próxima página, se ainda há uma e nenhuma está a caminho.
  /// Devolve `true` se a lista mudou.
  Future<bool> carregarMais() async {
    if (_carregando || !_temMais) return false;
    final geracao = _geracao;
    _carregando = true;
    try {
      const limite = DatabaseService.tamanhoDaPagina;
      final pagina = await buscar(_deslocamento, limite);
      if (geracao != _geracao) return false;
      _deslocamento += pagina.length;
      _temMais = pagina.length == limite;
      final vistos = {for (final item in itens) chave(item)};
      itens.addAll(pagina.where((item) => !vistos.contains(chave(item))));
      return true;
    } finally {
      if (geracao == _geracao) _carregando = false;
    }
  }
}

/// Avisa ([aoChegarNoFim]) quando a rolagem da lista vertical [child] chega
/// perto do fim, e também quando a lista ainda não enche a tela: assim a
/// próxima página vem antes de a pessoa precisar dela.
class CarregarAoChegarNoFim extends StatelessWidget {
  const CarregarAoChegarNoFim({
    super.key,
    required this.aoChegarNoFim,
    required this.child,
  });

  final VoidCallback aoChegarNoFim;
  final Widget child;

  /// A quantos pixels do fim a próxima página é pedida.
  static const _antesDoFim = 400.0;

  bool _conferir(ScrollMetrics m, int profundidade) {
    if (profundidade == 0 &&
        m.axis == Axis.vertical &&
        m.extentAfter < _antesDoFim) {
      aoChegarNoFim();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // As métricas mudam na primeira montagem e a cada página que chega; a
    // rolagem, quando a pessoa desce.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _conferir(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _conferir(n.metrics, n.depth),
        child: child,
      ),
    );
  }
}

/// O fim de uma lista paginada: o indicador enquanto a próxima página
/// chega. Sem mais páginas, não ocupa espaço.
class FimDaPaginacao extends StatelessWidget {
  const FimDaPaginacao({super.key, required this.temMais});

  final bool temMais;

  @override
  Widget build(BuildContext context) {
    if (!temMais) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.amarelo,
          ),
        ),
      ),
    );
  }
}
