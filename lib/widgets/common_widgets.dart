import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/formatters.dart';
import '../theme/app_theme.dart';

/// Botão principal: pílula amarela com texto preto.
class BotaoPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool expandido;
  final IconData? icone;

  const BotaoPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.expandido = true,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(
      texto,
      textAlign: TextAlign.center,
      style: AppTheme.texto(
        size: 15,
        weight: FontWeight.w600,
        color: onPressed == null ? AppColors.muted : Colors.black,
      ),
    );
    final botao = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amarelo,
        foregroundColor: Colors.black,
        disabledBackgroundColor: AppColors.card2,
        disabledForegroundColor: AppColors.muted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18),
            const SizedBox(width: 8),
          ],
          // Com a largura toda, o texto quebra a linha em vez de estourar o
          // botão em telas estreitas. O botão compacto não tem largura
          // definida, e ali um Flexible não é permitido.
          if (expandido) Flexible(child: rotulo) else rotulo,
        ],
      ),
    );
    return expandido ? SizedBox(width: double.infinity, child: botao) : botao;
  }
}

/// Botão secundário: pílula translúcida, com contorno claro e texto branco.
class BotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool expandido;
  final IconData? icone;

  const BotaoSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.expandido = true,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(
      texto,
      textAlign: TextAlign.center,
      style: AppTheme.texto(
        size: 15,
        weight: FontWeight.w600,
        color: onPressed == null ? AppColors.muted : AppColors.text,
      ),
    );
    final botao = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.vidro,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: const StadiumBorder(),
      ),
      child: icone == null
          ? rotulo
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 18),
                const SizedBox(width: 8),
                // Como no BotaoPrincipal: com a largura toda, o texto quebra a
                // linha em vez de estourar o botão.
                if (expandido) Flexible(child: rotulo) else rotulo,
              ],
            ),
    );
    return expandido ? SizedBox(width: double.infinity, child: botao) : botao;
  }
}

/// Botão redondo translúcido (efeito vidro), para ações de ícone como
/// voltar. O fundo desfocado aparece quando há conteúdo atrás dele.
class BotaoVidro extends StatelessWidget {
  final IconData icone;
  final VoidCallback? onPressed;

  /// Texto da dica e do leitor de tela, ex.: "Voltar".
  final String dica;
  final double tamanho;
  final Color? corIcone;

  const BotaoVidro({
    super.key,
    required this.icone,
    required this.onPressed,
    required this.dica,
    this.tamanho = 44,
    this.corIcone,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: Semantics(
        button: true,
        label: dica,
        excludeSemantics: true,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: AppColors.vidro,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: tamanho,
                  height: tamanho,
                  child: Icon(
                    icone,
                    size: tamanho * 0.45,
                    color: corIcone ?? AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão padrão do app. Com [selected] ganha a borda amarela.
class Cartao extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? cor;

  const Cartao({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: padding,
          decoration: BoxDecoration(
            color: cor ?? AppColors.card,
            borderRadius: BorderRadius.circular(20),
            // A borda existe sempre (transparente quando não selecionado),
            // para o conteúdo não mudar de lugar ao selecionar.
            border: Border.all(
              color: selected ? AppColors.amarelo : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ícone de linha dentro de um círculo. Com [destaque] o fundo fica amarelo;
/// com [cor], o círculo ganha um fundo suave dessa cor (ex.: status).
class IconeCirculo extends StatelessWidget {
  final IconData icone;
  final double tamanho;
  final bool destaque;
  final Color? cor;

  const IconeCirculo({
    super.key,
    required this.icone,
    this.tamanho = 52,
    this.destaque = false,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final fundo = destaque
        ? AppColors.amarelo
        : cor?.withValues(alpha: 0.16) ?? AppColors.card2;
    final corIcone = destaque ? Colors.black : cor ?? AppColors.text;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
      child: Icon(icone, size: tamanho * 0.44, color: corIcone),
    );
  }
}

/// Atalho redondo com o nome embaixo, como as categorias da tela inicial.
class AtalhoCirculo extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;

  const AtalhoCirculo({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconeCirculo(icone: icone, tamanho: 60),
              const SizedBox(height: 8),
              Text(
                rotulo,
                textAlign: TextAlign.center,
                style: AppTheme.texto(size: 12, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílula colorida usada para status.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;

  const Etiqueta({
    super.key,
    required this.texto,
    this.cor = AppColors.amarelo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: AppTheme.texto(size: 11, weight: FontWeight.w600, color: cor),
      ),
    );
  }
}

/// Avatar circular com as iniciais. Com [large] o fundo fica amarelo.
class AvatarIniciais extends StatelessWidget {
  final String texto;
  final double tamanho;
  final bool large;

  const AvatarIniciais({
    super.key,
    required this.texto,
    this.tamanho = 48,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: large ? AppColors.amarelo : AppColors.card2,
      ),
      child: Text(
        texto,
        style: AppTheme.titulo(
          size: tamanho * 0.34,
          weight: FontWeight.w600,
          color: large ? Colors.black : AppColors.amarelo,
        ),
      ),
    );
  }
}

/// Título de seção, com uma ação opcional à direita (ex.: "Ver todos").
class TituloSecao extends StatelessWidget {
  final String texto;
  final String? acao;
  final VoidCallback? onAcao;

  const TituloSecao(this.texto, {super.key, this.acao, this.onAcao});

  @override
  Widget build(BuildContext context) {
    final titulo = Text(
      texto,
      style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
    );
    if (acao == null) return titulo;
    return Row(
      children: [
        Expanded(child: titulo),
        TextButton(
          onPressed: onAcao,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
          ),
          child: Text(acao!, style: AppTheme.texto(size: 13)),
        ),
      ],
    );
  }
}

/// Rótulo pequeno acima de um campo ou de um dado.
class RotuloCampo extends StatelessWidget {
  final String texto;

  const RotuloCampo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: AppTheme.texto(
        size: 13,
        weight: FontWeight.w500,
        color: AppColors.muted,
      ),
    );
  }
}

/// AppBar padrão: título centralizado e o voltar num botão translúcido.
class BarberAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final List<Widget>? acoes;
  final bool mostrarVoltar;

  const BarberAppBar({
    super.key,
    required this.titulo,
    this.acoes,
    this.mostrarVoltar = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final podeVoltar =
        mostrarVoltar && (ModalRoute.of(context)?.canPop ?? false);
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      leadingWidth: 68,
      leading: podeVoltar
          ? Center(
              child: BotaoVidro(
                icone: Icons.arrow_back_ios_new_rounded,
                dica: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      title: Text(titulo),
      actions: acoes == null ? null : [...acoes!, const SizedBox(width: 12)],
    );
  }
}

/// Barra de navegação inferior flutuante e translúcida. A opção atual fica
/// numa pílula amarela, que desliza até a opção tocada.
class BarraNavegacao extends StatelessWidget {
  final int atual;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> itens;

  /// Duração das animações da barra (e da troca de aba, na área principal).
  static const duracao = Duration(milliseconds: 320);
  static const curva = Curves.easeOutCubic;

  const BarraNavegacao({
    super.key,
    required this.atual,
    required this.onTap,
    required this.itens,
  });

  @override
  Widget build(BuildContext context) {
    // Posição da pílula de -1 (primeira opção) a 1 (última).
    final posicao = itens.length < 2
        ? 0.0
        : -1 + 2 * atual / (itens.length - 1);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.card2.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(posicao, 0),
                      duration: duracao,
                      curve: curva,
                      child: FractionallySizedBox(
                        widthFactor: 1 / itens.length,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: ShapeDecoration(
                            color: AppColors.amarelo,
                            shape: StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < itens.length; i++)
                        Expanded(child: _item(i)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final selecionado = i == atual;
    return Semantics(
      button: true,
      selected: selecionado,
      label: itens[i].$2,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(i),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // A cor acompanha a pílula: preta em cima dela, cinza fora.
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: selecionado ? Colors.black : AppColors.muted,
            ),
            duration: duracao,
            curve: curva,
            builder: (_, cor, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selecionado ? 1.12 : 1,
                  duration: duracao,
                  curve: curva,
                  child: Icon(itens[i].$1, size: 22, color: cor),
                ),
                const SizedBox(height: 2),
                Text(
                  itens[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.texto(
                    size: 11,
                    weight: selecionado ? FontWeight.w600 : FontWeight.w500,
                    color: cor ?? AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abas da área principal. Cada perfil tem as suas (ver `HomeScreen`): o
/// cliente, Início, Serviços, Agenda e Perfil; o administrador, Painel,
/// Agenda (a geral), Relatórios e Perfil; o barbeiro, Agenda e Perfil.
enum Aba { inicio, servicos, agenda, perfil, painel, relatorios }

/// Liga as abas da área principal à barra de navegação: uma tela que está
/// numa aba usa [trocar] ou [abrir] para mudar de aba em vez de abrir uma
/// tela nova por cima.
class NavegacaoPrincipal extends InheritedWidget {
  /// As abas do perfil logado.
  final Set<Aba> abas;
  final ValueChanged<Aba> irParaAba;

  const NavegacaoPrincipal({
    super.key,
    required this.abas,
    required this.irParaAba,
    required super.child,
  });

  /// Troca para a [aba] quando a tela está na área principal e o perfil tem
  /// essa aba. Devolve `false` quando não trocou (a tela foi aberta por cima).
  static bool trocar(BuildContext context, Aba aba) {
    final navegacao = context
        .getInheritedWidgetOfExactType<NavegacaoPrincipal>();
    if (navegacao == null || !navegacao.abas.contains(aba)) return false;
    navegacao.irParaAba(aba);
    return true;
  }

  /// Troca para a [aba] ou, fora da área principal, abre a [rota] por cima.
  static Future<void> abrir(BuildContext context, Aba aba, String rota) async {
    if (trocar(context, aba)) return;
    await Navigator.of(context).pushNamed(rota);
  }

  @override
  bool updateShouldNotify(NavegacaoPrincipal oldWidget) =>
      irParaAba != oldWidget.irParaAba || abas != oldWidget.abas;
}

/// Estado vazio reutilizado nas listagens.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconeCirculo(icone: icone, tamanho: 76, cor: AppColors.amarelo),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppTheme.titulo(size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícones que o administrador escolhe para um serviço: o valor gravado na
/// coluna `icone` do banco (um emoji, como nos dados de exemplo), o ícone de
/// linha que a tela mostra e o nome da opção.
const List<(String, IconData, String)> iconesDeServico = [
  ('✂️', Icons.content_cut_rounded, 'Corte'),
  ('🪒', Icons.face_6_outlined, 'Barba'),
  ('💈', Icons.workspace_premium_outlined, 'Combo'),
  ('💆', Icons.water_drop_outlined, 'Hidratação'),
  ('🎨', Icons.palette_outlined, 'Coloração'),
];

/// Ícone de linha de um serviço a partir do valor gravado no banco. Um valor
/// fora da lista (gravado antes dela, por exemplo) mostra a tesoura.
IconData iconeDoServico(String icone) {
  for (final opcao in iconesDeServico) {
    if (opcao.$1 == icone) return opcao.$2;
  }
  return Icons.content_cut_rounded;
}

/// Duas colunas cujas linhas crescem com o conteúdo.
///
/// Substitui `GridView.count` com proporção fixa: com a fonte do sistema
/// aumentada (acessibilidade), o conteúdo não cabia na célula de altura
/// fixa e estourava. Aqui cada linha tem a altura do card mais alto.
class GradeDuasColunas extends StatelessWidget {
  final List<Widget> filhos;
  final double espaco;

  const GradeDuasColunas({super.key, required this.filhos, this.espaco = 12});

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    for (var i = 0; i < filhos.length; i += 2) {
      if (i > 0) linhas.add(SizedBox(height: espaco));
      linhas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: filhos[i]),
              SizedBox(width: espaco),
              Expanded(
                child: i + 1 < filhos.length
                    ? filhos[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: linhas,
    );
  }
}

/// Estado de erro de uma tela que não conseguiu carregar os dados.
///
/// Substitui o carregamento eterno: diz o que houve e oferece tentar de novo.
class EstadoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const EstadoErro({
    super.key,
    required this.mensagem,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconeCirculo(
              icone: Icons.error_outline_rounded,
              tamanho: 76,
              cor: AppColors.red,
            ),
            const SizedBox(height: 18),
            Text(
              'Algo deu errado',
              style: AppTheme.titulo(size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: AppTheme.texto(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: BotaoSecundario(
                texto: 'Tentar novamente',
                onPressed: onTentarNovamente,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensagens padronizadas de feedback.
void mostrarErro(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: AppTheme.texto(size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
}

void mostrarSucesso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: AppTheme.texto(size: 13, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
}

void mostrarInfo(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.card2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          mensagem,
          style: AppTheme.texto(size: 13, color: AppColors.text),
        ),
      ),
    );
}

/// O administrador libera uma nova senha no balcão (regra de negócio 16),
/// para um cliente ou um barbeiro ([quem]: "o cliente" ou "o barbeiro"):
/// confirma, gera o código provisório com [liberar] e o mostra uma vez só.
Future<void> liberarNovaSenhaNoBalcao(
  BuildContext context, {
  required String nome,
  required String email,
  required String quem,
  required int horas,
  required Future<({bool sucesso, String? erro, String? codigo})> Function()
  liberar,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Liberar nova senha?', style: AppTheme.titulo(size: 18)),
      content: Text(
        'Confira se quem pediu é mesmo $nome. O app vai gerar um '
        'código provisório, que vale por $horas horas e uma vez só. Com '
        'ele no lugar da senha, $quem entra e cria uma senha nova.',
        style: AppTheme.texto(size: 13, color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancelar',
            style: AppTheme.texto(size: 13, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Liberar',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmou != true || !context.mounted) return;

  final r = await liberar();
  if (!context.mounted) return;
  if (!r.sucesso) {
    mostrarErro(context, r.erro ?? 'Não foi possível liberar a nova senha');
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Código provisório', style: AppTheme.titulo(size: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r.codigo!,
            textAlign: TextAlign.center,
            // Sem serifa: os algarismos ficam da mesma altura, mais fáceis
            // de ditar.
            style: AppTheme.texto(
              size: 32,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Entregue este código a $nome. No login, $quem usa o '
            'e-mail $email e este código no lugar da senha, e o app '
            'pede uma senha nova. Vale por $horas horas, uma vez só, e não '
            'aparece de novo.',
            style: AppTheme.texto(size: 13, color: AppColors.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            'Entendi',
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Formata valores no padrão brasileiro: `R$ 2.800,00`, `-R$ 27,50`.
///
/// Usa a mesma formatação dos campos de valor (com separador de milhar) e
/// arredonda pelos centavos, evitando resíduos de ponto flutuante.
String formatarReal(double valor) {
  final centavos = (valor * 100).round();
  final texto = 'R\$ ${formatarMoedaDeCentavos(centavos.abs())}';
  return centavos < 0 ? '-$texto' : texto;
}

/// Esconde o meio do telefone, ex.: `(67) 98888-1234` → `(67) •••••-1234`.
/// Um número fora do padrão (menos de 10 dígitos) volta como veio.
String mascararTelefone(String telefone) {
  final d = telefone.replaceAll(RegExp(r'\D'), '');
  if (d.length < 10) return telefone;
  final meio = '•' * (d.length - 6);
  return '(${d.substring(0, 2)}) $meio-${d.substring(d.length - 4)}';
}

/// Esconde parte do e-mail, ex.: `lucas.martins@email.com` →
/// `l•••s@email.com`. Um texto sem `@` volta como veio.
String mascararEmail(String email) {
  final arroba = email.indexOf('@');
  if (arroba < 1) return email;
  final usuario = email.substring(0, arroba);
  final dominio = email.substring(arroba);
  final fim = usuario.length > 2 ? usuario[usuario.length - 1] : '';
  return '${usuario[0]}•••$fim$dominio';
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// Data por extenso em pt_BR, ex.: "Segunda, 11 de agosto".
/// Se os dados de locale não estiverem carregados, cai no formato numérico.
String formatarDataExtenso(DateTime d) {
  try {
    final texto = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
    return texto[0].toUpperCase() + texto.substring(1);
  } catch (_) {
    return formatarDataCurta(d);
  }
}

/// Data numérica, ex.: "11/08/2026".
String formatarDataCurta(DateTime d) =>
    '${_doisDigitos(d.day)}/${_doisDigitos(d.month)}/${d.year}';

/// Hora, ex.: "09:30".
String formatarHora(DateTime d) =>
    '${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}';

/// Data e hora juntas, ex.: "11/08/2026 às 09:30".
String formatarDataHora(DateTime d) =>
    '${formatarDataCurta(d)} às ${formatarHora(d)}';

/// Abreviação do dia da semana em caixa alta, ex.: "SEG".
String abreviacaoDiaSemana(DateTime d) {
  const dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  return dias[d.weekday - 1];
}
