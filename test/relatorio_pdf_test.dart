import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/relatorio_pdf.dart';

/// O PDF dos Relatórios: o arquivo, o nome e o período.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('pt_BR'));

  RelatorioGeral relatorio({DateTime? inicio, DateTime? fim}) =>
      RelatorioGeral(
        inicio: inicio,
        fim: fim,
        faturamento: 72.5,
        aReceber: 17.5,
        ticketMedio: 30,
        folhaSalarial: 7950,
        totalAgendamentos: 4,
        confirmados: 1,
        cancelados: 1,
        finalizados: 2,
        faltas: 1,
        totalClientes: 3,
        pontosEmCirculacao: 60,
        porMetodo: const [
          ItemRelatorio(rotulo: 'Pix', quantidade: 2, valor: 60),
          ItemRelatorio(rotulo: 'Dinheiro', quantidade: 1, valor: 12.5),
        ],
        porServico: const [
          ItemRelatorio(rotulo: 'Corte de Cabelo', quantidade: 2, valor: 60),
          ItemRelatorio(rotulo: 'Barba', quantidade: 1, valor: 12.5),
        ],
        porBarbeiro: const [
          ItemRelatorio(rotulo: 'Carlos Eduardo', quantidade: 3, valor: 72.5),
        ],
        faturamentoNoTempo: [
          for (var dia = 1; dia <= 12; dia++)
            FaturamentoNoTempo(
              DateTime(2026, 11, dia),
              dia == 3 ? 60 : (dia == 11 ? 12.5 : 0),
            ),
        ],
      );

  test('o PDF sai inteiro, com as fontes e os gráficos', () async {
    final bytes = await gerarPdfDoRelatorio(
      relatorio(inicio: DateTime(2026, 11), fim: DateTime(2026, 12)),
      nomeDoPeriodo: 'Este mês',
      mensal: true,
      geradoEm: DateTime(2026, 11, 12, 14, 30),
    );

    final texto = latin1.decode(bytes);
    expect(texto.startsWith('%PDF-'), isTrue);
    expect(texto.trimRight().endsWith('%%EOF'), isTrue);
    // Com as fontes e os gráficos dentro, não é um arquivo vazio.
    expect(bytes.length, greaterThan(10000));
  });

  test('sem dados nos gráficos, o PDF sai do mesmo jeito', () async {
    const vazio = RelatorioGeral(
      faturamento: 0,
      aReceber: 0,
      ticketMedio: 0,
      folhaSalarial: 0,
      totalAgendamentos: 0,
      confirmados: 0,
      cancelados: 0,
      finalizados: 0,
      totalClientes: 0,
      pontosEmCirculacao: 0,
      porMetodo: [],
      porServico: [],
      porBarbeiro: [],
    );

    final bytes = await gerarPdfDoRelatorio(
      vazio,
      nomeDoPeriodo: 'Tudo',
      mensal: false,
      geradoEm: DateTime(2026, 11, 12),
    );
    expect(latin1.decode(bytes).startsWith('%PDF-'), isTrue);
  });

  test('o nome do arquivo e o período descrito', () {
    final geradoEm = DateTime(2026, 11, 12, 14, 30);
    final doMes = relatorio(
      inicio: DateTime(2026, 10),
      fim: DateTime(2026, 11),
    );
    expect(
      nomeDoArquivoDoRelatorio(doMes, geradoEm),
      'relatorio-sysbarber-2026-10.pdf',
    );
    expect(descricaoDoPeriodo(doMes), '01/10/2026 a 31/10/2026');

    final tudo = relatorio();
    expect(
      nomeDoArquivoDoRelatorio(tudo, geradoEm),
      'relatorio-sysbarber-completo-2026-11-12.pdf',
    );
    expect(descricaoDoPeriodo(tudo), 'Desde o início');
  });
}
