import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/main.dart' show SysBarberApp;
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/screens/admin_barbeiros_screen.dart';
import 'package:sysbarber/screens/admin_clientes_screen.dart';
import 'package:sysbarber/screens/admin_relatorios_screen.dart';
import 'package:sysbarber/screens/admin_screen.dart';
import 'package:sysbarber/screens/admin_servicos_screen.dart';
import 'package:sysbarber/screens/agendamentos_screen.dart';
import 'package:sysbarber/screens/barbeiro_screen.dart';
import 'package:sysbarber/screens/cadastro_screen.dart';
import 'package:sysbarber/screens/configuracao_screen.dart';
import 'package:sysbarber/screens/convite_barbeiro_screen.dart';
import 'package:sysbarber/screens/home_screen.dart';
import 'package:sysbarber/screens/horario_screen.dart';
import 'package:sysbarber/screens/login_screen.dart';
import 'package:sysbarber/screens/pagamento_screen.dart';
import 'package:sysbarber/screens/perfil_screen.dart';
import 'package:sysbarber/screens/recuperar_senha_screen.dart';
import 'package:sysbarber/screens/servicos_screen.dart';
import 'package:sysbarber/screens/splash_screen.dart';
import 'package:sysbarber/screens/termos_screen.dart';
import 'package:sysbarber/services/auth_service.dart';
import 'package:sysbarber/services/booking_flow.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/email.dart';
import 'package:sysbarber/services/formatters.dart';
import 'package:sysbarber/services/lembretes.dart';
import 'package:sysbarber/services/senhas.dart';
import 'package:sysbarber/services/sms.dart';
import 'package:sysbarber/services/suporte.dart';
import 'package:sysbarber/widgets/animacoes.dart';
import 'package:sysbarber/widgets/common_widgets.dart';

/// Administrador criado pela configuração inicial nos testes (desde a P22 o
/// app não tem conta padrão).
const emailAdmin = 'admin@sysbarber.com';
const senhaAdmin = 'admin1234';

/// Testes de tela: o que o usuário vê quando os dados chegam — e quando não
/// chegam.
void main() {
  final service = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Senhas.iteracoes = 1000;
    // Sem as notificações do aparelho: os lembretes ficam numa lista.
    AuthService.instance.lembretes = LembretesEmMemoria();
  });

  tearDown(() async => service.resetarParaTeste());

  /// Abre um banco em memória já configurado, com o administrador e os
  /// dados de exemplo (fora do relógio falso do teste).
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
      service.injetarBancoParaTeste(db);
      await service.configurarBarbearia(
        nome: 'Administrador',
        email: emailAdmin,
        telefone: '(67) 99999-0000',
        senha: senhaAdmin,
        aceitouTermos: true,
        dadosDeExemplo: true,
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
    expect(find.text('Tentar novamente'), findsOneWidget);
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
      await tester.tap(find.text('Tentar novamente'));
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
    Widget card(String n) => Cartao(
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
      await tester.tap(find.text('Tentar novamente'));
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
    expect(find.text('Confirmar pagamento'), findsOneWidget);

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
    // O botão do card e o do diálogo.
    expect(find.text('Concluir'), findsNWidgets(2));
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

  // -------------------------------------------------------------------------
  // P14 e P16 — régua de dias da tela de horário
  // -------------------------------------------------------------------------

  testWidgets('a régua de dias vai até o 14º dia e não mostra domingos',
      (tester) async {
    BookingFlow.limpar(); // sem barbeiro: a tela não consulta o banco
    // Tela larga para a régua inteira ser montada: assim nenhum dia fica de
    // fora da conferência.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await abrir(tester, const HorarioScreen());

    // Antes eram 7 dias, com domingo.
    expect(find.text('DOM'), findsNothing);
    final ultimo = DatabaseService.diasDisponiveis().last;
    expect(find.text('${ultimo.day}'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // P17 — agenda geral do administrador
  // -------------------------------------------------------------------------

  /// Banco com o seed e o administrador logado.
  Future<void> adminLogado(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(
      () => AuthService.instance.login(
        emailAdmin,
        senhaAdmin,
      ),
    );
  }

  /// Pagamento "na barbearia", ainda pendente, do agendamento [id] (R$ 35).
  Future<int> pagamentoPendente(int id) => service.criarPagamento(
    Pagamento(
      idAgendamento: id,
      valor: 35,
      metodo: 'A combinar',
      status: Pagamento.statusPendente,
      criadoEm: DateTime.now().toIso8601String(),
      tipo: TipoPagamento.naHora.dbValue,
    ),
  );

  testWidgets('o painel administrativo abre a agenda geral', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const AdminScreen());

    await tester.scrollUntilVisible(
      find.text('Agenda geral'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Agenda geral'));
    await tester.pump(); // monta a rota
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 500)); // fim da transição

    expect(find.text('Agenda geral'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('a agenda geral mostra os atendimentos de todos os barbeiros, '
      'com as ações da barbearia', (tester) async {
    // Tela alta: com os filtros no topo, os dois cards cabem sem rolar.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await adminLogado(tester);
    await tester.runAsync(() async {
      final idCliente = await cadastrarClienteTeste();
      // Com o Carlos (barbeiro 1), já passou do horário e falta receber.
      final passado = await marcarCorte(
        idCliente,
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await pagamentoPendente(passado);
      // Com o Rafael (barbeiro 2), amanhã.
      final amanha = DateTime.now().add(const Duration(days: 1));
      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: 2,
          idServico: 1,
          dataHora: DateTime(
            amanha.year,
            amanha.month,
            amanha.day,
            9,
          ).toIso8601String(),
        ),
      );
    });

    await abrir(tester, const AgendamentosScreen(agendaGeral: true));

    expect(find.text('Agenda geral'), findsOneWidget);
    expect(find.text('com Carlos Eduardo'), findsOneWidget);
    expect(find.text('com Rafael Souza'), findsOneWidget);
    expect(find.text('Receber'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Não compareceu'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('cancelar pela agenda geral não cobra multa', (tester) async {
    await adminLogado(tester);
    late int id;
    await tester.runAsync(() async {
      // Em 30 minutos: se fosse o cliente cancelando, haveria multa.
      id = await marcarCorte(
        await cadastrarClienteTeste(),
        DateTime.now().add(const Duration(minutes: 30)),
      );
      await pagamentoPendente(id);
    });
    await abrir(tester, const AgendamentosScreen(agendaGeral: true));

    await tester.runAsync(() => tester.tap(find.text('Cancelar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('parte da barbearia'), findsOneWidget);
    expect(find.textContaining('Será cobrada multa'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Cancelar agendamento'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    late Pagamento? pagamento;
    late RelatorioGeral relatorio;
    await tester.runAsync(() async {
      pagamento = await service.buscarPagamentoDoAgendamento(id);
      relatorio = await service.gerarRelatorio();
    });
    expect(pagamento!.cancelado, isTrue);
    expect(pagamento!.natureza, NaturezaPagamento.servico);
    expect(relatorio.cancelados, 1);
    expect(relatorio.aReceber, 0);

    // Deixa o aviso "Agendamento cancelado" sumir antes de encerrar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o barbeiro não abre a agenda geral', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(
      () => AuthService.instance.login(
        'carlos.eduardo@sysbarber.com',
        'barbeiro123',
      ),
    );

    await abrir(tester, const AgendamentosScreen(agendaGeral: true));

    // O título da tela e o aviso.
    expect(find.text('Acesso restrito'), findsNWidgets(2));
    expect(find.text('Agenda geral'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // Desde a agenda geral, quem confirma o recebimento é a barbearia — o
  // barbeiro ou o administrador —, e não só o profissional.
  testWidgets('quem vai pagar na barbearia lê que a barbearia confirma o '
      'recebimento', (tester) async {
    await abrir(tester, const PagamentoScreen());

    await tester.tap(find.text('Pagar na barbearia'));
    await tester.pump();
    // O aviso fica abaixo das opções; a lista só o monta quando aparece.
    await tester.scrollUntilVisible(
      find.textContaining('a barbearia confirma o recebimento'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.textContaining('a barbearia confirma o recebimento'),
      findsOneWidget,
    );
    expect(find.textContaining('profissional'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // P18 e P19 — ajustes visuais vistos no emulador
  // -------------------------------------------------------------------------

  testWidgets('o painel usa o singular com um cliente só', (tester) async {
    // Um cliente só: o administrador não conta como cliente.
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(cadastrarClienteTeste);

    await abrir(tester, const AdminScreen());

    expect(find.text('1 cadastrado'), findsOneWidget);
    expect(find.text('1 cadastrados'), findsNothing);
  });

  testWidgets('os relatórios usam o singular com um cliente só',
      (tester) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(cadastrarClienteTeste);
    await abrir(tester, const AdminRelatoriosScreen());

    await tester.scrollUntilVisible(
      find.text('cadastrado'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('cadastrado'), findsOneWidget);
  });

  testWidgets('o texto das opções de pagamento não encosta no botão de '
      'seleção', (tester) async {
    celularPequeno(tester);
    await abrir(tester, const PagamentoScreen());

    for (final descricao in [
      TipoPagamento.antecipado.descricao,
      TipoPagamento.naHora.descricao,
    ]) {
      final linha = tester.widget<Row>(
        find
            .ancestor(of: find.text(descricao), matching: find.byType(Row))
            .first,
      );
      final texto = tester.getRect(find.text(descricao));
      final selecao = tester.getRect(find.byWidget(linha.children.last));

      expect(
        selecao.left - texto.right,
        greaterThanOrEqualTo(8),
        reason: descricao,
      );
    }
  });

  testWidgets('botão com texto longo quebra a linha em celular pequeno, sem '
      'estourar', (tester) async {
    celularPequeno(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BotaoPrincipal(
              texto: 'Reservar e pagar na barbearia',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    // Antes o texto ficava numa linha só e estourava o botão.
    expect(tester.takeException(), isNull);
    expect(find.text('Reservar e pagar na barbearia'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // P22 — configuração inicial da barbearia
  // -------------------------------------------------------------------------

  /// Banco recém-criado, como na primeira abertura: sem administrador.
  Future<void> bancoNovo(WidgetTester tester) async {
    await tester.runAsync(() async {
      service.injetarBancoParaTeste(
        await databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            singleInstance: false,
            onCreate: service.criarSchema,
            onConfigure: DatabaseService.configurar,
          ),
        ),
      );
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.logout();
      await AuthService.instance.carregarConfiguracao();
    });
  }

  testWidgets('a primeira abertura leva à configuração da barbearia', (
    tester,
  ) async {
    await bancoNovo(tester);

    await abrir(tester, const SplashScreen());

    expect(find.text('A barbearia na palma da sua mão'), findsOneWidget);
    expect(find.text('Configurar barbearia'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    expect(find.text('Criar conta'), findsNothing);
  });

  testWidgets('o corte da tesoura aparece só ao abrir o app, e não ao voltar '
      'para a abertura', (tester) async {
    await bancoNovo(tester);

    await tester.pumpWidget(const SysBarberApp());
    expect(find.byType(CorteDeAbertura), findsOneWidget);
    expect(find.text('Configurar barbearia'), findsNothing);

    await tester.pump(Animacoes.duracaoCorte);
    await tester.pumpAndSettle();
    expect(find.text('Configurar barbearia'), findsOneWidget);

    // Como ao sair da conta: a abertura volta sem o corte.
    Navigator.of(tester.element(find.text('Configurar barbearia')))
        .pushNamedAndRemoveUntil('/', (_) => false);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CorteDeAbertura), findsNothing);
  });

  /// Abre [abertura] com o cliente de teste logado; o Início é um texto.
  Future<void> abrirLogado(WidgetTester tester, Widget abertura) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await cadastrarClienteTeste();
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: abertura,
        routes: {'/home': (_) => const Scaffold(body: Text('INÍCIO'))},
      ),
    );
  }

  testWidgets('com a sessão salva, o app abre com o corte e só depois entra', (
    tester,
  ) async {
    await abrirLogado(tester, const SplashScreen(comCorte: true));

    // Sem o corte, ele entraria em 600 ms.
    await tester.pump(Animacoes.duracaoCorte * 0.9);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('INÍCIO'), findsNothing);
    expect(find.textContaining('Entrando como'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('INÍCIO'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('entrando com a sessão salva, a abertura fica no centro da '
      'tela', (tester) async {
    await abrirLogado(tester, const SplashScreen());
    await tester.pump(const Duration(milliseconds: 300));

    final centro = tester.getCenter(find.byType(Scaffold)).dx;
    expect(tester.getCenter(find.byType(IconeCirculo)).dx, closeTo(centro, 1));
    expect(
      tester.getCenter(find.textContaining('Entrando como')).dx,
      closeTo(centro, 1),
    );

    await tester.pumpAndSettle();
    expect(find.text('INÍCIO'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('a configuração cria o administrador e mostra como os '
      'barbeiros de exemplo entram', (tester) async {
    await bancoNovo(tester);
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: const ConfiguracaoScreen(),
          routes: {'/home': (_) => const Scaffold(body: Text('INÍCIO'))},
        ),
      ),
    );

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Dono da Barbearia');
    await tester.enterText(campos.at(1), 'dono@barbearia.com');
    await tester.enterText(campos.at(2), '67987654321');
    await tester.enterText(campos.at(3), 'senhaDoDono1');
    await tester.enterText(campos.at(4), 'senhaDoDono1');
    await tester.ensureVisible(find.text('Começar com dados de exemplo'));
    await tester.tap(find.text('Começar com dados de exemplo'));
    await tester.pump();
    await tester.ensureVisible(find.byType(AceiteTermos));
    await tester.tap(find.textContaining('Li e aceito'));
    await tester.pump();

    await tester.ensureVisible(find.text('Configurar e entrar'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Configurar e entrar'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();

    // O dono precisa saber como os barbeiros de exemplo entram no app.
    expect(find.textContaining('barbeiro123'), findsWidgets);
    // A navegação depois do diálogo continua o código iniciado no relógio
    // real (o toque em "CONFIGURAR E ENTRAR"), então também roda nele.
    await tester.runAsync(() async {
      await tester.tap(find.text('Entendi'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.podeAdministrar, isTrue);
    expect(await tester.runAsync(service.listarBarbeiros), hasLength(3));
  });

  testWidgets('o login não mostra mais as credenciais do administrador', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Antes, em modo de desenvolvimento, o login exibia a conta padrão.
    expect(find.textContaining('admin1234'), findsNothing);
    expect(find.textContaining('admin@sysbarber.com'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // P24 — recuperação de senha
  // -------------------------------------------------------------------------

  /// Toca em [alvo] e espera o banco (e o hash em outro isolate) responder.
  /// O toque roda no relógio real, e com ele tudo o que o botão dispara,
  /// inclusive o que continua depois de um diálogo.
  Future<void> tocarEsperando(WidgetTester tester, Finder alvo) async {
    await tester.ensureVisible(alvo);
    await tester.runAsync(() async {
      await tester.tap(alvo);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
  }

  /// App com a tela [inicio] e a Home trocada por um marcador.
  Future<void> abrirComHome(WidgetTester tester, Widget inicio) =>
      tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            home: inicio,
            routes: {
              '/home': (_) => const Scaffold(body: Text('INÍCIO')),
              AuthService.rotaRecuperarSenha: (_) =>
                  const RecuperarSenhaScreen(),
            },
          ),
        ),
      );

  testWidgets('"Esqueci minha senha" no login é um botão e abre a '
      'recuperação', (tester) async {
    final semantica = tester.ensureSemantics();
    await abrirComHome(tester, const LoginScreen());

    expect(
      tester.getSemantics(find.text('Esqueci minha senha')),
      isSemantics(isButton: true),
    );
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Esqueceu a senha?'), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('a recuperação mostra o SMS simulado e, com o código, cria a '
      'senha nova e entra', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(cadastrarClienteTeste);
    await abrirComHome(tester, const RecuperarSenhaScreen());

    await tester.enterText(find.byType(TextField).at(0), 'c@teste.com');
    // O celular só aparece quando a pessoa escolhe receber por SMS.
    expect(find.text('Celular cadastrado'), findsNothing);
    await tester.tap(find.text('Por SMS'));
    await tester.pump();
    expect(find.text('Celular cadastrado'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '67999990000');
    await tocarEsperando(tester, find.text('Enviar código'));

    expect(find.text('SMS simulado'), findsOneWidget);
    expect(find.textContaining('(67) •••••-0000'), findsWidgets);
    final codigo = RegExp(
      r'\d{6}',
    ).firstMatch(SmsSimulado.instance.ultima.value!.mensagem)!.group(0)!;
    expect(find.textContaining(codigo), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), codigo);
    await tester.enterText(find.byType(TextField).at(1), 'senhaNova1');
    await tester.enterText(find.byType(TextField).at(2), 'senhaNova1');
    await tocarEsperando(tester, find.text('Salvar e entrar'));
    await tester.pumpAndSettle();

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.usuarioAtual!.email, 'c@teste.com');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('por e-mail basta o e-mail da conta: a tela mostra o e-mail '
      'simulado e, com o código, cria a senha nova e entra', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(cadastrarClienteTeste);
    await abrirComHome(tester, const RecuperarSenhaScreen());

    // Por e-mail é a opção inicial, e o celular não é pedido.
    expect(find.text('Celular cadastrado'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'c@teste.com');
    await tocarEsperando(tester, find.text('Enviar código'));

    expect(find.text('E-mail simulado'), findsOneWidget);
    expect(find.textContaining('c•••@teste.com'), findsWidgets);
    expect(find.text('Código do e-mail'), findsOneWidget);
    final codigo = RegExp(
      r'\d{6}',
    ).firstMatch(EmailSimulado.instance.ultimo.value!.texto)!.group(0)!;

    await tester.enterText(find.byType(TextField).at(0), codigo);
    await tester.enterText(find.byType(TextField).at(1), 'senhaNova1');
    await tester.enterText(find.byType(TextField).at(2), 'senhaNova1');
    await tocarEsperando(tester, find.text('Salvar e entrar'));
    await tester.pumpAndSettle();

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.usuarioAtual!.email, 'c@teste.com');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('quem entra com o código liberado pela barbearia é levado a '
      'criar uma senha nova', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    late String codigo;
    await tester.runAsync(() async {
      codigo = await service.liberarCodigoDaBarbearia(
        await cadastrarClienteTeste(),
      );
    });
    await abrirComHome(tester, const LoginScreen());

    await tester.enterText(find.byType(TextField).at(0), 'c@teste.com');
    await tester.enterText(find.byType(TextField).at(1), codigo);
    await tocarEsperando(
      tester,
      find.widgetWithText(BotaoPrincipal, 'Entrar'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crie sua nova senha'), findsOneWidget);
    expect(AuthService.instance.estaLogado, isFalse);

    await tester.enterText(find.byType(TextField).at(0), 'minhaSenha1');
    await tester.enterText(find.byType(TextField).at(1), 'minhaSenha1');
    await tocarEsperando(tester, find.text('Salvar e entrar'));
    await tester.pumpAndSettle();

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.usuarioAtual!.email, 'c@teste.com');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o administrador libera uma nova senha no detalhe do cliente '
      'e vê o código provisório', (tester) async {
    await adminLogado(tester);
    await tester.runAsync(cadastrarClienteTeste);
    await abrir(tester, const AdminClientesScreen());

    await tocarEsperando(tester, find.text('c@teste.com'));
    await tocarEsperando(tester, find.text('Liberar nova senha'));
    await tester.pumpAndSettle();
    expect(find.text('Liberar nova senha?'), findsOneWidget);

    await tocarEsperando(tester, find.text('Liberar'));
    await tester.pumpAndSettle();

    expect(find.text('Código provisório'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{6}$').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );
    final gravado = await tester.runAsync(
      () => service.database.then((db) => db.query('codigo_senha')),
    );
    expect(gravado!.single['origem'], 'barbearia');
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P26 — Suporte no Perfil
  // -------------------------------------------------------------------------

  /// Abre o Perfil de quem está logado. Os links que ele abriria ficam na
  /// lista devolvida; com [abre] falso, é como um aparelho sem o app.
  Future<List<Uri>> abrirPerfil(WidgetTester tester, {bool abre = true}) async {
    final abertos = <Uri>[];
    await abrir(
      tester,
      PerfilScreen(
        abrirLink: (link) async {
          abertos.add(link);
          return abre;
        },
      ),
    );
    return abertos;
  }

  /// Rola o Perfil até o Suporte, no fim da lista (que só monta o que está
  /// perto da tela).
  Future<void> rolarAteOSuporte(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('E-mail'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // O scrollUntilVisible termina num ensureVisible sem redesenhar a tela.
    await tester.pump();
  }

  Future<void> clienteLogado(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await cadastrarClienteTeste();
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
  }

  testWidgets('o Perfil termina com o Suporte, e o WhatsApp abre com a '
      'mensagem pronta do cliente', (tester) async {
    await clienteLogado(tester);
    final abertos = await abrirPerfil(tester);

    await rolarAteOSuporte(tester);
    expect(find.text('Suporte'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    // No fim da tela, depois do SAIR.
    expect(
      tester.getTopLeft(find.text('Suporte')).dy,
      greaterThan(tester.getTopLeft(find.text('Sair')).dy),
    );

    await tester.tap(find.text('WhatsApp'));
    await tester.pump();

    expect(abertos.single.host, 'wa.me');
    expect(abertos.single.path, '/${ContatoSuporte.whatsapp}');
    expect(
      abertos.single.queryParameters['text'],
      'Olá! Sou Cliente (cliente) e preciso de ajuda com o SysBarber.',
    );
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o administrador também tem o Suporte, e o e-mail vai com o '
      'assunto e a mensagem pronta dele', (tester) async {
    await adminLogado(tester);
    final abertos = await abrirPerfil(tester);

    await rolarAteOSuporte(tester);
    // O painel é uma aba do administrador: o Perfil não leva mais a ele.
    expect(find.text('Área administrativa'), findsNothing);
    await tocarEsperando(tester, find.text('E-mail'));

    expect(abertos.single.scheme, 'mailto');
    expect(abertos.single.path, ContatoSuporte.email);
    expect(abertos.single.queryParameters['subject'], 'Suporte SysBarber');
    expect(
      abertos.single.queryParameters['body'],
      'Olá! Sou Administrador (administrador) e preciso de ajuda com o '
      'SysBarber.',
    );
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('sem app para abrir o WhatsApp ou o e-mail, o Perfil avisa', (
    tester,
  ) async {
    await clienteLogado(tester);
    await abrirPerfil(tester, abre: false);

    await rolarAteOSuporte(tester);
    await tocarEsperando(tester, find.text('WhatsApp'));
    expect(
      find.text(
        'Não foi possível abrir o WhatsApp. Tente falar com o suporte por '
        'e-mail.',
      ),
      findsOneWidget,
    );

    await tocarEsperando(tester, find.text('E-mail'));
    expect(
      find.text(
        'Não há app de e-mail neste aparelho. Escreva para '
        '${ContatoSuporte.email} ou use o WhatsApp.',
      ),
      findsOneWidget,
    );
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('os botões do Suporte cabem lado a lado em celular pequeno com '
      'fonte grande', (tester) async {
    celularPequeno(tester);
    await clienteLogado(tester);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: PerfilScreen(abrirLink: (_) async => true),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    await rolarAteOSuporte(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P23 — sem nota dos barbeiros
  // -------------------------------------------------------------------------

  testWidgets('a escolha do profissional não mostra nota dos barbeiros', (
    tester,
  ) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    BookingFlow.limpar();

    await abrir(tester, const BarbeiroScreen());

    expect(find.text('Carlos Eduardo'), findsOneWidget);
    // Antes: "⭐ 4.9 (128)", números fixos dos barbeiros de exemplo.
    expect(find.textContaining('⭐'), findsNothing);
    expect(find.text('4.9'), findsNothing);
    expect(find.text('(128)'), findsNothing);

    // O selo de selecionado continua aparecendo no card escolhido.
    await tester.tap(find.text('Carlos Eduardo'));
    await tester.pump();
    expect(find.text('Selecionado ✓'), findsOneWidget);
  });

  testWidgets('Gerenciar Barbeiros não mostra nota dos barbeiros', (
    tester,
  ) async {
    await adminLogado(tester);

    await abrir(tester, const AdminBarbeirosScreen());

    expect(find.text('Carlos Eduardo'), findsOneWidget);
    // Antes: "4.9 (128 avaliações)", com uma estrela.
    expect(find.textContaining('avaliações'), findsNothing);
    expect(find.byIcon(Icons.star_outline), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // Novo visual — ícones de linha no lugar dos emojis
  // -------------------------------------------------------------------------

  test('cada ícone de serviço vira o seu ícone de linha, e um valor fora da '
      'lista mostra a tesoura', () {
    for (final (valor, icone, _) in iconesDeServico) {
      expect(iconeDoServico(valor), icone);
    }
    // Gravado antes da lista existir, quando o administrador digitava o emoji.
    expect(iconeDoServico('🪞'), Icons.content_cut_rounded);
  });

  testWidgets('o administrador escolhe o ícone do serviço entre os ícones de '
      'linha, e o banco guarda a opção escolhida', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const AdminServicosScreen());

    await tester.tap(find.text('Corte de Cabelo'));
    await tester.pumpAndSettle();
    // Antes era um campo de texto "Ícone (emoji)".
    expect(find.text('Ícone (emoji)'), findsNothing);
    final coloracao = find.bySemanticsLabel('Ícone Coloração');
    await tester.ensureVisible(coloracao);
    await tester.tap(coloracao);
    await tester.pump();
    await tocarEsperando(tester, find.text('Salvar'));

    late List<Servico> servicos;
    await tester.runAsync(
      () async => servicos = await service.listarServicos(),
    );
    expect(servicos.firstWhere((s) => s.nome == 'Corte de Cabelo').icone, '🎨');
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // Navegação principal com abas
  // -------------------------------------------------------------------------

  /// O botão [rotulo] da barra de navegação (e não outro texto de mesmo nome
  /// na tela).
  Finder botaoDaBarra(String rotulo) => find.descendant(
    of: find.byType(BarraNavegacao),
    matching: find.text(rotulo),
  );

  /// Toca em [alvo] e espera a aba nova carregar do banco. A aba faz
  /// várias consultas seguidas, e cada uma precisa do relógio real.
  Future<void> trocarDeAba(WidgetTester tester, Finder alvo) async {
    await tester.tap(alvo);
    await tester.pump(); // monta a aba nova
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    // Fim da animação: ela começa a contar num quadro, e a aba que saiu só
    // é desmontada no quadro depois do fim.
    for (var i = 0; i < 3; i++) {
      await tester.pump(BarraNavegacao.duracao);
    }
  }

  /// A aba marcada na barra de navegação.
  Aba abaMarcada(WidgetTester tester) {
    final atual = tester
        .widget<BarraNavegacao>(find.byType(BarraNavegacao))
        .atual;
    return HomeScreen.abasDoPerfil(AuthService.instance)[atual].$1;
  }

  testWidgets('a barra de navegação fica fixa: cada botão troca a aba, e o '
      'voltar do Android leva de volta ao Início', (tester) async {
    await clienteLogado(tester);
    await abrir(tester, const HomeScreen());
    expect(abaMarcada(tester), Aba.inicio);

    // Antes cada botão abria uma tela nova, por cima, e a barra sumia.
    await trocarDeAba(tester, botaoDaBarra('Serviços'));
    expect(find.byType(ServicosScreen), findsOneWidget);
    expect(find.byType(BarraNavegacao), findsOneWidget);
    expect(abaMarcada(tester), Aba.servicos);

    await trocarDeAba(tester, botaoDaBarra('Perfil'));
    expect(find.byType(PerfilScreen), findsOneWidget);
    expect(find.byType(BarraNavegacao), findsOneWidget);
    expect(abaMarcada(tester), Aba.perfil);

    // O atalho do Perfil para os agendamentos troca para a aba Agenda.
    await trocarDeAba(tester, find.bySemanticsLabel(RegExp('^Agendamentos')));
    expect(find.byType(AgendamentosScreen), findsOneWidget);
    expect(abaMarcada(tester), Aba.agenda);

    await tester.runAsync(() => tester.binding.handlePopRoute());
    // A animação começa a contar no quadro seguinte, e a aba que saiu só é
    // desmontada no quadro depois do fim.
    for (var i = 0; i < 3; i++) {
      await tester.pump(BarraNavegacao.duracao);
    }
    expect(abaMarcada(tester), Aba.inicio);
    expect(find.byType(AgendamentosScreen), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P30 — telas de cada perfil
  // -------------------------------------------------------------------------

  testWidgets('o administrador entra no painel, com as abas Painel, Agenda, '
      'Relatórios e Perfil, e não agenda', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const HomeScreen());

    // Antes ele via o Início do cliente, com Serviços e Fidelidade.
    expect(find.byType(AdminScreen), findsOneWidget);
    for (final rotulo in ['Painel', 'Agenda', 'Relatórios', 'Perfil']) {
      expect(botaoDaBarra(rotulo), findsOneWidget, reason: rotulo);
    }
    expect(botaoDaBarra('Início'), findsNothing);
    expect(botaoDaBarra('Serviços'), findsNothing);

    // A Agenda do administrador é a agenda geral.
    await trocarDeAba(tester, botaoDaBarra('Agenda'));
    expect(abaMarcada(tester), Aba.agenda);
    expect(find.text('Agenda geral'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o barbeiro tem as abas Agenda e Perfil, e o Perfil troca a '
      'senha, sem Suporte', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(
      () => AuthService.instance.login(
        'carlos.eduardo@sysbarber.com',
        'barbeiro123',
      ),
    );
    await abrir(tester, const HomeScreen());

    expect(find.text('Minha agenda'), findsOneWidget);
    expect(botaoDaBarra('Agenda'), findsOneWidget);
    expect(botaoDaBarra('Perfil'), findsOneWidget);
    expect(botaoDaBarra('Início'), findsNothing);

    // Antes o barbeiro não tinha Perfil.
    await trocarDeAba(tester, botaoDaBarra('Perfil'));
    expect(find.byType(PerfilScreen), findsOneWidget);
    expect(find.text('Carlos Eduardo'), findsOneWidget);
    expect(find.text('Especialidade'), findsOneWidget);
    expect(find.text('Alterar senha'), findsOneWidget);
    // Nome e especialidade são do administrador; e-mail e telefone, dele.
    expect(find.text('E-mail e telefone'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sair'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Suporte'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P33 — convite do barbeiro
  // -------------------------------------------------------------------------

  /// Deixa terminar o que a tela pediu ao banco depois de um toque.
  Future<void> esperarBanco(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
  }

  /// Texto do código do convite na tela, em dois blocos (`K7MP-Q2XR`).
  final codigoNaTela = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$').hasMatch(w.data ?? ''),
  );

  testWidgets('o administrador convida o barbeiro pelo sheet, compartilha a '
      'mensagem pronta e vê o convite pendente', (tester) async {
    await adminLogado(tester);
    final compartilhados = <String>[];
    await abrir(
      tester,
      AdminBarbeirosScreen(
        compartilhar: (texto) async => compartilhados.add(texto),
      ),
    );

    await tocarEsperando(tester, find.byTooltip('Convidar barbeiro'));
    await tester.pumpAndSettle();
    expect(find.text('Convidar barbeiro'), findsOneWidget);
    // O administrador não define mais e-mail nem senha.
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome completo'),
      'Pedro Alves',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Especialidade'),
      'Degradê',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Salário (R\$)'),
      '240000',
    );
    await tocarEsperando(tester, find.text('Gerar convite'));
    await tester.pumpAndSettle();

    expect(find.text('Convite para Pedro Alves'), findsOneWidget);
    expect(codigoNaTela, findsOneWidget);
    final codigo = tester.widget<Text>(codigoNaTela).data!;

    await tocarEsperando(tester, find.text('Compartilhar'));
    expect(compartilhados.single, contains(codigo));
    expect(compartilhados.single, contains('Tenho um convite de barbeiro'));

    await tocarEsperando(tester, find.text('Concluir'));
    await esperarBanco(tester);

    expect(find.text('Convites pendentes'), findsOneWidget);
    expect(find.text('Convite pendente'), findsOneWidget);
    expect(find.text('Pedro Alves'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o convite pendente ganha outro código ou é cancelado, e o '
      'vencido aparece como vencido', (tester) async {
    await adminLogado(tester);
    await tester.runAsync(() async {
      await service.criarConviteBarbeiro(
        nome: 'Pedro Alves',
        especialidade: 'Degradê',
        salario: 2400,
      );
      await service.criarConviteBarbeiro(
        nome: 'João Lima',
        especialidade: 'Barba',
        salario: 2400,
        agora: DateTime.now().subtract(const Duration(days: 8)),
      );
    });
    await abrir(tester, const AdminBarbeirosScreen());

    expect(find.text('Convite pendente'), findsOneWidget);
    expect(find.text('Convite vencido'), findsOneWidget);

    // Outro código para o vencido.
    await tocarEsperando(tester, find.text('Gerar outro código').last);
    await tester.pumpAndSettle();
    expect(find.text('Gerar outro código?'), findsOneWidget);
    await tocarEsperando(tester, find.text('Gerar'));
    await tester.pumpAndSettle();
    expect(find.text('Convite para João Lima'), findsOneWidget);
    expect(codigoNaTela, findsOneWidget);
    await tocarEsperando(tester, find.text('Concluir'));
    await esperarBanco(tester);
    expect(find.text('Convite vencido'), findsNothing);
    final convites = await tester.runAsync(service.listarConvitesBarbeiro);
    expect(convites!.where((c) => c.vencido(DateTime.now())), isEmpty);

    // Cancelar o do Pedro, o primeiro da lista.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tocarEsperando(tester, find.text('Cancelar convite').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancelar o convite?'), findsOneWidget);
    await tocarEsperando(tester, find.text('Cancelar convite').last);
    await tester.pumpAndSettle();

    expect(find.text('Pedro Alves'), findsNothing);
    expect(find.text('João Lima'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('editar o barbeiro muda só nome, especialidade e salário, e o '
      'administrador libera uma nova senha para ele', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const AdminBarbeirosScreen());

    await tocarEsperando(tester, find.text('Carlos Eduardo'));
    await tester.pumpAndSettle();
    expect(find.text('Editar barbeiro'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.widgetWithText(TextField, 'E-mail de acesso'), findsNothing);

    await tocarEsperando(tester, find.text('Liberar nova senha'));
    await tester.pumpAndSettle();
    expect(find.text('Liberar nova senha?'), findsOneWidget);
    await tocarEsperando(tester, find.text('Liberar'));
    await tester.pumpAndSettle();

    expect(find.text('Código provisório'), findsOneWidget);
    expect(
      find.textContaining('o barbeiro usa o e-mail carlos.eduardo@'),
      findsOneWidget,
    );
    final gravado = await tester.runAsync(
      () => service.database.then((db) => db.query('codigo_senha')),
    );
    expect(gravado!.single['id_barbeiro'], isNotNull);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('no login, "Tenho um convite de barbeiro" abre o convite, que '
      'confere o código e cria a conta do barbeiro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    late String codigo;
    await tester.runAsync(() async {
      codigo = (await service.criarConviteBarbeiro(
        nome: 'Pedro Alves',
        especialidade: 'Degradê',
        salario: 2400,
      )).codigo;
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: const LoginScreen(),
          routes: {
            '/home': (_) => const Scaffold(body: Text('INÍCIO')),
            AuthService.rotaConvite: (_) => const ConviteBarbeiroScreen(),
          },
        ),
      ),
    );

    await tocarEsperando(tester, find.text('Tenho um convite de barbeiro'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar na equipe'), findsOneWidget);

    // Código errado: avisa e continua na mesma etapa.
    await tester.enterText(find.byType(TextField), 'zzzzzzzz');
    await tocarEsperando(tester, find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Convite não encontrado'), findsOneWidget);
    expect(find.text('Entrar na equipe'), findsOneWidget);
    // O aviso some sozinho; antes disso, cobriria o botão do fim da tela.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), codigo.toLowerCase());
    expect(find.text(formatarCodigoConvite(codigo)), findsOneWidget);
    await tocarEsperando(tester, find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Convite para Pedro Alves'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(0),
      'pedro.alves@sysbarber.com',
    );
    await tester.enterText(find.byType(TextField).at(1), '67994044004');
    await tester.enterText(find.byType(TextField).at(2), 'senha123');
    await tester.enterText(find.byType(TextField).at(3), 'senha123');
    await tester.ensureVisible(find.byType(AceiteTermos));
    await tester.tap(find.textContaining('Li e aceito'));
    await tester.pump();
    await tocarEsperando(tester, find.text('Criar conta e entrar'));
    await esperarBanco(tester);

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.ehBarbeiro, isTrue);
    expect(AuthService.instance.barbeiroAtual!.telefone, '(67) 99404-4004');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('no Perfil, o barbeiro edita o próprio e-mail e telefone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(
      () => AuthService.instance.login(
        'rafael.souza@sysbarber.com',
        'barbeiro123',
      ),
    );
    await abrir(tester, const PerfilScreen());

    await tocarEsperando(tester, find.text('Editar dados'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Telefone'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome completo'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'rafael@barbearia.com',
    );
    await tocarEsperando(tester, find.text('Salvar'));
    await tester.pumpAndSettle();
    // O e-mail fica no topo do Perfil.
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();

    expect(find.text('rafael@barbearia.com'), findsOneWidget);
    expect(AuthService.instance.barbeiroAtual!.email, 'rafael@barbearia.com');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('fechar o sheet pelo voltar, sem "Concluir", também mostra o '
      'convite pendente', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const AdminBarbeirosScreen());

    await tocarEsperando(tester, find.byTooltip('Convidar barbeiro'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome completo'),
      'Pedro Alves',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Especialidade'),
      'Degradê',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Salário (R\$)'),
      '240000',
    );
    await tocarEsperando(tester, find.text('Gerar convite'));
    await tester.pumpAndSettle();
    expect(codigoNaTela, findsOneWidget);

    // O voltar do Android fecha o sheet.
    await tester.binding.handlePopRoute();
    await esperarBanco(tester);

    expect(find.text('Convite para Pedro Alves'), findsNothing);
    expect(find.text('Convite pendente'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // Filtros da agenda geral
  // -------------------------------------------------------------------------

  /// Atendimentos de amanhã (Carlos e Rafael) e de depois de amanhã (Carlos)
  /// para os filtros da agenda geral.
  Future<(DateTime, DateTime)> atendimentosParaFiltrar(
    WidgetTester tester,
  ) async {
    final amanha = DateTime.now().add(const Duration(days: 1));
    final depois = DateTime.now().add(const Duration(days: 2));
    await tester.runAsync(() async {
      final idCliente = await cadastrarClienteTeste();
      for (final (idBarbeiro, dia, hora) in [
        (1, amanha, 9),
        (2, amanha, 10),
        (1, depois, 9),
      ]) {
        await service.criarAgendamento(
          Agendamento(
            idCliente: idCliente,
            idBarbeiro: idBarbeiro,
            idServico: 1,
            dataHora: DateTime(
              dia.year,
              dia.month,
              dia.day,
              hora,
            ).toIso8601String(),
          ),
        );
      }
    });
    return (amanha, depois);
  }

  /// Tela alta: os três atendimentos cabem sem rolar.
  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a agenda geral filtra pelo barbeiro escolhido no select', (
    tester,
  ) async {
    telaAlta(tester);
    await adminLogado(tester);
    await atendimentosParaFiltrar(tester);
    await abrir(tester, const AgendamentosScreen(agendaGeral: true));
    expect(find.text('com Carlos Eduardo'), findsNWidgets(2));
    expect(find.text('com Rafael Souza'), findsOneWidget);

    // Antes não havia filtro: era preciso achar o nome em cada card.
    await tester.tap(find.byType(DropdownButton<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Eduardo').last);
    await tester.pumpAndSettle();
    expect(find.text('com Carlos Eduardo'), findsNWidgets(2));
    expect(find.text('com Rafael Souza'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o calendário da agenda geral filtra por período, de um dia até '
      'outro, e o período pode ser limpo', (tester) async {
    telaAlta(tester);
    await adminLogado(tester);
    final (amanha, depois) = await atendimentosParaFiltrar(tester);
    DateTimeRange? recebido;
    await abrir(
      tester,
      AgendamentosScreen(
        agendaGeral: true,
        // No lugar do calendário: escolhe só amanhã.
        escolherPeriodo: (_, atual) async {
          recebido = atual;
          return DateTimeRange(start: amanha, end: amanha);
        },
      ),
    );

    await tester.tap(find.bySemanticsLabel('Escolher período'));
    await tester.pump();
    expect(recebido, isNull);
    expect(find.text('com Carlos Eduardo'), findsOneWidget);
    expect(find.text('com Rafael Souza'), findsOneWidget);
    expect(find.text(formatarDataCurta(amanha)), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar período'));
    await tester.pump();
    expect(find.text('com Carlos Eduardo'), findsNWidgets(2));
    expect(find.text(formatarDataCurta(depois)), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('o botão do calendário abre o calendário de período', (
    tester,
  ) async {
    await adminLogado(tester);
    await abrir(tester, const AgendamentosScreen(agendaGeral: true));

    await tester.tap(find.bySemanticsLabel('Escolher período'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(find.text('Escolha o período'), findsOneWidget);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P34 — excluir a própria conta e termos de uso
  // -------------------------------------------------------------------------

  testWidgets('o cadastro só cria a conta com os termos aceitos, e "Ler os '
      'termos" abre o texto', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: const CadastroScreen(),
          routes: {
            '/home': (_) => const Scaffold(body: Text('INÍCIO')),
            AuthService.rotaTermos: (_) => const TermosScreen(),
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Joana Lima');
    await tester.enterText(find.byType(TextField).at(1), 'joana@teste.com');
    await tester.enterText(find.byType(TextField).at(2), '67988881234');
    await tester.enterText(find.byType(TextField).at(3), 'senha123');
    await tocarEsperando(tester, find.text('Cadastrar'));
    await esperarBanco(tester);
    expect(find.text(DatabaseService.termosNaoAceitos), findsOneWidget);
    expect(AuthService.instance.estaLogado, isFalse);

    await tocarEsperando(tester, find.text('Ler os termos'));
    await tester.pumpAndSettle();
    expect(find.byType(TermosScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Li e aceito'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tocarEsperando(tester, find.text('Cadastrar'));
    await esperarBanco(tester);

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(AuthService.instance.ehCliente, isTrue);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('os termos explicam os dados guardados e os direitos de quem '
      'usa o app', (tester) async {
    await abrir(tester, const TermosScreen());

    expect(find.text('Termos de uso e política de privacidade'), findsOneWidget);
    for (final titulo in [
      'Quais dados o app guarda',
      'Onde ficam e com quem são compartilhados',
      'Seus direitos',
    ]) {
      await tester.scrollUntilVisible(find.text(titulo), 200);
      expect(find.text(titulo), findsOneWidget);
    }
    expect(find.textContaining('Lei Geral de Proteção de Dados'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Versão de ${TermosScreen.versao}.'),
      200,
    );
  });

  testWidgets('no Perfil, o cliente exclui a própria conta com a senha e '
      'volta à abertura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final id = await cadastrarClienteTeste();
      await service.adicionarPontos(id, 120, 'Pontos de teste');
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          initialRoute: '/perfil',
          routes: {
            '/': (_) => const Scaffold(body: Text('ABERTURA')),
            '/perfil': (_) => const PerfilScreen(),
          },
        ),
      ),
    );
    await esperarBanco(tester);

    await tester.scrollUntilVisible(
      find.text('Excluir minha conta'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Termos e privacidade'), findsOneWidget);
    await tocarEsperando(tester, find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir a sua conta?'), findsOneWidget);
    expect(find.textContaining('seus 120 pontos são perdidos'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'errada1');
    await tocarEsperando(tester, find.text('Excluir conta'));
    await esperarBanco(tester);
    expect(find.text('Senha incorreta'), findsOneWidget);
    expect(find.text('Excluir a sua conta?'), findsOneWidget);
    // Os avisos nascem no relógio real do toque; tirá-los cancela o
    // temporizador deles.
    ScaffoldMessenger.of(
      tester.element(find.byType(PerfilScreen)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'senha123');
    await tocarEsperando(tester, find.text('Excluir conta'));
    await esperarBanco(tester);

    expect(find.text('ABERTURA'), findsOneWidget);
    expect(AuthService.instance.estaLogado, isFalse);
    // O mesmo com o aviso "Conta excluída", antes de a tela ser desmontada.
    ScaffoldMessenger.of(
      tester.element(find.text('ABERTURA')),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  });

  testWidgets('o administrador e o barbeiro não têm "Excluir minha conta", '
      'mas têm os termos no Perfil', (tester) async {
    await adminLogado(tester);
    await abrir(tester, const PerfilScreen());
    await tester.scrollUntilVisible(
      find.text('Sair'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Termos e privacidade'), findsOneWidget);
    expect(find.text('Excluir minha conta'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);

    await tester.runAsync(
      () => AuthService.instance.login(
        'rafael.souza@sysbarber.com',
        'barbeiro123',
      ),
    );
    await abrir(tester, const PerfilScreen());
    await tester.scrollUntilVisible(
      find.text('Sair'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Termos e privacidade'), findsOneWidget);
    expect(find.text('Excluir minha conta'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P36 — reagendar
  // -------------------------------------------------------------------------

  testWidgets('o cliente vê "Reagendar" até 1 hora antes, e o barbeiro não',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final id = await cadastrarClienteTeste();
      final dia = DatabaseService.diasDisponiveis()[1];
      await marcarCorte(id, DateTime(dia.year, dia.month, dia.day, 9));
      await marcarCorte(id, DateTime.now().add(const Duration(minutes: 30)));
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await abrir(tester, const AgendamentosScreen());

    // Com menos de 1 hora, sobra só cancelar.
    expect(find.text('Reagendar'), findsOneWidget);
    expect(find.text('Cancelar agendamento'), findsNWidgets(2));
    await tester.runAsync(AuthService.instance.logout);

    await tester.runAsync(
      () => AuthService.instance.login(
        'carlos.eduardo@sysbarber.com',
        'barbeiro123',
      ),
    );
    await abrir(tester, const AgendamentosScreen());
    expect(find.text('Reagendar'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('reagendar passa pelo profissional e pelo horário, confirma e '
      'volta à lista com o horário novo', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantica = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    final dia = DatabaseService.diasDisponiveis()[1];
    late int idAgendamento;
    late int idCliente;
    await tester.runAsync(() async {
      idCliente = await cadastrarClienteTeste();
      idAgendamento = await marcarCorte(
        idCliente,
        DateTime(dia.year, dia.month, dia.day, 9),
      );
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: const AgendamentosScreen(),
          routes: {
            '/barbeiro': (_) => const BarbeiroScreen(),
            '/horario': (_) => const HorarioScreen(),
          },
        ),
      ),
    );
    await esperarBanco(tester);

    await tocarEsperando(tester, find.text('Reagendar'));
    await esperarBanco(tester);
    expect(find.textContaining('Reagendando o horário de'), findsOneWidget);
    await tocarEsperando(tester, find.text('Continuar'));
    await esperarBanco(tester);
    expect(find.text('Novo horário'), findsOneWidget);

    await tocarEsperando(
      tester,
      find.bySemanticsLabel(formatarDataExtenso(dia)),
    );
    await esperarBanco(tester);
    // O horário atual, com o mesmo barbeiro, não é oferecido.
    expect(find.text('09:00'), findsNothing);
    await tocarEsperando(tester, find.text('14:00'));
    await tocarEsperando(tester, find.text('Reagendar'));
    await tester.pumpAndSettle();
    expect(find.text('Reagendar?'), findsOneWidget);
    await tocarEsperando(tester, find.text('Reagendar').last);
    await esperarBanco(tester);

    expect(find.byType(HorarioScreen), findsNothing);
    expect(find.byType(AgendamentosScreen), findsOneWidget);
    final novo = DateTime(dia.year, dia.month, dia.day, 14);
    expect(find.text(formatarDataHora(novo)), findsOneWidget);
    final gravado = await tester.runAsync(
      () => service.listarAgendamentosCliente(idCliente),
    );
    expect(gravado!.single.id, idAgendamento);
    expect(gravado.single.data, novo);
    expect(BookingFlow.reagendando, isNull);

    ScaffoldMessenger.of(
      tester.element(find.byType(AgendamentosScreen)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    semantica.dispose();
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // P37 — lembrete do horário
  // -------------------------------------------------------------------------

  testWidgets('reservar pelo pagamento pede a permissão de notificação e '
      'agenda o lembrete', (tester) async {
    final lembretes = LembretesEmMemoria();
    AuthService.instance.lembretes = lembretes;
    addTearDown(() => AuthService.instance.lembretes = LembretesEmMemoria());
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    final dia = DatabaseService.diasDisponiveis()[1];
    await tester.runAsync(() async {
      await cadastrarClienteTeste();
      await AuthService.instance.login('c@teste.com', 'senha123');
      BookingFlow.iniciar((await service.listarServicos()).first);
      BookingFlow.barbeiroSelecionado = (await service.listarBarbeiros()).first;
      BookingFlow.dataSelecionada = dia;
      BookingFlow.horaSelecionada = '09:00';
    });
    await abrir(tester, const PagamentoScreen());

    await tocarEsperando(tester, find.text('Pagar na barbearia'));
    await tocarEsperando(tester, find.text('Reservar e pagar na barbearia'));
    await esperarBanco(tester);

    expect(lembretes.pedidosDePermissao, 1);
    expect(lembretes.agendados, hasLength(1));
    expect(lembretes.agendados.single.titulo, 'Seu horário é às 09:00');
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('cancelar pela agenda apaga o lembrete do horário', (
    tester,
  ) async {
    final lembretes = LembretesEmMemoria();
    AuthService.instance.lembretes = lembretes;
    addTearDown(() => AuthService.instance.lembretes = LembretesEmMemoria());
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      final id = await cadastrarClienteTeste();
      final dia = DatabaseService.diasDisponiveis()[1];
      await marcarCorte(id, DateTime(dia.year, dia.month, dia.day, 9));
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    expect(lembretes.agendados, hasLength(1));
    await abrir(tester, const AgendamentosScreen());

    await tocarEsperando(tester, find.text('Cancelar agendamento'));
    await tester.pumpAndSettle();
    await tocarEsperando(tester, find.text('Cancelar agendamento').last);
    await esperarBanco(tester);

    expect(lembretes.agendados, isEmpty);
    await tester.runAsync(AuthService.instance.logout);
  });

  // -------------------------------------------------------------------------
  // Animações de entrada
  // -------------------------------------------------------------------------

  /// Opacidade com que [alvo] está sendo desenhado (1 = pronto).
  double opacidadeDe(WidgetTester tester, Finder alvo) => tester
      .widget<Opacity>(
        find.ancestor(of: alvo, matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('a abertura anima: o ícone surge primeiro, e o slogan e o '
      'botão entram depois', (tester) async {
    await bancoNovo(tester);
    await abrir(tester, const SplashScreen());

    final icone = find.byType(IconeCirculo);
    final slogan = find.text('A barbearia na palma da sua mão');
    final botao = find.text('Configurar barbearia');
    expect(opacidadeDe(tester, slogan), 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(
      opacidadeDe(tester, icone),
      greaterThan(opacidadeDe(tester, slogan)),
    );
    expect(
      opacidadeDe(tester, slogan),
      greaterThan(opacidadeDe(tester, botao)),
    );

    await tester.pump(const Duration(seconds: 2));
    for (final alvo in [icone, slogan, botao]) {
      expect(opacidadeDe(tester, alvo), 1);
    }
  });

  testWidgets('o Início entra em cascata e os pontos contam até o valor', (
    tester,
  ) async {
    await clienteLogado(tester);
    await tester.runAsync(
      () => service.adicionarPontos(
        AuthService.instance.usuarioAtual!.id!,
        120,
        'Pontos de teste',
      ),
    );
    await abrir(tester, const HomeScreen());

    expect(find.text('0 pts'), findsOneWidget);
    expect(opacidadeDe(tester, find.text('Pontos de fidelidade')), 0);

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('120 pts'), findsOneWidget);
    expect(opacidadeDe(tester, find.text('Pontos de fidelidade')), 1);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('os serviços entram em cascata, um depois do outro', (
    tester,
  ) async {
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await abrir(tester, const ServicosScreen());

    final primeiro = find.text('Corte de Cabelo');
    final terceiro = find.text('Corte + Barba');
    expect(opacidadeDe(tester, primeiro), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(
      opacidadeDe(tester, primeiro),
      greaterThan(opacidadeDe(tester, terceiro)),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(opacidadeDe(tester, primeiro), 1);
    expect(opacidadeDe(tester, terceiro), 1);
  });
  // -------------------------------------------------------------------------
  // P41 — último serviço no Início
  // -------------------------------------------------------------------------

  /// Atendimento do cliente [idCliente] com o barbeiro 1 (Carlos Eduardo),
  /// [dias] atrás, já com o desfecho [status].
  Future<int> atendimentoPassado(
    int idCliente, {
    required int dias,
    required StatusAgendamento status,
    int idServico = 1,
  }) => service.criarAgendamento(
    Agendamento(
      idCliente: idCliente,
      idBarbeiro: 1,
      idServico: idServico,
      dataHora: DateTime.now().subtract(Duration(days: dias)).toIso8601String(),
      status: status,
    ),
  );

  /// Abre o Início do cliente `c@teste.com`, com o horário e a escolha do
  /// profissional atrás do "Repetir". [historico] roda antes do login.
  Future<void> abrirInicio(
    WidgetTester tester,
    Future<void> Function(int idCliente) historico,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(BookingFlow.limpar);
    SharedPreferences.setMockInitialValues({});
    service.injetarBancoParaTeste(await bancoComSeed(tester));
    await tester.runAsync(() async {
      await historico(await cadastrarClienteTeste());
      await AuthService.instance.login('c@teste.com', 'senha123');
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
          routes: {
            '/barbeiro': (_) => const BarbeiroScreen(),
            '/horario': (_) => const HorarioScreen(),
          },
        ),
      ),
    );
    await esperarBanco(tester);
  }

  testWidgets('o Início mostra o último atendimento concluído no lugar do '
      'acesso rápido; cancelamentos e faltas não contam', (tester) async {
    await abrirInicio(tester, (id) async {
      await atendimentoPassado(
        id,
        dias: 10,
        status: StatusAgendamento.finalizado,
        idServico: 2,
      );
      await atendimentoPassado(
        id,
        dias: 5,
        status: StatusAgendamento.finalizado,
      );
      await atendimentoPassado(
        id,
        dias: 2,
        status: StatusAgendamento.cancelado,
        idServico: 3,
      );
      await atendimentoPassado(
        id,
        dias: 1,
        status: StatusAgendamento.faltou,
        idServico: 3,
      );
    });

    // Antes o Início tinha o acesso rápido, que repetia a barra de navegação.
    expect(find.text('Acesso rápido'), findsNothing);
    expect(find.text('Último serviço'), findsOneWidget);
    expect(find.text('Corte de Cabelo'), findsOneWidget);
    final quando = DateTime.now().subtract(const Duration(days: 5));
    expect(
      find.text('com Carlos Eduardo · ${formatarDataCurta(quando)}'),
      findsOneWidget,
    );
    expect(find.text('Barba'), findsNothing);
    expect(find.text('Corte + Barba'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('sem atendimento concluído, o Início não mostra o último '
      'serviço', (tester) async {
    await abrirInicio(tester, (id) async {
      await atendimentoPassado(
        id,
        dias: 2,
        status: StatusAgendamento.cancelado,
      );
      await atendimentoPassado(id, dias: 1, status: StatusAgendamento.faltou);
    });

    expect(find.text('Nenhum horário marcado'), findsOneWidget);
    expect(find.text('Último serviço'), findsNothing);
    expect(find.text('Repetir'), findsNothing);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('"Repetir" abre o horário com o mesmo serviço e o mesmo '
      'barbeiro já escolhidos', (tester) async {
    await abrirInicio(
      tester,
      (id) =>
          atendimentoPassado(id, dias: 5, status: StatusAgendamento.finalizado),
    );

    await tocarEsperando(tester, find.text('Repetir'));
    await esperarBanco(tester);

    expect(find.byType(HorarioScreen), findsOneWidget);
    expect(find.byType(BarbeiroScreen), findsNothing);
    expect(BookingFlow.servicoSelecionado?.nome, 'Corte de Cabelo');
    expect(BookingFlow.barbeiroSelecionado?.nome, 'Carlos Eduardo');
    expect(BookingFlow.reagendando, isNull);
    await tester.runAsync(AuthService.instance.logout);
  });

  testWidgets('com o barbeiro indisponível, "Repetir" abre a escolha do '
      'profissional com o serviço já escolhido', (tester) async {
    await abrirInicio(tester, (id) async {
      await atendimentoPassado(
        id,
        dias: 5,
        status: StatusAgendamento.finalizado,
      );
      await service.definirBarbeiroAtivo(1, false);
    });

    await tocarEsperando(tester, find.text('Repetir'));
    await esperarBanco(tester);

    expect(find.byType(HorarioScreen), findsNothing);
    expect(find.byType(BarbeiroScreen), findsOneWidget);
    expect(BookingFlow.servicoSelecionado?.nome, 'Corte de Cabelo');
    // Carlos Eduardo aparece apagado, sem seleção: falta escolher outro.
    final continuar = tester.widget<BotaoPrincipal>(
      find.widgetWithText(BotaoPrincipal, 'Continuar'),
    );
    expect(continuar.onPressed, isNull);
    await tester.runAsync(AuthService.instance.logout);
  });
}
