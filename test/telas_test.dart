import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/screens/agendamentos_screen.dart';
import 'package:sysbarber/screens/horario_screen.dart';
import 'package:sysbarber/screens/login_screen.dart';
import 'package:sysbarber/screens/servicos_screen.dart';
import 'package:sysbarber/services/auth_service.dart';
import 'package:sysbarber/services/booking_flow.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/senhas.dart';
import 'package:sysbarber/widgets/common_widgets.dart';

/// Testes de tela: o que o usuário vê quando os dados chegam — e quando não
/// chegam.
void main() {
  final service = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Senhas.iteracoes = 1000;
  });

  tearDown(() async => service.resetarParaTeste());

  /// Abre um banco em memória com o seed (fora do relógio falso do teste).
  Future<Database> bancoComSeed(WidgetTester tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: service.criarSchema,
          onConfigure: DatabaseService.configurar,
        ),
      );
    });
    return db;
  }

  /// Monta a tela e deixa as consultas ao banco terminarem.
  Future<void> abrir(WidgetTester tester, Widget tela) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: tela));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('Serviços lista o catálogo do banco', (tester) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));

    await abrir(tester, const ServicosScreen());

    expect(find.text('Corte + Barba'), findsOneWidget);
    expect(find.byType(EstadoErro), findsNothing);
  });

  testWidgets('falha ao carregar mostra erro com "tentar novamente", e não '
      'um carregamento eterno', (tester) async {
    final db = await bancoComSeed(tester);
    await tester.runAsync(db.close);
    service.injetarBancoParaTeste(db);

    await abrir(tester, const ServicosScreen());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(EstadoErro), findsOneWidget);
    expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
    // Nenhum detalhe técnico na tela.
    expect(find.textContaining('database_closed'), findsNothing);
  });

  testWidgets('"tentar novamente" recarrega a tela', (tester) async {
    final fechado = await bancoComSeed(tester);
    await tester.runAsync(fechado.close);
    service.injetarBancoParaTeste(fechado);
    await abrir(tester, const ServicosScreen());
    expect(find.byType(EstadoErro), findsOneWidget);

    // O banco volta a responder e o usuário tenta de novo.
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(EstadoErro), findsNothing);
    expect(find.text('Corte + Barba'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Correção 17 — layout e acessibilidade
  // -------------------------------------------------------------------------

  /// Tela de celular pequeno (320 pt de largura).
  void celularPequeno(WidgetTester tester) {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('a grade de indicadores cresce com a fonte do sistema',
      (tester) async {
    celularPequeno(tester);
    Widget card(String n) => GoldCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋'),
          Text(n),
          const Text('Agendamentos'),
          const Text('12 no total'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              children: [
                GradeDuasColunas(filhos: [card('1'), card('2'), card('3')]),
              ],
            ),
          ),
        ),
      ),
    );

    // Com proporção fixa (GridView.count) o conteúdo estourava a célula.
    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('nome longo não estoura o card do agendamento', (tester) async {
    celularPequeno(tester);
    SharedPreferences.setMockInitialValues({});
    final db = await bancoComSeed(tester);
    service.injetarBancoParaTeste(db);

    await tester.runAsync(() async {
      final idBarbeiro = await service.cadastrarBarbeiro(
        const Barbeiro(
          nome: 'Carlos Eduardo de Albuquerque Figueiredo Santos Junior',
          especialidade: 'Barba',
          avaliacao: 5,
          avaliacoes: 1,
          iniciais: 'CJ',
          salario: 2000,
        ),
      );
      final idCliente = await service.cadastrarCliente(
        Cliente(
          nome: 'Cliente',
          email: 'c@teste.com',
          telefone: '(67) 99999-0000',
          senhaHash: DatabaseService.hashSenha('senha123'),
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );
      final amanha = DateTime.now().add(const Duration(days: 1));
      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: idBarbeiro,
          idServico: 3,
          dataHora: DateTime(
            amanha.year,
            amanha.month,
            amanha.day,
            9,
          ).toIso8601String(),
        ),
      );
      await AuthService.instance.login('c@teste.com', 'senha123');
    });

    await abrir(tester, const AgendamentosScreen());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Albuquerque'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('horários e dias são anunciados como botões', (tester) async {
    final semantica = tester.ensureSemantics();
    BookingFlow.limpar(); // sem barbeiro: a tela mostra a grade base

    await abrir(tester, const HorarioScreen());

    expect(
      tester.getSemantics(find.text('09:00')),
      isSemantics(isButton: true, isSelected: false),
    );
    await tester.tap(find.text('09:00'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('09:00').first),
      isSemantics(isButton: true, isSelected: true),
    );
    semantica.dispose();
  });

  testWidgets('"Criar conta" no login é um botão de verdade', (tester) async {
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(
      tester.getSemantics(find.text('Criar conta')),
      isSemantics(isButton: true),
    );
    semantica.dispose();
  });
}
