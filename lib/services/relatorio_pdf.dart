import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/graficos_relatorio.dart';

/// O relatório da tela de Relatórios em PDF, com os mesmos números e
/// gráficos (desenhados pela biblioteca `pdf`), para o administrador
/// compartilhar.

/// Cores dos itens no papel branco, na mesma ordem da tela
/// ([coresDosGraficos]): o cinza-claro da tela some no branco.
final _coresNoPapel = [
  PdfColor.fromHex('#FFD23F'),
  PdfColor.fromHex('#4A4A4A'),
  PdfColor.fromHex('#2E9E5B'),
  PdfColor.fromHex('#3B82F6'),
  PdfColor.fromHex('#F97316'),
];

PdfColor _corDoItem(int i) => _coresNoPapel[i % _coresNoPapel.length];

final _amarelo = PdfColor.fromHex('#FFD23F');
final _cinza = PdfColor.fromHex('#6B6B6B');
final _fundo = PdfColor.fromHex('#F3F3F3');

/// "01/11/2026 a 30/11/2026", ou "Desde o início", sem período.
String descricaoDoPeriodo(RelatorioGeral r) {
  final inicio = r.inicio;
  final fim = r.fim;
  if (inicio == null || fim == null) return 'Desde o início';
  final ultimoDia = fim.subtract(const Duration(days: 1));
  return '${formatarDataCurta(inicio)} a ${formatarDataCurta(ultimoDia)}';
}

/// Nome do arquivo, ex.: `relatorio-sysbarber-2026-11.pdf` (o mês do
/// período) ou `relatorio-sysbarber-completo-2026-11-12.pdf` (sem período,
/// com o dia em que foi gerado).
String nomeDoArquivoDoRelatorio(RelatorioGeral r, DateTime geradoEm) {
  String dois(int n) => n.toString().padLeft(2, '0');
  final inicio = r.inicio;
  return inicio == null
      ? 'relatorio-sysbarber-completo-${geradoEm.year}-'
          '${dois(geradoEm.month)}-${dois(geradoEm.day)}.pdf'
      : 'relatorio-sysbarber-${inicio.year}-${dois(inicio.month)}.pdf';
}

/// Entrega o PDF pronto: os testes trocam por um falso.
typedef CompartilharPdf = Future<void> Function(Uint8List bytes, String nome);

/// Salva o PDF numa pasta temporária do app e abre o compartilhar do
/// Android (WhatsApp, e-mail, Drive ou salvar no aparelho), como o convite
/// do barbeiro.
Future<void> compartilharPdfPeloAndroid(Uint8List bytes, String nome) async {
  final pasta = await getTemporaryDirectory();
  final arquivo = File(p.join(pasta.path, nome));
  await arquivo.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(arquivo.path, mimeType: 'application/pdf')],
      subject: 'Relatório SysBarber',
    ),
  );
}

/// Gera o PDF do relatório [r], do período chamado [nomeDoPeriodo] na tela
/// ("Este mês", "Mês passado" ou "Tudo"). Com [mensal], entra o "Resultado
/// do mês", como na tela.
Future<Uint8List> gerarPdfDoRelatorio(
  RelatorioGeral r, {
  required String nomeDoPeriodo,
  required bool mensal,
  required DateTime geradoEm,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'),
  );
  final negrito = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Montserrat-Bold.ttf'),
  );
  final documento = pw.Document(
    title: 'Relatório SysBarber — $nomeDoPeriodo',
    author: 'SysBarber',
    theme: pw.ThemeData.withFont(base: regular, bold: negrito),
  );

  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _cinza),
        ),
      ),
      build: (_) => [
        _cabecalho(r, nomeDoPeriodo, geradoEm),
        pw.SizedBox(height: 16),
        _destaque(r),
        _secao('Financeiro', [
          _indicadores([
            ('A receber', formatarReal(r.aReceber), 'pendente hoje'),
            (
              'Ticket médio',
              formatarReal(r.ticketMedio),
              'por atendimento pago',
            ),
            (
              'Folha salarial',
              formatarReal(r.folhaSalarial),
              'mensal da equipe',
            ),
            if (mensal)
              (
                'Resultado do mês',
                formatarReal(r.faturamento - r.folhaSalarial),
                'faturamento − folha',
              ),
          ]),
        ]),
        _secao('Agendamentos', [
          _indicadores([
            ('Total', '${r.totalAgendamentos}', 'geral'),
            ('Confirmados', '${r.confirmados}', 'em aberto'),
            (
              'Cancelados',
              '${r.cancelados}',
              '${formatarPercentual(r.taxaCancelamento)} do total',
            ),
            ('Concluídos', '${r.finalizados}', 'atendimentos realizados'),
            ('Faltas', '${r.faltas}', 'cliente não compareceu'),
          ]),
        ]),
        _secao('Clientes e fidelidade', [
          _indicadores([
            (
              'Clientes',
              '${r.totalClientes}',
              r.totalClientes == 1 ? 'cadastrado' : 'cadastrados',
            ),
            ('Pontos ativos', '${r.pontosEmCirculacao}', 'em circulação'),
          ]),
        ]),
        _secao('Faturamento no tempo', [
          pw.Text(
            r.faturamentoPorMes ? 'Por mês' : 'Por dia',
            style: pw.TextStyle(fontSize: 9, color: _cinza),
          ),
          pw.SizedBox(height: 8),
          _graficoDoFaturamento(r),
        ]),
        _secao('Por forma de pagamento', [_graficoDaRosca(r.porMetodo)]),
        _secao('Serviços mais procurados', [_barrasHorizontais(r.porServico)]),
        _secao('Barbeiros mais requisitados', [
          _barrasHorizontais(r.porBarbeiro),
        ]),
      ],
    ),
  );
  return documento.save();
}

pw.Widget _cabecalho(
  RelatorioGeral r,
  String nomeDoPeriodo,
  DateTime geradoEm,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Text(
            'Sys',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: _amarelo,
            ),
          ),
          pw.Text(
            'Barber',
            style: const pw.TextStyle(
                fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Text(
            'Relatório',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Período: $nomeDoPeriodo (${descricaoDoPeriodo(r)})',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.Text(
        'Gerado em ${formatarDataHora(geradoEm)}',
        style: pw.TextStyle(fontSize: 10, color: _cinza),
      ),
    ],
  );
}

pw.Widget _destaque(RelatorioGeral r) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: _amarelo,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          'Faturamento líquido',
          style:
              const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          formatarReal(r.faturamento),
          style:
              const pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Pagamentos e multas recebidos, menos estornos',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
}

/// Uma seção com o título, que não se divide entre páginas: se ela não
/// couber no fim de uma, vai inteira para a próxima, e o título não fica
/// separado do gráfico.
pw.Widget _secao(String titulo, List<pw.Widget> conteudo) {
  return pw.Inseparable(
    child: _conteudoDaSecao(titulo, conteudo),
  );
}

pw.Widget _conteudoDaSecao(String titulo, List<pw.Widget> conteudo) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style:
              const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...conteudo,
      ],
    ),
  );
}

/// Os indicadores em duas colunas, como a grade da tela.
pw.Widget _indicadores(List<(String, String, String)> itens) {
  pw.Widget celula((String, String, String)? item) => pw.Container(
        margin: const pw.EdgeInsets.all(3),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: item == null ? null : _fundo,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: item == null
            ? pw.SizedBox()
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.$1,
                      style: pw.TextStyle(fontSize: 9, color: _cinza)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.$2,
                    style: const pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(item.$3,
                      style: pw.TextStyle(fontSize: 8, color: _cinza)),
                ],
              ),
      );
  return pw.Table(
    children: [
      for (var i = 0; i < itens.length; i += 2)
        pw.TableRow(
          children: [
            celula(itens[i]),
            celula(i + 1 < itens.length ? itens[i + 1] : null),
          ],
        ),
    ],
  );
}

pw.Widget _semDados(String texto) =>
    pw.Text(texto, style: pw.TextStyle(fontSize: 10, color: _cinza));

/// Uma linha da legenda: a cor, o nome, a quantidade e o valor.
pw.Widget _linhaDaLegenda(PdfColor cor, ItemRelatorio item) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(color: cor, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(item.rotulo, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Text(
          '${item.quantidade}× · ${formatarReal(item.valor)}',
          style:
              const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _graficoDoFaturamento(RelatorioGeral r) {
  final pontos = r.faturamentoNoTempo;
  final maior = pontos.fold<double>(0, (m, p) => max(m, p.valor));
  if (maior <= 0) return _semDados('Sem faturamento no período');
  final passo = passoDosRotulos(pontos.length);
  final topo = (maior * 1.15).ceilToDouble();
  return pw.SizedBox(
    height: 170,
    child: pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          [
            for (var i = 0; i < pontos.length; i++)
              i % passo == 0
                  ? rotuloDoFaturamento(pontos[i], porMes: r.faturamentoPorMes)
                  : '',
          ],
          marginStart: 12,
          marginEnd: 12,
          textStyle: pw.TextStyle(fontSize: 7, color: _cinza),
        ),
        yAxis: pw.FixedAxis(
          [0, topo / 3, 2 * topo / 3, topo],
          format: (v) => v.round().toString(),
          divisions: true,
          textStyle: pw.TextStyle(fontSize: 7, color: _cinza),
        ),
      ),
      datasets: [
        pw.BarDataSet(
          color: _amarelo,
          width: pontos.length > 20 ? 5 : 10,
          data: [
            for (var i = 0; i < pontos.length; i++)
              pw.PointChartValue(i.toDouble(), max(0, pontos[i].valor)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _graficoDaRosca(List<ItemRelatorio> itens) {
  if (itens.isEmpty) return _semDados('Ainda sem dados suficientes');
  final total = itens.fold<double>(0, (t, i) => t + max(0, i.valor));
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      if (total > 0)
        pw.SizedBox(
          width: 130,
          height: 130,
          child: pw.Chart(
            grid: pw.PieGrid(),
            datasets: [
              for (var i = 0; i < itens.length; i++)
                pw.PieDataSet(
                  value: max(0, itens[i].valor),
                  color: _corDoItem(i),
                  innerRadius: 34,
                ),
            ],
          ),
        ),
      pw.SizedBox(width: 20),
      pw.Expanded(
        child: pw.Column(
          children: [
            for (var i = 0; i < itens.length; i++)
              _linhaDaLegenda(_corDoItem(i), itens[i]),
          ],
        ),
      ),
    ],
  );
}

/// Barras horizontais, da maior para a menor, e a legenda embaixo.
pw.Widget _barrasHorizontais(List<ItemRelatorio> itens) {
  final maior = itens.fold<int>(0, (m, i) => max(m, i.quantidade));
  if (itens.isEmpty || maior == 0) {
    return _semDados('Ainda sem dados suficientes');
  }
  return pw.Column(
    children: [
      for (var i = 0; i < itens.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.LayoutBuilder(
            builder: (_, limites) => pw.Stack(
              children: [
                pw.Container(
                  height: 10,
                  width: limites!.maxWidth,
                  decoration: pw.BoxDecoration(
                    color: _fundo,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
                pw.Container(
                  height: 10,
                  width: limites.maxWidth * itens[i].quantidade / maior,
                  decoration: pw.BoxDecoration(
                    color: _corDoItem(i),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      pw.SizedBox(height: 4),
      for (var i = 0; i < itens.length; i++)
        _linhaDaLegenda(_corDoItem(i), itens[i]),
    ],
  );
}
