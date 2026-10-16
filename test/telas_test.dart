import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/screens/admin_barbeiros_screen.dart';
import 'package:sysbarber/screens/admin_clientes_screen.dart';
import 'package:sysbarber/screens/admin_relatorios_screen.dart';
import 'package:sysbarber/screens/admin_screen.dart';
import 'package:sysbarber/screens/admin_servicos_screen.dart';
import 'package:sysbarber/screens/agendamentos_screen.dart';
import 'package:sysbarber/screens/horario_screen.dart';
import 'package:sysbarber/screens/login_screen.dart';
import 'package:sysbarber/screens/pagamento_screen.dart';
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

  // -------------------------------------------------------------------------
  // P03 — resgate e desistência tardia
  // -------------------------------------------------------------------------

  /// Cadastra o cliente `c@teste.com` (senha `senha123`) e devolve o id.
  Future<int> cadastrarClienteTeste() => service.cadastrarCliente(
    Cliente(
      nome: 'Cliente',
      email: 'c@teste.com',
      telefone: '(67) 99999-0000',
      senhaHash: DatabaseService.hashSenha('senha123'),
      criadoEm: DateTime.now().toIso8601String(),
    ),
  );

  /// Corte de Cabelo do cliente [idCliente] com o barbeiro 1 em [quando].
  /// Devolve o id do agendamento.
  Future<int> marcarCorte(int idCliente, DateTime quando) =>
      service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: quando.toIso8601String(),
        ),
      );

  /// Cliente `c@teste.com` com um Corte de Cabelo trocado por 500 pontos,
  /// marcado com o barbeiro 1 para [quando]. Devolve o id do agendamento.
  Future<int> resgateMarcado(DateTime quando) async {
    final idCliente = await cadastrarClienteTeste();
    await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
    final id = await marcarCorte(idCliente, quando);
    await service.resgatarPremio(
      idCliente: idCliente,
      idAgendamento: id,
      nomeServico: 'Corte de Cabelo',
    );
    return id;
  }

  testWidgets('cancelar um resgate em cima da hora avisa a perda dos pontos, '
      'e não multa em dinheiro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await resgateMarcado(DateTime.now().add(const Duration(minutes: 30)));
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await abrir(tester, const AgendamentosScreen());

    await tester.tap(find.text('Cancelar agendamento'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('500 pontos usados no resgate não serão devolvidos'),
      findsOneWidget,
    );
    expect(find.textContaining('multa'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('registrar falta num resgate avisa a perda dos pontos',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await resgateMarcado(DateTime.now().subtract(const Duration(hours: 2)));
      await AuthService.instance.login(
        'carlos.eduardo@sysbarber.com',
        'barbeiro123',
      );
    });
    await abrir(tester, const AgendamentosScreen());

    await tester.ensureVisible(find.text('Não compareceu'));
    await tester.tap(find.text('Não compareceu'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('500 pontos usados no resgate não serão devolvidos'),
      findsOneWidget,
    );
    expect(find.textContaining('multa de'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('resgate cancelado fora do prazo mostra os pontos retidos',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final amanha = DateTime.now().add(const Duration(days: 1));
      final as9 = DateTime(amanha.year, amanha.month, amanha.day, 9);
      final id = await resgateMarcado(as9);
      await service.cancelarAgendamento(
        id,
        agora: as9.subtract(const Duration(minutes: 30)),
      );
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await abrir(tester, const AgendamentosScreen());

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    // Antes aparecia "Resgatado com pontos de fidelidade", como se valesse.
    expect(find.text('500 pontos do resgate não devolvidos'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P01 — estado de erro em toda tela que carrega dados
  // -------------------------------------------------------------------------

  /// Banco já fechado: qualquer consulta falha.
  Future<void> bancoFechado(WidgetTester tester) async {
    final db = await bancoComSeed(tester);
    await tester.runAsync(db.close);
    service.injetarBancoParaTeste(db);
  }

  /// Loga o cliente `c@teste.com` e fecha o banco em seguida: a tela abre com
  /// sessão, mas toda consulta falha.
  Future<void> clienteLogadoSemBanco(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await bancoComSeed(tester);
    service.injetarBancoParaTeste(db);
    await tester.runAsync(() async {
      await cadastrarClienteTeste();
      await AuthService.instance.login('c@teste.com', 'senha123');
      await db.close();
    });
  }

  /// O banco volta a responder e o usuário toca em "Tentar novamente".
  Future<void> tentarDeNovoComBanco(WidgetTester tester) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  for (final (nome, tela) in <(String, Widget)>[
    ('o painel administrativo', const AdminScreen()),
    ('os relatórios', const AdminRelatoriosScreen()),
    ('o cadastro de serviços', const AdminServicosScreen()),
    ('o cadastro de barbeiros', const AdminBarbeirosScreen()),
    ('a lista de clientes', const AdminClientesScreen()),
  ]) {
    testWidgets('falha ao carregar $nome mostra erro com "tentar novamente"',
        (tester) async {
      await bancoFechado(tester);

      await abrir(tester, tela);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(EstadoErro), findsOneWidget);
    });
  }

  testWidgets('"tentar novamente" recarrega o painel administrativo',
      (tester) async {
    await bancoFechado(tester);
    await abrir(tester, const AdminScreen());
    expect(find.byType(EstadoErro), findsOneWidget);

    await tentarDeNovoComBanco(tester);

    expect(find.byType(EstadoErro), findsNothing);
    expect(find.text('Painel de Controle'), findsOneWidget);
  });

  testWidgets('falha ao carregar os agendamentos mostra erro, e "tentar '
      'novamente" recarrega', (tester) async {
    await clienteLogadoSemBanco(tester);

    await abrir(tester, const AgendamentosScreen());

    // Antes a lista vazia passava por "Nenhum agendamento futuro".
    expect(find.text('Nenhum agendamento futuro'), findsNothing);
    expect(find.byType(EstadoErro), findsOneWidget);

    await tentarDeNovoComBanco(tester);

    expect(find.byType(EstadoErro), findsNothing);
    expect(find.text('Nenhum agendamento futuro'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('falha ao carregar os pontos no pagamento avisa e deixa tentar '
      'de novo, sem travar o pagamento', (tester) async {
    await clienteLogadoSemBanco(tester);

    await abrir(tester, const PagamentoScreen());

    // Antes o resgate sumia sem nenhuma explicação.
    expect(find.textContaining('carregar seus pontos'), findsOneWidget);
    expect(find.text('CONFIRMAR PAGAMENTO'), findsOneWidget);

    await tentarDeNovoComBanco(tester);

    expect(find.textContaining('carregar seus pontos'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P12 — "Concluído" no lugar de "Finalizado"
  // -------------------------------------------------------------------------

  testWidgets('o barbeiro conclui o atendimento pelo botão "Concluir"',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final idCliente = await cadastrarClienteTeste();
      await marcarCorte(
        idCliente,
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await AuthService.instance.login(
        'carlos.eduardo@sysbarber.com',
        'barbeiro123',
      );
    });
    await abrir(tester, const AgendamentosScreen());

    expect(find.text('Finalizar'), findsNothing);
    await tester.ensureVisible(find.text('Concluir'));
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Concluir atendimento?'), findsOneWidget);
    expect(find.text('CONCLUIR'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('atendimento concluído aparece como "Concluído" no histórico',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final amanha = DateTime.now().add(const Duration(days: 1));
      final as9 = DateTime(amanha.year, amanha.month, amanha.day, 9);
      final id = await marcarCorte(await cadastrarClienteTeste(), as9);
      await service.finalizarAgendamento(
        id,
        agora: as9.add(const Duration(hours: 1)),
      );
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await abrir(tester, const AgendamentosScreen());

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Concluído'), findsOneWidget);
    expect(find.text('Finalizado'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('os relatórios contam os atendimentos "Concluídos"',
      (tester) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await abrir(tester, const AdminRelatoriosScreen());

    await tester.scrollUntilVisible(
      find.text('Concluídos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Concluídos'), findsOneWidget);
    expect(find.text('Finalizados'), findsNothing);
  });
}
