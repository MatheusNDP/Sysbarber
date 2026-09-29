import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/formatters.dart';
import '../theme/app_theme.dart';

/// Botão principal: preenchido em dourado com texto preto.
class GoldButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool expandido;
  final IconData? icone;

  const GoldButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.expandido = true,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final botao = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: AppColors.card2,
        disabledForegroundColor: AppColors.muted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icone != null) ...[Icon(icone, size: 18), const SizedBox(width: 8)],
          Text(
            texto,
            style: AppTheme.sans(
              size: 14,
              weight: FontWeight.w700,
              color: onPressed == null ? AppColors.muted : Colors.black,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
    return expandido ? SizedBox(width: double.infinity, child: botao) : botao;
  }
}

/// Botão secundário: apenas contorno dourado.
class GoldOutlineButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool expandido;

  const GoldOutlineButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.expandido = true,
  });

  @override
  Widget build(BuildContext context) {
    final botao = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        texto,
        style: AppTheme.sans(
          size: 14,
          weight: FontWeight.w700,
          color: AppColors.gold,
          letterSpacing: 1,
        ),
      ),
    );
    return expandido ? SizedBox(width: double.infinity, child: botao) : botao;
  }
}

/// Cartão padrão do app. Com [selected] a borda vira dourada.
class GoldCard extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? cor;

  const GoldCard({
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: padding,
          decoration: BoxDecoration(
            color: cor ?? AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pílula colorida usada para status.
class GoldBadge extends StatelessWidget {
  final String texto;
  final Color cor;

  const GoldBadge({super.key, required this.texto, this.cor = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(
        texto,
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w700,
          color: cor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Avatar circular. Com [large] recebe o gradiente dourado.
class GoldAvatar extends StatelessWidget {
  final String texto;
  final double tamanho;
  final bool large;

  const GoldAvatar({
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
        gradient: large
            ? const LinearGradient(
                colors: [AppColors.goldLight, AppColors.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.card2, AppColors.card],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: large ? null : Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Text(
        texto,
        style: AppTheme.serif(
          size: tamanho * 0.36,
          color: large ? Colors.black : AppColors.gold,
        ),
      ),
    );
  }
}

/// Linha de 2px com degradê dourado → transparente.
class GoldDivider extends StatelessWidget {
  final double largura;

  const GoldDivider({super.key, this.largura = double.infinity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      width: largura,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold, Colors.transparent],
        ),
      ),
    );
  }
}

/// Rótulo de seção em caixa alta.
class SectionLabel extends StatelessWidget {
  final String texto;

  const SectionLabel(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: AppTheme.sans(
        size: 11,
        weight: FontWeight.w700,
        color: AppColors.gold,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// AppBar padrão com título serifado dourado.
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: mostrarVoltar,
      title: Text(
        titulo,
        style: AppTheme.serif(size: 20, color: AppColors.gold),
      ),
      actions: acoes,
    );
  }
}

/// Estado vazio reutilizado nas listagens.
class EstadoVazio extends StatelessWidget {
  final String icone;
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
            Text(icone, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(titulo, style: AppTheme.serif(size: 18)),
            const SizedBox(height: 8),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
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
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Algo deu errado', style: AppTheme.serif(size: 18)),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: GoldOutlineButton(
                texto: 'TENTAR NOVAMENTE',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: AppTheme.sans(size: 13, color: Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: AppTheme.sans(size: 13, color: Colors.black),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          mensagem,
          style: AppTheme.sans(size: 13, color: AppColors.text),
        ),
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
