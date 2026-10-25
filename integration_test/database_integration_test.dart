import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/auth_service.dart';
import 'package:sysbarber/services/booking_flow.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/email.dart';
import 'package:sysbarber/services/senhas.dart';
import 'package:sysbarber/services/sms.dart';

/// Administrador criado pela configuração inicial no início de cada teste.
/// Desde a P22 o app não tem mais conta padrão: a senha é escolhida por quem
/// configura a barbearia.
const emailAdmin = 'admin@sysbarber.com';
const senhaAdmin = 'admin1234';

/// Testes de integração do [DatabaseService].
///
/// Cada teste roda contra um banco SQLite **em memória** criado do zero,
/// garantindo isolamento total entre os casos.
void main() {
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Menos iterações só para a suíte rodar rápido; o formato é o mesmo.
    Senhas.iteracoes = 1000;
  });

  setUp(() async {
    service = DatabaseService.instance;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: service.criarSchema,
        // Mesma configuração do aparelho: chaves estrangeiras ligadas.
        onConfigure: DatabaseService.configurar,
      ),
    );
    service.injetarBancoParaTeste(db);
    // Mesmo ponto de partida em todos os testes: barbearia configurada, com
    // os dados de exemplo (3 barbeiros e 5 serviços).
    await service.configurarBarbearia(
      nome: 'Administrador',
      email: emailAdmin,
      telefone: '(67) 99999-0000',
      senha: senhaAdmin,
      aceitouTermos: true,
      dadosDeExemplo: true,
    );
  });

  tearDown(() async => await service.resetarParaTeste());

  /// Todas as contas da tabela de clientes, inclusive a do administrador,
  /// que [DatabaseService.listarClientes] deixa de fora.
  Future<List<Cliente>> todasAsContas() async {
    final db = await service.database;
    return (await db.query('cliente')).map(Cliente.fromMap).toList();
  }

  /// Cadastra um cliente auxiliar e devolve o id gerado.
  Future<int> criarClienteTeste({
    String email = 'novo@teste.com',
    String senha = 'senha123',
  }) {
    return service.cadastrarCliente(
      Cliente(
        nome: 'Novo Cliente',
        email: email,
        telefone: '(67) 98888-1234',
        senhaHash: DatabaseService.hashSenha(senha),
        criadoEm: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Próximo dia em que a barbearia atende, a partir de amanhã: se amanhã for
  /// domingo, é a segunda. Sem isto a suíte falharia quando rodasse num
  /// sábado.
  DateTime proximoDiaDeAtendimento() {
    final amanha = DateTime.now().add(const Duration(days: 1));
    final dia = DatabaseService.atendeNoDia(amanha)
        ? amanha
        : amanha.add(const Duration(days: 1));
    return DateTime(dia.year, dia.month, dia.day);
  }

  // -------------------------------------------------------------------------
  group('Configuração com dados de exemplo', () {
    test('cria os 3 barbeiros', () async {
      final barbeiros = await service.listarBarbeiros();
      expect(barbeiros.length, 3);
      expect(barbeiros.first.nome, 'Carlos Eduardo');
      expect(barbeiros.first.iniciais, 'CE');
    });

    test('cria os 5 serviços', () async {
      final servicos = await service.listarServicos();
      expect(servicos.length, 5);
      expect(servicos.map((s) => s.nome), contains('Corte + Barba'));
      final combo = servicos.firstWhere((s) => s.nome == 'Corte + Barba');
      expect(combo.preco, 55.00);
      expect(combo.duracaoMinutos, 50);
    });

    test('cria a conta administradora com a senha em hash', () async {
      final admin = await service.buscarClientePorEmail(
        emailAdmin,
      );
      expect(admin, isNotNull);
      expect(admin!.nome, 'Administrador');
      expect(admin.admin, isTrue);
      expect(admin.senhaHash, isNot(equals(senhaAdmin)));
      expect(
        Senhas.conferir(senhaAdmin, admin.senhaHash),
        isTrue,
      );
    });

    test('a conta administradora é a única com privilégio', () async {
      final contas = await todasAsContas();
      expect(contas.where((c) => c.admin).length, 1);
      expect(contas.firstWhere((c) => c.admin).email,
          emailAdmin);
    });
  });

  // -------------------------------------------------------------------------
  group('Cadastro e autenticação', () {
    test('cadastra um cliente e o recupera pelo e-mail', () async {
      final id = await criarClienteTeste();
      expect(id, greaterThan(0));

      final salvo = await service.buscarClientePorEmail('novo@teste.com');
      expect(salvo, isNotNull);
      expect(salvo!.nome, 'Novo Cliente');
      expect(salvo.id, id);
    });

    test('autentica com a senha correta e recusa a incorreta', () async {
      await criarClienteTeste(senha: 'senha123');

      final ok = await service.autenticar('novo@teste.com', 'senha123');
      expect(ok, isNotNull);
      expect(ok!.email, 'novo@teste.com');

      final errada = await service.autenticar('novo@teste.com', 'senhaErrada');
      expect(errada, isNull);

      final inexistente = await service.autenticar('ninguem@x.com', 'senha123');
      expect(inexistente, isNull);
    });

    test('emailExiste identifica e-mails já cadastrados', () async {
      expect(await service.emailExiste(emailAdmin), isTrue);
      expect(await service.emailExiste('naocadastrado@teste.com'), isFalse);
    });

    test('cliente cadastrado pelo app nunca nasce administrador', () async {
      final id = await criarClienteTeste();
      final salvo = await service.buscarClientePorId(id);
      expect(salvo!.admin, isFalse);
    });

    test('o cadastro cria o registro de fidelidade com 0 pontos', () async {
      final id = await criarClienteTeste();
      expect(await service.obterPontos(id), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('Agendamentos', () {
    test('cria o agendamento e o recupera com barbeiro e serviço '
        '(INNER JOIN)', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();
      final data = DateTime.now().add(const Duration(days: 1));

      final idAgendamento = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros.first.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime(
            data.year,
            data.month,
            data.day,
            9,
          ).toIso8601String(),
        ),
      );
      expect(idAgendamento, greaterThan(0));

      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.length, 1);
      expect(lista.first.barbeiro, isNotNull);
      expect(lista.first.servico, isNotNull);
      expect(lista.first.barbeiro!.nome, barbeiros.first.nome);
      expect(lista.first.servico!.nome, servicos.first.nome);
      expect(lista.first.status, StatusAgendamento.confirmado);
    });

    test('cancelar o agendamento muda o status', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();

      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros.first.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
        ),
      );

      final linhas = await service.atualizarStatusAgendamento(
        id,
        StatusAgendamento.cancelado,
      );
      expect(linhas, 1);

      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.status, StatusAgendamento.cancelado);
    });

    test('um horário agendado deixa de ficar disponível', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();
      final barbeiro = barbeiros.first;

      final data = proximoDiaDeAtendimento();

      final antes = await service.horariosDisponiveis(barbeiro.id!, data);
      expect(antes, contains('09:00'));
      expect(antes.length, DatabaseService.horariosBase.length);

      final idAgendamento = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime(
            data.year,
            data.month,
            data.day,
            9,
          ).toIso8601String(),
        ),
      );

      final depois = await service.horariosDisponiveis(barbeiro.id!, data);
      expect(depois, isNot(contains('09:00')));
      expect(depois.length, antes.length - 1);

      // Outro barbeiro continua com a grade completa no mesmo dia.
      final outro = await service.horariosDisponiveis(barbeiros[1].id!, data);
      expect(outro, contains('09:00'));

      // Cancelar libera o horário de volta (regra de negócio 2).
      await service.atualizarStatusAgendamento(
        idAgendamento,
        StatusAgendamento.cancelado,
      );
      final liberado = await service.horariosDisponiveis(barbeiro.id!, data);
      expect(liberado, contains('09:00'));
    });
  });

  // -------------------------------------------------------------------------
  group('Fidelidade', () {
    test('adicionar pontos atualiza o saldo e grava o histórico', () async {
      final idCliente = await criarClienteTeste();
      expect(await service.obterPontos(idCliente), 0);

      await service.adicionarPontos(idCliente, 55, 'Pagamento — Corte + Barba');
      expect(await service.obterPontos(idCliente), 55);

      await service.adicionarPontos(idCliente, 35, 'Pagamento — Corte');
      expect(await service.obterPontos(idCliente), 90);

      final historico = await service.listarHistoricoPontos(idCliente);
      expect(historico.length, 2);
      expect(historico.first.pontos, 35);
      expect(historico.last.descricao, 'Pagamento — Corte + Barba');
    });
  });

  // -------------------------------------------------------------------------
  group('CRUD de barbeiros (administração)', () {
    test('o seed traz contato, acesso e salário', () async {
      final b = (await service.listarBarbeiros()).first;
      expect(b.email, 'carlos.eduardo@sysbarber.com');
      expect(b.telefone, isNotEmpty);
      expect(b.salario, greaterThan(0));
      // A senha nunca fica em texto puro.
      expect(b.senhaHash, isNot(equals('barbeiro123')));
      expect(Senhas.conferir('barbeiro123', b.senhaHash), isTrue);
    });

    test('cadastra, edita e exclui um barbeiro', () async {
      final id = await service.cadastrarBarbeiro(
        Barbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          iniciais: Barbeiro.iniciaisDe('Pedro Alves'),
          telefone: '(67) 99404-4004',
          email: 'pedro.alves@sysbarber.com',
          senhaHash: DatabaseService.hashSenha('senha123'),
          salario: 2400.00,
        ),
      );
      expect(id, greaterThan(0));
      expect((await service.listarBarbeiros()).length, 4);

      final salvo = await service.buscarBarbeiroPorEmail(
        'pedro.alves@sysbarber.com',
      );
      expect(salvo!.iniciais, 'PA');
      expect(salvo.salario, 2400.00);

      await service.atualizarDadosDoBarbeiro(
        salvo.id!,
        nome: salvo.nome,
        especialidade: salvo.especialidade,
        salario: 3000.00,
      );
      final editado = await service.buscarBarbeiroPorEmail(
        'pedro.alves@sysbarber.com',
      );
      expect(editado!.salario, 3000.00);

      expect(await service.excluirBarbeiro(id), 1);
      expect((await service.listarBarbeiros()).length, 3);
    });

    test('autentica o barbeiro e recusa senha errada', () async {
      final ok = await service.autenticarBarbeiro(
        'rafael.souza@sysbarber.com',
        'barbeiro123',
      );
      expect(ok, isNotNull);
      expect(ok!.nome, 'Rafael Souza');

      expect(
        await service.autenticarBarbeiro(
          'rafael.souza@sysbarber.com',
          'errada',
        ),
        isNull,
      );
    });

    test('emailBarbeiroExiste ignora o próprio registro na edição', () async {
      final b = (await service.listarBarbeiros()).first;
      expect(await service.emailBarbeiroExiste(b.email), isTrue);
      expect(
        await service.emailBarbeiroExiste(b.email, ignorarId: b.id),
        isFalse,
      );
    });

    test('conta os agendamentos que impedem a exclusão', () async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;

      expect(await service.contarAgendamentosDoBarbeiro(barbeiro.id!), 0);

      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );

      expect(await service.contarAgendamentosDoBarbeiro(barbeiro.id!), 1);
      expect(await service.contarAgendamentosDoServico(servico.id!), 1);
    });
  });

  // -------------------------------------------------------------------------
  group('Pagamento e fidelidade', () {
    /// Cria um agendamento e devolve (idCliente, idAgendamento, valor).
    Future<(int, int, double)> prepararAgendamento() async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );
      return (idCliente, id, servico.preco);
    }

    test('pagamento pendente não credita pontos', () async {
      final (idCliente, idAgendamento, valor) = await prepararAgendamento();

      await service.criarPagamento(
        Pagamento(
          idAgendamento: idAgendamento,
          valor: valor,
          metodo: 'A combinar',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          tipo: 'na_hora',
        ),
      );

      expect(await service.obterPontos(idCliente), 0);
      expect(await service.listarHistoricoPontos(idCliente), isEmpty);
    });

    test('confirmar o pagamento credita os pontos uma única vez', () async {
      final (idCliente, idAgendamento, valor) = await prepararAgendamento();

      final idPagamento = await service.criarPagamento(
        Pagamento(
          idAgendamento: idAgendamento,
          valor: valor,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );

      expect(await service.confirmarPagamento(idPagamento), isTrue);
      expect(await service.obterPontos(idCliente), valor.round());

      // Idempotente: confirmar de novo não duplica os pontos.
      expect(await service.confirmarPagamento(idPagamento), isFalse);
      expect(await service.obterPontos(idCliente), valor.round());
      expect((await service.listarHistoricoPontos(idCliente)).length, 1);
    });

    test('o pagamento guarda apenas os 4 últimos dígitos do cartão', () async {
      final (_, idAgendamento, valor) = await prepararAgendamento();

      await service.criarPagamento(
        Pagamento(
          idAgendamento: idAgendamento,
          valor: valor,
          metodo: 'Cartão',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          cartaoFinal: '1111',
        ),
      );

      final p = await service.buscarPagamentoDoAgendamento(idAgendamento);
      expect(p!.cartaoFinal, '1111');
      expect(p.cartaoFinal!.length, 4);
    });
  });

  // -------------------------------------------------------------------------
  group('Agenda do profissional', () {
    test('lista só os agendamentos do barbeiro, com o cliente', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();
      final amanha = DateTime.now().add(const Duration(days: 1));

      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros.first.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime(
            amanha.year,
            amanha.month,
            amanha.day,
            9,
          ).toIso8601String(),
        ),
      );
      // Este é de outro profissional e não pode aparecer.
      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros[1].id!,
          idServico: servicos[1].id!,
          dataHora: DateTime(
            amanha.year,
            amanha.month,
            amanha.day,
            10,
          ).toIso8601String(),
        ),
      );

      final agenda = await service.listarAgendamentosBarbeiro(
        barbeiros.first.id!,
      );
      expect(agenda.length, 1);
      expect(agenda.first.cliente, isNotNull);
      expect(agenda.first.cliente!.nome, 'Novo Cliente');
      expect(agenda.first.servico!.nome, servicos.first.nome);

      final outra = await service.listarAgendamentosBarbeiro(
        barbeiros[1].id!,
      );
      expect(outra.length, 1);
      expect(outra.first.servico!.nome, servicos[1].nome);
    });

    test('barbeiro sem atendimentos recebe agenda vazia', () async {
      final barbeiros = await service.listarBarbeiros();
      expect(
        await service.listarAgendamentosBarbeiro(barbeiros.last.id!),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Disponibilidade do barbeiro', () {
    test('o seed traz um profissional indisponível', () async {
      final todos = await service.listarBarbeiros();
      final ativos = await service.listarBarbeirosAtivos();

      expect(todos.length, 3);
      expect(ativos.length, 2);
      expect(todos.firstWhere((b) => !b.ativo).nome, 'Marcos Lima');
    });

    test('alternar a disponibilidade muda quem aceita agendamento', () async {
      final b = (await service.listarBarbeirosAtivos()).first;

      expect(await service.definirBarbeiroAtivo(b.id!, false), 1);
      var ativos = await service.listarBarbeirosAtivos();
      expect(ativos.any((x) => x.id == b.id), isFalse);
      // Continua cadastrado, apenas indisponível.
      expect((await service.listarBarbeiros()).length, 3);

      await service.definirBarbeiroAtivo(b.id!, true);
      ativos = await service.listarBarbeirosAtivos();
      expect(ativos.any((x) => x.id == b.id), isTrue);
    });

    test('ficar indisponível não apaga a agenda já assumida', () async {
      final idCliente = await criarClienteTeste();
      final b = (await service.listarBarbeirosAtivos()).first;
      final s = (await service.listarServicos()).first;

      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: b.id!,
          idServico: s.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );

      await service.definirBarbeiroAtivo(b.id!, false);

      // O atendimento marcado continua valendo para os dois lados.
      expect((await service.listarAgendamentosBarbeiro(b.id!)).length, 1);
      expect((await service.listarAgendamentosCliente(idCliente)).length, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('Política de cancelamento', () {
    /// Cria um agendamento daqui a [minutos] e devolve
    /// (idCliente, idAgendamento, preco).
    Future<(int, int, double)> agendarEm(int minutos) async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(Duration(minutes: minutos))
              .toIso8601String(),
        ),
      );
      return (idCliente, id, servico.preco);
    }

    test('dentroDoPrazo separa o limite de 1 hora', () {
      final agora = DateTime(2026, 8, 30, 12, 0);
      expect(
        DatabaseService.dentroDoPrazo(
          agora.add(const Duration(minutes: 61)),
          agora: agora,
        ),
        isTrue,
      );
      expect(
        DatabaseService.dentroDoPrazo(
          agora.add(const Duration(minutes: 59)),
          agora: agora,
        ),
        isFalse,
      );
    });

    test('sem pagamento e no prazo: cancela sem cobrar nada', () async {
      final (_, id, _) = await agendarEm(180);
      final r = await service.cancelarAgendamento(id);

      expect(r.comMulta, isFalse);
      expect(r.multa, 0);
      expect(await service.buscarPagamentoDoAgendamento(id), isNull);
      expect((await service.gerarRelatorio()).cancelados, 1);
    });

    test('sem pagamento e fora do prazo: gera multa a pagar', () async {
      final (_, id, preco) = await agendarEm(30);
      final r = await service.cancelarAgendamento(id);

      expect(r.comMulta, isTrue);
      expect(r.multa, preco * 0.5);
      expect(r.multaAPagar, preco * 0.5);

      final p = await service.buscarPagamentoDoAgendamento(id);
      expect(p!.metodo, DatabaseService.metodoMulta);
      expect(p.pendente, isTrue);
      expect(p.valor, preco * 0.5);

      // A multa devida entra como valor a receber.
      expect((await service.gerarRelatorio()).aReceber, preco * 0.5);
    });

    test('pagamento pendente no prazo: nada fica a receber', () async {
      final (_, id, preco) = await agendarEm(180);
      await service.criarPagamento(
        Pagamento(
          idAgendamento: id,
          valor: preco,
          metodo: 'A combinar',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          tipo: 'na_hora',
        ),
      );

      final r = await service.cancelarAgendamento(id);
      expect(r.comMulta, isFalse);
      expect((await service.gerarRelatorio()).aReceber, 0);
    });

    test('pago e no prazo: estorna tudo e reverte os pontos', () async {
      final (idCliente, id, preco) = await agendarEm(180);
      final idPag = await service.criarPagamento(
        Pagamento(
          idAgendamento: id,
          valor: preco,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );
      await service.confirmarPagamento(idPag);
      expect(await service.obterPontos(idCliente), preco.round());

      final r = await service.cancelarAgendamento(id);

      expect(r.comMulta, isFalse);
      expect(r.estorno, preco);
      expect(r.pontosAjustados, -preco.round());
      expect(await service.obterPontos(idCliente), 0);

      // Pagamento + estorno se anulam: nada sobra no faturamento.
      expect((await service.gerarRelatorio()).faturamento, 0);
    });

    test('pago e fora do prazo: retém 50% e estorna o resto', () async {
      final (idCliente, id, preco) = await agendarEm(30);
      final idPag = await service.criarPagamento(
        Pagamento(
          idAgendamento: id,
          valor: preco,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );
      await service.confirmarPagamento(idPag);

      final r = await service.cancelarAgendamento(id);

      expect(r.comMulta, isTrue);
      expect(r.multa, preco * 0.5);
      expect(r.estorno, preco * 0.5);
      expect(await service.obterPontos(idCliente), 0);

      // Só a multa permanece como receita.
      expect((await service.gerarRelatorio()).faturamento, preco * 0.5);
    });

    test('cancelamento pela barbearia isenta a multa', () async {
      final (_, id, preco) = await agendarEm(30);

      // O mesmo horário multaria o cliente.
      final comoCliente = DatabaseService.dentroDoPrazo(
        DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(comoCliente, isFalse);

      final r = await service.cancelarAgendamento(id, porBarbeiro: true);

      expect(r.comMulta, isFalse);
      expect(r.multa, 0);
      expect(r.multaAPagar, 0);
      expect((await service.gerarRelatorio()).aReceber, 0);
      expect(preco, greaterThan(0));
    });

    test('barbearia cancela em cima da hora: estorno integral', () async {
      final (idCliente, id, preco) = await agendarEm(30);
      final idPag = await service.criarPagamento(
        Pagamento(
          idAgendamento: id,
          valor: preco,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );
      await service.confirmarPagamento(idPag);

      final r = await service.cancelarAgendamento(id, porBarbeiro: true);

      // Nada é retido: o cliente recebe tudo de volta.
      expect(r.estorno, preco);
      expect(r.multa, 0);
      expect((await service.gerarRelatorio()).faturamento, 0);
      expect(await service.obterPontos(idCliente), 0);
    });

    test('serviço resgatado com pontos devolve os pontos', () async {
      final (idCliente, id, _) = await agendarEm(180);
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      await service.resgatarPremio(
        idCliente: idCliente,
        idAgendamento: id,
        nomeServico: 'Corte de Cabelo',
      );
      expect(await service.obterPontos(idCliente), 0);

      final r = await service.cancelarAgendamento(id);

      expect(r.pontosAjustados, DatabaseService.pontosParaPremio);
      expect(await service.obterPontos(idCliente), 500);
    });
  });

  // -------------------------------------------------------------------------
  group('Conclusão do atendimento', () {
    test('finalizarAgendamento atribui o status finalizado', () async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;

      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );

      // Concluído no dia do atendimento (dias antes não é permitido).
      final noDia = DateTime.now().add(const Duration(days: 1));
      expect(await service.finalizarAgendamento(id, agora: noDia), 1);

      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.status, StatusAgendamento.finalizado);

      // O indicador de concluídos deixa de ficar preso em zero.
      final r = await service.gerarRelatorio();
      expect(r.finalizados, 1);
      expect(r.confirmados, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('Forma de recebimento no balcão', () {
    test('confirmarPagamento substitui o método provisório', () async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;

      final idAgendamento = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );

      final idPagamento = await service.criarPagamento(
        Pagamento(
          idAgendamento: idAgendamento,
          valor: servico.preco,
          metodo: 'A combinar',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          tipo: 'na_hora',
        ),
      );

      await service.confirmarPagamento(idPagamento, metodo: 'Dinheiro');

      final p = await service.buscarPagamentoDoAgendamento(idAgendamento);
      expect(p!.metodo, 'Dinheiro');
      expect(p.confirmado, isTrue);

      // 'A combinar' não pode sobrar no relatório por forma de pagamento.
      final r = await service.gerarRelatorio();
      expect(r.porMetodo.map((m) => m.rotulo), isNot(contains('A combinar')));
      expect(r.porMetodo.first.rotulo, 'Dinheiro');
    });
  });

  // -------------------------------------------------------------------------
  group('Horários já passados', () {
    test('não são oferecidos no dia corrente', () async {
      final barbeiro = (await service.listarBarbeiros()).first;
      final agora = DateTime.now();

      final hoje = await service.horariosDisponiveis(barbeiro.id!, agora);
      for (final h in hoje) {
        final partes = h.split(':');
        final horario = DateTime(
          agora.year,
          agora.month,
          agora.day,
          int.parse(partes[0]),
          int.parse(partes[1]),
        );
        expect(
          horario.isAfter(agora),
          isTrue,
          reason: '$h já passou e não deveria estar disponível',
        );
      }
    });

    test('a grade completa continua valendo para dias futuros', () async {
      final barbeiro = (await service.listarBarbeiros()).first;

      final livres = await service.horariosDisponiveis(
        barbeiro.id!,
        proximoDiaDeAtendimento(),
      );
      expect(livres.length, DatabaseService.horariosBase.length);
    });
  });

  // -------------------------------------------------------------------------
  group('Resgate de pontos', () {
    /// Cria um agendamento e devolve (idCliente, idAgendamento, nomeServico).
    Future<(int, int, String)> prepararAgendamento() async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );
      return (idCliente, id, servico.nome);
    }

    test('recusa o resgate quando o saldo é insuficiente', () async {
      final (idCliente, idAgendamento, nome) = await prepararAgendamento();
      await service.adicionarPontos(idCliente, 499, 'Saldo de teste');

      final id = await service.resgatarPremio(
        idCliente: idCliente,
        idAgendamento: idAgendamento,
        nomeServico: nome,
      );

      expect(id, isNull);
      // Nada pode ter sido debitado nem gravado.
      expect(await service.obterPontos(idCliente), 499);
      expect(await service.buscarPagamentoDoAgendamento(idAgendamento), isNull);
    });

    test('debita os pontos e gera pagamento de valor zero', () async {
      final (idCliente, idAgendamento, nome) = await prepararAgendamento();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');

      final id = await service.resgatarPremio(
        idCliente: idCliente,
        idAgendamento: idAgendamento,
        nomeServico: nome,
      );

      expect(id, isNotNull);
      expect(await service.obterPontos(idCliente), 0);

      final p = await service.buscarPagamentoDoAgendamento(idAgendamento);
      expect(p!.valor, 0);
      expect(p.metodo, 'Pontos de fidelidade');
      expect(p.confirmado, isTrue);

      // O resgate precisa aparecer no extrato como saída.
      final extrato = await service.listarHistoricoPontos(idCliente);
      expect(extrato.first.pontos, -500);
      expect(extrato.first.descricao, contains('Resgate'));
    });

    test('o serviço gratuito não entra no faturamento', () async {
      final (idCliente, idAgendamento, nome) = await prepararAgendamento();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      await service.resgatarPremio(
        idCliente: idCliente,
        idAgendamento: idAgendamento,
        nomeServico: nome,
      );

      final r = await service.gerarRelatorio();
      expect(r.faturamento, 0);
      expect(r.aReceber, 0);
    });

    test('premiosDisponiveis acompanha o saldo', () async {
      final idCliente = await criarClienteTeste();
      expect(await service.premiosDisponiveis(idCliente), 0);

      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      expect(await service.premiosDisponiveis(idCliente), 1);

      await service.adicionarPontos(idCliente, 600, 'Saldo de teste');
      expect(await service.premiosDisponiveis(idCliente), 2);
    });
  });

  // -------------------------------------------------------------------------
  group('Painel do dia', () {
    test('conta apenas o movimento da data e ignora cancelados', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();

      final hoje = DateTime.now();
      final amanha = hoje.add(const Duration(days: 1));

      // Vazio antes de qualquer agendamento, mas com os totais preenchidos.
      final inicial = await service.resumoDoDia(hoje);
      expect(inicial.agendamentosHoje, 0);
      expect(inicial.barbeirosTotal, 3);
      expect(inicial.servicosTotal, 5);
      expect(inicial.clientesTotal, greaterThan(0));

      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros.first.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime(
            hoje.year,
            hoje.month,
            hoje.day,
            9,
          ).toIso8601String(),
        ),
      );
      // Este é de amanhã e não pode entrar na conta de hoje.
      await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros[1].id!,
          idServico: servicos[1].id!,
          dataHora: DateTime(
            amanha.year,
            amanha.month,
            amanha.day,
            10,
          ).toIso8601String(),
        ),
      );

      final resumo = await service.resumoDoDia(hoje);
      expect(resumo.agendamentosHoje, 1);
      expect(resumo.barbeirosHoje, 1);
      expect(resumo.clientesHoje, 1);
      expect(resumo.servicosHoje, 1);
      expect(resumo.agendamentosTotal, 2);
    });

    test('agendamento cancelado sai do painel do dia', () async {
      final idCliente = await criarClienteTeste();
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();
      final hoje = DateTime.now();

      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiros.first.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime(
            hoje.year,
            hoje.month,
            hoje.day,
            14,
          ).toIso8601String(),
        ),
      );
      expect((await service.resumoDoDia(hoje)).agendamentosHoje, 1);

      await service.atualizarStatusAgendamento(
        id,
        StatusAgendamento.cancelado,
      );
      expect((await service.resumoDoDia(hoje)).agendamentosHoje, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('Relatórios', () {
    test('consolida faturamento, pendências e rankings', () async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servicos = await service.listarServicos();

      final idA = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servicos.first.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );
      final idB = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servicos[1].id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
        ),
      );

      final pagoA = await service.criarPagamento(
        Pagamento(
          idAgendamento: idA,
          valor: servicos.first.preco,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );
      await service.confirmarPagamento(pagoA);

      await service.criarPagamento(
        Pagamento(
          idAgendamento: idB,
          valor: servicos[1].preco,
          metodo: 'A combinar',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          tipo: 'na_hora',
        ),
      );

      final r = await service.gerarRelatorio();

      // Só o confirmado entra no faturamento.
      expect(r.faturamento, servicos.first.preco);
      expect(r.aReceber, servicos[1].preco);
      expect(r.ticketMedio, servicos.first.preco);
      expect(r.totalAgendamentos, 2);
      expect(r.confirmados, 2);
      expect(r.folhaSalarial, greaterThan(0));
      expect(r.porMetodo.first.rotulo, 'Pix');
      expect(r.porBarbeiro.first.rotulo, barbeiro.nome);
      expect(r.porServico.length, 2);
    });

    test('a taxa de cancelamento acompanha os status', () async {
      final idCliente = await criarClienteTeste();
      final barbeiro = (await service.listarBarbeiros()).first;
      final servico = (await service.listarServicos()).first;

      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: barbeiro.id!,
          idServico: servico.id!,
          dataHora: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        ),
      );
      await service.atualizarStatusAgendamento(
        id,
        StatusAgendamento.cancelado,
      );

      final r = await service.gerarRelatorio();
      expect(r.cancelados, 1);
      expect(r.taxaCancelamento, 100.0);
    });
  });

  // -------------------------------------------------------------------------
  group('CRUD de serviços (administração)', () {
    test('cadastra, edita e exclui um serviço', () async {
      // CREATE — passa de 5 para 6 serviços.
      final id = await service.cadastrarServico(
        const Servico(
          nome: 'Sobrancelha',
          descricao: 'Design masculino',
          preco: 20.00,
          duracaoMinutos: 15,
          icone: '🪞',
        ),
      );
      expect(id, greaterThan(0));
      expect((await service.listarServicos()).length, 6);

      // UPDATE — o preço e o nome são alterados.
      final linhas = await service.atualizarServico(
        Servico(
          id: id,
          nome: 'Sobrancelha Premium',
          descricao: 'Design masculino detalhado',
          preco: 30.00,
          duracaoMinutos: 20,
          icone: '🪞',
        ),
      );
      expect(linhas, 1);

      final editado = (await service.listarServicos()).firstWhere(
        (s) => s.id == id,
      );
      expect(editado.nome, 'Sobrancelha Premium');
      expect(editado.preco, 30.00);
      expect(editado.duracaoMinutos, 20);

      // DELETE — volta para os 5 serviços do seed.
      final excluidas = await service.excluirServico(id);
      expect(excluidas, 1);
      expect((await service.listarServicos()).length, 5);
    });
  });

  // =========================================================================
  // CORREÇÕES DA AUDITORIA
  // =========================================================================

  /// O saldo de pontos precisa bater com a soma do extrato — qualquer
  /// atualização perdida quebra essa igualdade.
  Future<void> expectSaldoConfereComExtrato(int idCliente) async {
    final saldo = await service.obterPontos(idCliente);
    final extrato = await service.listarHistoricoPontos(idCliente);
    final soma = extrato.fold<int>(0, (t, h) => t + h.pontos);
    expect(saldo, soma, reason: 'saldo $saldo difere do extrato $soma');
  }

  /// Agendamento de teste no próximo dia de atendimento, no horário informado.
  Future<int> agendarNoProximoDia(
    int idCliente, {
    int hora = 9,
    int minuto = 0,
    int idBarbeiro = 1,
    int idServico = 1,
  }) {
    final d = proximoDiaDeAtendimento();
    return service.criarAgendamento(
      Agendamento(
        idCliente: idCliente,
        idBarbeiro: idBarbeiro,
        idServico: idServico,
        dataHora: DateTime(d.year, d.month, d.day, hora, minuto)
            .toIso8601String(),
      ),
    );
  }

  group('Correção 1 — transações e pontos atômicos', () {
    test('créditos simultâneos não se perdem', () async {
      final idCliente = await criarClienteTeste();

      await Future.wait([
        for (var i = 0; i < 10; i++)
          service.adicionarPontos(idCliente, 10, 'Crédito $i'),
      ]);

      expect(await service.obterPontos(idCliente), 100);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('resgates simultâneos não gastam o mesmo saldo duas vezes', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      final a1 = await agendarNoProximoDia(idCliente, hora: 9);
      final a2 = await agendarNoProximoDia(idCliente, hora: 14);

      final ids = await Future.wait([
        service.resgatarPremio(
          idCliente: idCliente,
          idAgendamento: a1,
          nomeServico: 'Corte',
        ),
        service.resgatarPremio(
          idCliente: idCliente,
          idAgendamento: a2,
          nomeServico: 'Corte',
        ),
      ]);

      // Com saldo para um único prêmio, só um resgate pode passar.
      expect(ids.whereType<int>().length, 1);
      expect(await service.obterPontos(idCliente), 0);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('confirmações simultâneas creditam os pontos uma vez', () async {
      final idCliente = await criarClienteTeste();
      final a = await agendarNoProximoDia(idCliente);
      final p = await service.criarPagamento(
        Pagamento(
          idAgendamento: a,
          valor: 35,
          metodo: 'Pix',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );

      final r = await Future.wait([
        service.confirmarPagamento(p),
        service.confirmarPagamento(p),
      ]);

      expect(r.where((ok) => ok).length, 1);
      expect(await service.obterPontos(idCliente), 35);
      await expectSaldoConfereComExtrato(idCliente);
    });
  });

  /// Próximo dia de atendimento no horário informado.
  DateTime proximoDiaAs(int hora, [int minuto = 0]) {
    final d = proximoDiaDeAtendimento();
    return DateTime(d.year, d.month, d.day, hora, minuto);
  }

  group('Correção 2 — reserva atômica (agendamento + pagamento)', () {
    test('pagar agora grava os dois registros e credita os pontos', () async {
      final idCliente = await criarClienteTeste();

      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // Corte + Barba, R$ 55
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Cartão',
        cartaoFinal: '1111',
      );

      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.confirmado, isTrue);
      expect(p.valor, 55);
      expect(p.metodo, 'Cartão');
      expect(p.cartaoFinal, '1111');
      expect(r.pontosCreditados, 55);
      expect(await service.obterPontos(idCliente), 55);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('pagar na barbearia deixa pendente e não pontua', () async {
      final idCliente = await criarClienteTeste();

      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.pendente, isTrue);
      expect(p.metodo, 'A combinar');
      expect(p.tipo, TipoPagamento.naHora.dbValue);
      expect(await service.obterPontos(idCliente), 0);
    });

    test('resgate por pontos debita o saldo e gera pagamento zero', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 520, 'Saldo de teste');

      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 5,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.resgatarPontos,
      );

      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.valor, 0);
      expect(p.metodo, 'Pontos de fidelidade');
      expect(r.pontosDebitados, 500);
      expect(r.saldoPontos, 20);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('saldo insuficiente não deixa agendamento órfão', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 499, 'Saldo de teste');

      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: proximoDiaAs(9),
          modo: ModoReserva.resgatarPontos,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.contarAgendamentos(), 0);
      expect(await service.obterPontos(idCliente), 499);
    });

    test('horário ocupado recusa a reserva sem gravar nada', () async {
      final c1 = await criarClienteTeste();
      final c2 = await criarClienteTeste(email: 'outro@teste.com');
      await service.reservar(
        idCliente: c1,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(10),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: c2,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: proximoDiaAs(10),
          modo: ModoReserva.pagarAgora,
          metodo: 'Pix',
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.contarAgendamentos(), 1);
      expect(await service.obterPontos(c2), 0);
    });

    test('barbeiro indisponível não recebe reserva nem oferece horário',
        () async {
      final idCliente = await criarClienteTeste();
      final inativo = (await service.listarBarbeiros()).firstWhere(
        (b) => !b.ativo,
      );

      expect(
        await service.horariosDisponiveis(inativo.id!, proximoDiaAs(0)),
        isEmpty,
      );
      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: inativo.id!,
          idServico: 1,
          dataHora: proximoDiaAs(9),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.contarAgendamentos(), 0);
    });

    test('horário que já passou é recusado', () async {
      final idCliente = await criarClienteTeste();
      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: DateTime.now().subtract(const Duration(hours: 1)),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
    });

    test('o valor cobrado vem do banco, não da tela', () async {
      final idCliente = await criarClienteTeste();
      final corte = (await service.listarServicos()).first;
      // O admin reajusta o preço enquanto o cliente está no fluxo.
      await service.atualizarServico(corte.copyWith(preco: 40));

      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: corte.id!,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );

      expect(r.valor, 40);
      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.valor, 40);
    });

    test('verificarReserva antecipa o impedimento sem gravar', () async {
      final idCliente = await criarClienteTeste();
      expect(
        await service.verificarReserva(idBarbeiro: 1, dataHora: proximoDiaAs(9)),
        isNull,
      );
      await agendarNoProximoDia(idCliente, hora: 9);
      expect(
        await service.verificarReserva(idBarbeiro: 1, dataHora: proximoDiaAs(9)),
        isNotNull,
      );
      expect(await service.contarAgendamentos(), 1);
    });
  });

  group('Correção 3 — pagamentos cancelados e multas', () {
    test('pagamento cancelado não pode ser recebido', () async {
      final idCliente = await criarClienteTeste();
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      await service.cancelarAgendamento(r.idAgendamento); // no prazo

      final cancelado = await service.buscarPagamentoDoAgendamento(
        r.idAgendamento,
      );
      expect(cancelado!.cancelado, isTrue);

      // Antes: virava 'Confirmado', creditava 55 pontos e R$ 55 de receita.
      expect(
        await service.confirmarPagamento(r.idPagamento, metodo: 'Pix'),
        isFalse,
      );
      expect(await service.obterPontos(idCliente), 0);
      expect((await service.gerarRelatorio()).faturamento, 0);
    });

    test('quitar a multa não gera pontos e mantém a identificação', () async {
      final idCliente = await criarClienteTeste();
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 3,
          dataHora: DateTime.now()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        ),
      );
      await service.cancelarAgendamento(id); // fora do prazo: multa 27,50

      final multa = await service.buscarPagamentoDoAgendamento(id);
      expect(multa!.natureza, NaturezaPagamento.multa);
      expect(await service.confirmarPagamento(multa.id!, metodo: 'Pix'), isTrue);

      final quitada = await service.buscarPagamentoDoAgendamento(id);
      expect(quitada!.confirmado, isTrue);
      expect(quitada.metodo, 'Pix');
      expect(quitada.natureza, NaturezaPagamento.multa);
      // Multa é receita, mas não é serviço prestado: não pontua.
      expect(await service.obterPontos(idCliente), 0);
      expect((await service.gerarRelatorio()).faturamento, 27.5);
    });

    test('estorno e resgate ficam identificados pela natureza', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      final pago = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      final gratis = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.resgatarPontos,
      );
      await service.cancelarAgendamento(pago.idAgendamento);

      final todos = await service.listarPagamentos();
      NaturezaPagamento natureza(int idAgendamento, double valor) => todos
          .firstWhere(
            (p) => p.idAgendamento == idAgendamento && p.valor == valor,
          )
          .natureza;

      expect(natureza(pago.idAgendamento, 35), NaturezaPagamento.servico);
      expect(natureza(pago.idAgendamento, -35), NaturezaPagamento.estorno);
      expect(natureza(gratis.idAgendamento, 0), NaturezaPagamento.resgate);
    });
  });

  group('Correção 4 — conclusão do atendimento e estados', () {
    test('não se conclui um atendimento dias antes', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarNoProximoDia(idCliente);

      await expectLater(
        service.finalizarAgendamento(id),
        throwsA(isA<RegraNegocioException>()),
      );
      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.status, StatusAgendamento.confirmado);
    });

    test('conclui depois do horário marcado', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarNoProximoDia(idCliente, hora: 9);

      // Antes a opção sumia da tela exatamente neste momento.
      final depois = proximoDiaAs(11);
      expect(await service.finalizarAgendamento(id, agora: depois), 1);
    });

    test('atendimento concluído não pode ser cancelado nem estornado',
        () async {
      final idCliente = await criarClienteTeste();
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.finalizarAgendamento(r.idAgendamento, agora: proximoDiaAs(10));

      await expectLater(
        service.cancelarAgendamento(r.idAgendamento, porBarbeiro: true),
        throwsA(isA<RegraNegocioException>()),
      );
      expect((await service.gerarRelatorio()).faturamento, 55);
      expect(await service.obterPontos(idCliente), 55);
    });

    test('cancelar duas vezes é recusado', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarNoProximoDia(idCliente);
      await service.cancelarAgendamento(id);

      await expectLater(
        service.cancelarAgendamento(id),
        throwsA(isA<RegraNegocioException>()),
      );
    });

    test('falta só é registrada depois do horário e cobra multa', () async {
      final idCliente = await criarClienteTeste();
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // R$ 55
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.registrarFalta(r.idAgendamento, agora: proximoDiaAs(8)),
        throwsA(isA<RegraNegocioException>()),
      );

      final resultado = await service.registrarFalta(
        r.idAgendamento,
        agora: proximoDiaAs(10),
      );
      expect(resultado.multaAPagar, 27.5);

      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.status, StatusAgendamento.faltou);
      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.natureza, NaturezaPagamento.multa);
      expect(p.pendente, isTrue);

      final rel = await service.gerarRelatorio();
      expect(rel.faltas, 1);
      expect(rel.confirmados, 0);
    });
  });

  group('Correção 5 — estorno de pontos que já foram gastos', () {
    test('cancelar o serviço pago depois de usar os pontos deixa saldo '
        'devedor', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 460, 'Saldo de teste');
      final pago = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // R$ 55 → 515 pontos
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 5, // prêmio → sobram 15 pontos
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.resgatarPontos,
      );

      final r = await service.cancelarAgendamento(pago.idAgendamento);

      // Antes: só 15 pontos eram revertidos e o prêmio saía por 460.
      expect(r.estorno, 55);
      expect(r.pontosAjustados, -55);
      expect(await service.obterPontos(idCliente), -40);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('saldo devedor não libera prêmio', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, -600, 'Estorno de teste');

      expect(await service.premiosDisponiveis(idCliente), 0);
      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: proximoDiaAs(9),
          modo: ModoReserva.resgatarPontos,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
    });
  });

  group('Correção 6 — duração do serviço e sobreposição', () {
    test('serviço longo bloqueia os horários que ele ocupa', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 5, // Coloração, 60 min
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      final livres = await service.horariosDisponiveis(1, proximoDiaAs(0));
      expect(livres, isNot(contains('09:00')));
      expect(livres, isNot(contains('09:30'))); // antes: oferecido
      expect(livres, contains('10:00'));
    });

    test('serviço longo não é oferecido onde não cabe', () async {
      final idCliente = await criarClienteTeste();
      await agendarNoProximoDia(idCliente, hora: 10); // Corte, 30 min

      final livres = await service.horariosDisponiveis(
        1,
        proximoDiaAs(0),
        duracaoMinutos: 60,
      );
      expect(livres, contains('09:00')); // 09:00–10:00 cabe
      expect(livres, isNot(contains('09:30'))); // 09:30–10:30 invade
    });

    test('reserva que invade outro atendimento é recusada', () async {
      final c1 = await criarClienteTeste();
      final c2 = await criarClienteTeste(email: 'outro@teste.com');
      await service.reservar(
        idCliente: c1,
        idBarbeiro: 1,
        idServico: 5,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: c2,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: proximoDiaAs(9, 30),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
    });

    test('cliente não marca dois horários ao mesmo tempo', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // 50 min: 09:00–09:50
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 2,
          idServico: 1,
          dataHora: proximoDiaAs(9, 30),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      // Na grade do cliente, o horário também some.
      final livres = await service.horariosDisponiveis(
        2,
        proximoDiaAs(0),
        idCliente: idCliente,
      );
      expect(livres, isNot(contains('09:30')));
      expect(livres, contains('10:00'));
    });

    test('o banco recusa dois agendamentos no mesmo horário', () async {
      final idCliente = await criarClienteTeste();
      await agendarNoProximoDia(idCliente, hora: 11);

      await expectLater(
        agendarNoProximoDia(idCliente, hora: 11),
        throwsA(isA<DatabaseException>()),
      );
      expect(await service.contarAgendamentos(), 1);
    });

    test('a duração fica registrada no agendamento', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 5,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      // Encurtar o serviço depois não libera o que já foi marcado.
      final coloracao = (await service.listarServicos()).firstWhere(
        (s) => s.id == 5,
      );
      await service.atualizarServico(coloracao.copyWith(duracaoMinutos: 30));

      final livres = await service.horariosDisponiveis(1, proximoDiaAs(0));
      expect(livres, isNot(contains('09:30')));
      final agenda = await service.listarAgendamentosCliente(idCliente);
      expect(agenda.first.duracaoMinutos, 60);
    });
  });

  group('Correção 7 — editar barbeiro preserva a disponibilidade', () {
    test('salvar o cadastro de um indisponível não o reativa', () async {
      final inativo = (await service.listarBarbeiros()).firstWhere(
        (b) => !b.ativo,
      );

      // O formulário monta um Barbeiro novo a partir dos campos; antes o
      // `ativo` padrão (true) ia junto e reativava o profissional.
      await service.atualizarDadosDoBarbeiro(
        inativo.id!,
        nome: inativo.nome,
        especialidade: 'Coloração, Corte e Barba',
        salario: 2700,
      );

      final depois = (await service.listarBarbeiros()).firstWhere(
        (b) => b.id == inativo.id,
      );
      expect(depois.especialidade, 'Coloração, Corte e Barba');
      expect(depois.salario, 2700);
      expect(depois.ativo, isFalse);
    });

    test('a disponibilidade muda só pelo interruptor', () async {
      final inativo = (await service.listarBarbeiros()).firstWhere(
        (b) => !b.ativo,
      );
      await service.definirBarbeiroAtivo(inativo.id!, true);
      final depois = (await service.listarBarbeiros()).firstWhere(
        (b) => b.id == inativo.id,
      );
      expect(depois.ativo, isTrue);
    });
  });

  group('Correção 8 — preço registrado no agendamento', () {
    test('reajuste do serviço não muda a multa de quem já agendou', () async {
      final idCliente = await criarClienteTeste();
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 3, // R$ 55 na hora de agendar
          dataHora: DateTime.now()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        ),
      );
      final combo = (await service.listarServicos()).firstWhere(
        (s) => s.id == 3,
      );
      await service.atualizarServico(combo.copyWith(preco: 100));

      final r = await service.cancelarAgendamento(id); // fora do prazo
      expect(r.multa, 27.5); // 50% de 55, não de 100
    });

    test('a listagem mostra o valor da época do agendamento', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1, // R$ 35
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      final corte = (await service.listarServicos()).first;
      await service.atualizarServico(corte.copyWith(preco: 50));

      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.preco, 35);
      expect(lista.first.valor, 35);
      final agenda = await service.listarAgendamentosBarbeiro(1);
      expect(agenda.first.valor, 35);
    });
  });

  group('Correção 9 — relatórios', () {
    test('estorno não distorce ticket médio nem forma de pagamento', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1, // R$ 35
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      final estornado = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // R$ 55, cancelado no prazo
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.cancelarAgendamento(estornado.idAgendamento);

      final r = await service.gerarRelatorio();
      expect(r.faturamento, 35);
      expect(r.ticketMedio, 35); // antes: 11,67
      final pix = r.porMetodo.firstWhere((m) => m.rotulo == 'Pix');
      expect(pix.valor, 35); // antes: 90, com o estorno numa linha à parte
      expect(r.porMetodo.where((m) => m.rotulo.startsWith('Estorno')), isEmpty);
    });

    test('resgate não entra no ticket nem nas formas de pagamento', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 5,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.resgatarPontos,
      );
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.pagarAgora,
        metodo: 'Cartão',
      );

      final r = await service.gerarRelatorio();
      expect(r.ticketMedio, 35);
      expect(r.porMetodo.map((m) => m.rotulo), ['Cartão']);
    });

    test('multa quitada entra pela forma em que foi paga', () async {
      final idCliente = await criarClienteTeste();
      final id = await service.criarAgendamento(
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 3,
          dataHora: DateTime.now()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        ),
      );
      await service.cancelarAgendamento(id);
      final multa = await service.buscarPagamentoDoAgendamento(id);
      await service.confirmarPagamento(multa!.id!, metodo: 'Dinheiro');

      final r = await service.gerarRelatorio();
      expect(r.faturamento, 27.5);
      expect(r.porMetodo.single.rotulo, 'Dinheiro');
      expect(r.porMetodo.single.valor, 27.5);
      // Multa não é atendimento: não entra no ticket médio.
      expect(r.ticketMedio, 0);
    });

    test('filtra pelo período', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarNoProximoDia(idCliente);
      final agora = DateTime.now();
      final inicioMes = DateTime(agora.year, agora.month);
      final proximoMes = DateTime(agora.year, agora.month + 1);
      await service.criarPagamento(
        Pagamento(
          idAgendamento: id,
          valor: 35,
          metodo: 'Pix',
          criadoEm: inicioMes
              .subtract(const Duration(days: 3))
              .toIso8601String(),
        ),
      );

      final doMes = await service.gerarRelatorio(
        inicio: inicioMes,
        fim: proximoMes,
      );
      expect(doMes.faturamento, 0);

      final geral = await service.gerarRelatorio();
      expect(geral.faturamento, 35);
    });
  });

  group('Correção 10 — pagamento do agendamento na listagem', () {
    test('depois do estorno, o pagamento do agendamento segue o original',
        () async {
      final idCliente = await criarClienteTeste();
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // R$ 55
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      // Cancelado 30 min antes: retém 27,50 e estorna 27,50.
      await service.cancelarAgendamento(
        r.idAgendamento,
        agora: proximoDiaAs(8, 30),
      );

      // Antes devolvia o estorno, e a tela mostrava "Pago via Estorno".
      final p = await service.buscarPagamentoDoAgendamento(r.idAgendamento);
      expect(p!.natureza, NaturezaPagamento.servico);
      expect(p.valor, 55);

      final a = (await service.listarAgendamentosCliente(idCliente)).first;
      expect(a.pagamento!.metodo, 'Pix');
      expect(a.pagamento!.confirmado, isTrue);
      expect(a.valorEstornado, 27.5);
    });

    test('a listagem já traz o pagamento de cada agendamento', () async {
      final idCliente = await criarClienteTeste();
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      await agendarNoProximoDia(idCliente, hora: 14); // sem pagamento

      final lista = await service.listarAgendamentosCliente(idCliente);
      final comPagamento = lista.firstWhere((a) => a.data.hour == 9);
      final semPagamento = lista.firstWhere((a) => a.data.hour == 14);
      expect(comPagamento.pagamento!.pendente, isTrue);
      expect(semPagamento.pagamento, isNull);
      expect(semPagamento.valorEstornado, 0);

      final agenda = await service.listarAgendamentosBarbeiro(1);
      expect(agenda.where((a) => a.pagamento != null).length, 1);
    });

    test('não aceita um segundo pagamento do mesmo serviço', () async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );

      await expectLater(
        service.criarPagamento(
          Pagamento(
            idAgendamento: r.idAgendamento,
            valor: 35,
            metodo: 'Dinheiro',
            criadoEm: DateTime.now().toIso8601String(),
          ),
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      // Resgatar um serviço que já foi pago também não passa — e não debita.
      await expectLater(
        service.resgatarPremio(
          idCliente: idCliente,
          idAgendamento: r.idAgendamento,
          nomeServico: 'Corte',
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.obterPontos(idCliente), 535);
    });

    test('a agenda do barbeiro não carrega a senha dos clientes', () async {
      final idCliente = await criarClienteTeste();
      await agendarNoProximoDia(idCliente);

      final agenda = await service.listarAgendamentosBarbeiro(1);
      expect(agenda.first.cliente!.nome, 'Novo Cliente');
      expect(agenda.first.cliente!.senhaHash, isEmpty);
    });
  });

  group('Correção 11 — senhas com salt individual', () {
    test('senhas de contas diferentes não compartilham hash', () async {
      final a = await criarClienteTeste(email: 'a@teste.com', senha: 'igual123');
      final b = await criarClienteTeste(email: 'b@teste.com', senha: 'igual123');
      final ca = await service.buscarClientePorId(a);
      final cb = await service.buscarClientePorId(b);
      expect(ca!.senhaHash, isNot(equals(cb!.senhaHash)));
    });

    test('hash antigo entra e é atualizado no primeiro login', () async {
      final id = await service.cadastrarCliente(
        Cliente(
          nome: 'Cliente Antigo',
          email: 'antigo@teste.com',
          telefone: '(67) 98888-1234',
          senhaHash: Senhas.hashLegado('senha123'),
          criadoEm: DateTime.now().toIso8601String(),
        ),
      );

      expect(await service.autenticar('antigo@teste.com', 'errada'), isNull);
      expect(await service.autenticar('antigo@teste.com', 'senha123'), isNotNull);

      final depois = await service.buscarClientePorId(id);
      expect(depois!.senhaHash, startsWith('pbkdf2-sha256\$'));
      expect(await service.autenticar('antigo@teste.com', 'senha123'), isNotNull);
    });

    test('o barbeiro com hash antigo também é atualizado', () async {
      final b = (await service.listarBarbeiros()).first;
      final db = await service.database;
      await db.update(
        'barbeiro',
        {'senha_hash': Senhas.hashLegado('barbeiro123')},
        where: 'id = ?',
        whereArgs: [b.id],
      );

      expect(
        await service.autenticarBarbeiro(b.email, 'barbeiro123'),
        isNotNull,
      );
      final depois = await service.buscarBarbeiroPorEmail(b.email);
      expect(depois!.senhaHash, startsWith('pbkdf2-sha256\$'));
    });
  });

  group('Correção 12 — migração de bancos antigos', () {
    /// Banco exatamente como a versão 2 do app o deixava.
    Future<Database> bancoV2() => databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        // Um banco em memória separado do que o serviço já tem aberto.
        singleInstance: false,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE cliente (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
              telefone TEXT NOT NULL, senha_hash TEXT NOT NULL,
              criado_em TEXT NOT NULL)''');
          await db.execute('''
            CREATE TABLE barbeiro (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL, especialidade TEXT NOT NULL,
              avaliacao REAL NOT NULL DEFAULT 0,
              avaliacoes INTEGER NOT NULL DEFAULT 0,
              iniciais TEXT NOT NULL,
              telefone TEXT NOT NULL DEFAULT '',
              email TEXT NOT NULL DEFAULT '',
              senha_hash TEXT NOT NULL DEFAULT '',
              salario REAL NOT NULL DEFAULT 0)''');
          await db.execute('''
            CREATE TABLE servico (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL, descricao TEXT NOT NULL,
              preco REAL NOT NULL, duracao_minutos INTEGER NOT NULL,
              icone TEXT NOT NULL)''');
          await db.execute('''
            CREATE TABLE agendamento (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_cliente INTEGER NOT NULL, id_barbeiro INTEGER NOT NULL,
              id_servico INTEGER NOT NULL, data_hora TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'confirmado')''');
          await db.execute('''
            CREATE TABLE pagamento (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_agendamento INTEGER NOT NULL, valor REAL NOT NULL,
              metodo TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'Confirmado',
              criado_em TEXT NOT NULL,
              tipo TEXT NOT NULL DEFAULT 'antecipado',
              cartao_final TEXT)''');
          await db.execute('''
            CREATE TABLE fidelidade (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_cliente INTEGER NOT NULL UNIQUE,
              pontos INTEGER NOT NULL DEFAULT 0)''');
          await db.execute('''
            CREATE TABLE historico_ponto (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_cliente INTEGER NOT NULL, descricao TEXT NOT NULL,
              pontos INTEGER NOT NULL, criado_em TEXT NOT NULL)''');
        },
      ),
    );

    Future<int> inserirCliente(Database db, String email) =>
        db.insert('cliente', {
          'nome': 'Conta $email',
          'email': email,
          'telefone': '(67) 90000-0000',
          'senha_hash': Senhas.hashLegado('senha123'),
          'criado_em': '2026-01-01T10:00:00.000',
        });

    Future<List<Map<String, Object?>>> admins(Database db) =>
        db.query('cliente', where: 'admin = 1');

    test('a migração não cria nem promove administrador: o app pede a '
        'configuração inicial', () async {
      final db = await bancoV2();
      // A antiga conta demo e um cliente que usava o antigo e-mail oficial.
      await inserirCliente(db, 'demo@sysbarber.com');
      await inserirCliente(db, 'admin@sysbarber.com');

      await service.migrar(db, 2, DatabaseService.versaoBanco);

      // Antes, a migração promovia (ou criava) um administrador com a senha
      // padrão admin1234. Agora ninguém é promovido: sem administrador, o
      // app abre na configuração inicial.
      expect(await admins(db), isEmpty);
      expect((await db.query('cliente')).length, 2);
      await db.close();
    });

    test('v2 → atual preserva e completa os dados financeiros', () async {
      final db = await bancoV2();
      final idCliente = await inserirCliente(db, 'demo@sysbarber.com');
      await db.insert('barbeiro', {
        'nome': 'Carlos Eduardo',
        'especialidade': 'Barba',
        'iniciais': 'CE',
      });
      await db.insert('servico', {
        'nome': 'Coloração',
        'descricao': 'Tintura',
        'preco': 80.0,
        'duracao_minutos': 60,
        'icone': '🎨',
      });
      final idA = await db.insert('agendamento', {
        'id_cliente': idCliente,
        'id_barbeiro': 1,
        'id_servico': 1,
        'data_hora': '2026-01-10T09:00:00.000',
        'status': 'cancelado',
      });
      Future<void> pagamento(double valor, String metodo, String status) =>
          db.insert('pagamento', {
            'id_agendamento': idA,
            'valor': valor,
            'metodo': metodo,
            'status': status,
            'criado_em': '2026-01-09T10:00:00.000',
          });
      await pagamento(80, 'Cartão', 'Confirmado');
      await pagamento(-40, 'Estorno (multa retida)', 'Confirmado');
      await pagamento(40, 'Multa por cancelamento', 'Pendente');
      await pagamento(0, 'Pontos de fidelidade', 'Cancelado');

      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final pagamentos = (await db.query('pagamento', orderBy: 'id'))
          .map(Pagamento.fromMap)
          .toList();
      expect(pagamentos.map((p) => p.natureza), [
        NaturezaPagamento.servico,
        NaturezaPagamento.estorno,
        NaturezaPagamento.multa,
        NaturezaPagamento.resgate,
      ]);
      // O estorno antigo passa a sair pela forma do pagamento original.
      expect(pagamentos[1].metodo, 'Cartão');

      final agendamento = Agendamento.fromMap(
        (await db.query('agendamento')).single,
      );
      expect(agendamento.duracaoMinutos, 60);
      expect(agendamento.preco, 80);

      final barbeiro = Barbeiro.fromMap((await db.query('barbeiro')).single);
      expect(barbeiro.ativo, isTrue);

      final indice = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['index', 'idx_agendamento_horario'],
      );
      expect(indice, hasLength(1));
      await db.close();
    });

    test('a migração cria a tabela dos códigos para criar uma senha nova '
        '(v6)', () async {
      final db = await bancoV2();
      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final tabela = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'codigo_senha'],
      );
      expect(tabela, hasLength(1));
      await db.close();
    });

    test('a migração cria a tabela dos convites do barbeiro (v7)', () async {
      final db = await bancoV2();
      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final tabela = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'convite_barbeiro'],
      );
      expect(tabela, hasLength(1));
      await db.close();
    });

    test('a migração v8 guarda o aceite dos termos e a exclusão da conta, e '
        'ninguém antigo aparece como tendo aceitado', () async {
      final db = await bancoV2();
      await service.migrar(db, 2, DatabaseService.versaoBanco);

      Future<List<String>> colunas(String tabela) async =>
          (await db.rawQuery('PRAGMA table_info($tabela)'))
              .map((c) => c['name'] as String)
              .toList();
      expect(
        await colunas('cliente'),
        containsAll(['termos_aceitos_em', 'excluido_em']),
      );
      expect(await colunas('barbeiro'), contains('termos_aceitos_em'));
      final aceitos = await db.query(
        'cliente',
        where: 'termos_aceitos_em IS NOT NULL',
      );
      expect(aceitos, isEmpty);
      await db.close();
    });
  });

  group('Correção 13 — sessão do barbeiro e acesso às rotas', () {
    final auth = AuthService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
      await auth.carregarConfiguracao();
    });

    /// Simula fechar e abrir o app: a memória some, o que foi salvo fica.
    Future<void> reiniciarApp() async {
      auth.esquecerSessaoEmMemoria();
      await auth.carregarSessao();
    }

    test('a sessão do barbeiro sobrevive ao reinício', () async {
      final r = await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');
      expect(r.sucesso, isTrue);

      await reiniciarApp();

      // Antes: o login do barbeiro não era salvo e ele caía na tela inicial.
      expect(auth.estaLogado, isTrue);
      expect(auth.ehBarbeiro, isTrue);
      expect(auth.barbeiroAtual!.nome, 'Rafael Souza');
      // E não existe mais um "cliente" falso com id nulo.
      expect(auth.usuarioAtual, isNull);
      // A área principal, com as abas dele (Agenda e Perfil).
      expect(auth.rotaInicial, '/home');
    });

    test('a sessão do cliente continua sendo restaurada', () async {
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');

      await reiniciarApp();

      expect(auth.ehBarbeiro, isFalse);
      expect(auth.usuarioAtual!.email, 'novo@teste.com');
      expect(auth.rotaInicial, '/home');
    });

    test('sessão salva por versões antigas (só o id) é de cliente', () async {
      final id = await criarClienteTeste();
      SharedPreferences.setMockInitialValues({AuthService.chaveSessao: id});

      await reiniciarApp();

      expect(auth.usuarioAtual!.id, id);
      expect(auth.ehBarbeiro, isFalse);
    });

    test('barbeiro excluído perde a sessão salva', () async {
      final novo = await service.cadastrarBarbeiro(
        Barbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          iniciais: 'PA',
          email: 'pedro@sysbarber.com',
          senhaHash: DatabaseService.hashSenha('senha123'),
          salario: 2000,
        ),
      );
      await auth.login('pedro@sysbarber.com', 'senha123');
      await service.excluirBarbeiro(novo);

      await reiniciarApp();

      expect(auth.estaLogado, isFalse);
    });

    test('cada perfil só abre as próprias rotas', () async {
      // Ninguém logado.
      expect(auth.podeAcessar('/login'), isTrue);
      expect(auth.podeAcessar('/recuperar-senha'), isTrue);
      expect(auth.podeAcessar('/home'), isFalse);
      expect(auth.podeAcessar('/admin'), isFalse);

      // Cliente comum.
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');
      expect(auth.podeAcessar('/home'), isTrue);
      expect(auth.podeAcessar('/pagamento'), isTrue);
      expect(auth.podeAcessar('/agendamentos'), isTrue);
      expect(auth.podeAcessar('/fidelidade'), isTrue);
      expect(auth.podeAcessar('/perfil'), isTrue);
      expect(auth.podeAcessar('/admin'), isFalse);

      // Administrador: só gerencia, não agenda nem tem Fidelidade.
      await auth.login(emailAdmin, senhaAdmin);
      expect(auth.podeAcessar('/home'), isTrue);
      expect(auth.podeAcessar('/admin'), isTrue);
      expect(auth.podeAcessar('/perfil'), isTrue);
      for (final rota in [
        '/servicos',
        '/barbeiro',
        '/horario',
        '/confirmacao',
        '/pagamento',
        '/fidelidade',
        '/agendamentos',
      ]) {
        expect(auth.podeAcessar(rota), isFalse, reason: rota);
      }

      // Barbeiro: a própria agenda e o Perfil (sem Suporte, que é da tela).
      await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');
      expect(auth.podeAcessar('/home'), isTrue);
      expect(auth.podeAcessar('/agendamentos'), isTrue);
      expect(auth.podeAcessar('/perfil'), isTrue);
      expect(auth.podeAcessar('/servicos'), isFalse);
      expect(auth.podeAcessar('/fidelidade'), isFalse);
      expect(auth.podeAcessar('/admin'), isFalse);
    });
  });

  group('Correção 14 — rascunho do agendamento', () {
    final auth = AuthService.instance;

    Future<void> preencherRascunho() async {
      BookingFlow.iniciar((await service.listarServicos()).first);
      BookingFlow.barbeiroSelecionado = (await service.listarBarbeiros()).first;
      BookingFlow.dataSelecionada = proximoDiaAs(0);
      BookingFlow.horaSelecionada = '09:00';
    }

    void expectRascunhoVazio() {
      expect(BookingFlow.servicoSelecionado, isNull);
      expect(BookingFlow.barbeiroSelecionado, isNull);
      expect(BookingFlow.dataHoraCompleta, isNull);
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sair da conta descarta o agendamento em andamento', () async {
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');
      await preencherRascunho();

      await auth.logout();

      expectRascunhoVazio();
    });

    test('entrar com outra conta começa sem rascunho', () async {
      await preencherRascunho();

      await auth.login(emailAdmin, senhaAdmin);

      expectRascunhoVazio();
    });

    test('escolher um serviço recomeça o fluxo', () async {
      await preencherRascunho();
      final outro = (await service.listarServicos()).last;

      BookingFlow.iniciar(outro);

      expect(BookingFlow.servicoSelecionado!.id, outro.id);
      expect(BookingFlow.barbeiroSelecionado, isNull);
      expect(BookingFlow.dataHoraCompleta, isNull);
    });
  });

  group('Correção 16 — editar perfil e alterar senha', () {
    final auth = AuthService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
    });

    test('atualiza nome e telefone sem tocar em e-mail, senha e privilégio',
        () async {
      await auth.login(emailAdmin, senhaAdmin);
      final antes = auth.usuarioAtual!;

      final r = await auth.atualizarPerfil(
        nome: 'Dono da Barbearia',
        telefone: '(67) 98765-4321',
      );

      expect(r.sucesso, isTrue);
      final depois = await service.buscarClientePorId(antes.id!);
      expect(depois!.nome, 'Dono da Barbearia');
      expect(depois.telefone, '(67) 98765-4321');
      expect(depois.email, antes.email);
      expect(depois.senhaHash, antes.senhaHash);
      expect(depois.admin, isTrue);
      // A sessão em memória também reflete a mudança.
      expect(auth.usuarioAtual!.nome, 'Dono da Barbearia');
    });

    test('dados inválidos não são gravados', () async {
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');

      final r = await auth.atualizarPerfil(nome: 'Jo', telefone: '123');

      expect(r.sucesso, isFalse);
      expect(auth.usuarioAtual!.nome, 'Novo Cliente');
    });

    test('alterar a senha exige a senha atual', () async {
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');

      final errada = await auth.alterarSenha(
        senhaAtual: 'chute123',
        novaSenha: 'novaSenha1',
      );
      expect(errada.sucesso, isFalse);

      final ok = await auth.alterarSenha(
        senhaAtual: 'senha123',
        novaSenha: 'novaSenha1',
      );
      expect(ok.sucesso, isTrue);

      expect(await service.autenticar('novo@teste.com', 'senha123'), isNull);
      expect(
        await service.autenticar('novo@teste.com', 'novaSenha1'),
        isNotNull,
      );
    });

    test('nova senha curta é recusada', () async {
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');

      final r = await auth.alterarSenha(senhaAtual: 'senha123', novaSenha: '123');

      expect(r.sucesso, isFalse);
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNotNull);
    });
  });

  group('Correção 18 — índices, e-mail único e centavos', () {
    test('as consultas frequentes têm índice', () async {
      final db = await service.database;
      final indices = (await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'index'",
      )).map((l) => l['name']).toSet();

      expect(
        indices,
        containsAll([
          'idx_agendamento_horario',
          'idx_agendamento_barbeiro_data',
          'idx_agendamento_cliente',
          'idx_pagamento_agendamento',
          'idx_historico_cliente',
          'idx_barbeiro_email',
        ]),
      );
    });

    test('o banco recusa dois barbeiros com o mesmo e-mail', () async {
      await expectLater(
        service.cadastrarBarbeiro(
          Barbeiro(
            nome: 'Outro Rafael',
            especialidade: 'Corte',
            iniciais: 'OR',
            email: 'Rafael.Souza@sysbarber.com',
            senhaHash: DatabaseService.hashSenha('senha123'),
            salario: 2000,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('multa e estorno ficam em centavos exatos', () async {
      final idCliente = await criarClienteTeste();
      final idServico = await service.cadastrarServico(
        const Servico(
          nome: 'Pigmentação',
          descricao: 'Barba',
          preco: 35.55, // metade: 17,775
          duracaoMinutos: 30,
          icone: '🧔',
        ),
      );
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: idServico,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );

      final c = await service.cancelarAgendamento(
        r.idAgendamento,
        agora: proximoDiaAs(8, 30),
      );

      bool emCentavos(double v) => (v * 100) == (v * 100).roundToDouble();
      expect(emCentavos(c.multa), isTrue, reason: '${c.multa}');
      expect(emCentavos(c.estorno), isTrue, reason: '${c.estorno}');
      expect(c.multa + c.estorno, closeTo(35.55, 1e-9));
      expect(
        (await service.gerarRelatorio()).faturamento,
        closeTo(c.multa, 1e-9),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('P02 — cancelamento só antes do horário', () {
    /// Reserva paga agora (R$ 55) para o próximo dia de atendimento às 9h.
    Future<ResultadoReserva> reservarPagoNoProximoDia(int idCliente) =>
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 3,
          dataHora: proximoDiaAs(9),
          modo: ModoReserva.pagarAgora,
          metodo: 'Pix',
        );

    test('depois do horário o cancelamento é recusado e nada muda', () async {
      final idCliente = await criarClienteTeste();
      final r = await reservarPagoNoProximoDia(idCliente);

      // Antes o banco cancelava, cobrava multa e estornava o resto.
      await expectLater(
        service.cancelarAgendamento(r.idAgendamento, agora: proximoDiaAs(9, 15)),
        throwsA(isA<RegraNegocioException>()),
      );

      final a = (await service.listarAgendamentosCliente(idCliente)).first;
      expect(a.status, StatusAgendamento.confirmado);
      expect(a.valorEstornado, 0);
      expect(await service.obterPontos(idCliente), 55);
      expect((await service.gerarRelatorio()).faturamento, 55);
    });

    test('no horário exato também já não cancela', () async {
      final idCliente = await criarClienteTeste();
      final r = await reservarPagoNoProximoDia(idCliente);

      await expectLater(
        service.cancelarAgendamento(r.idAgendamento, agora: proximoDiaAs(9)),
        throwsA(isA<RegraNegocioException>()),
      );
    });

    test('a barbearia também não cancela depois do horário', () async {
      final idCliente = await criarClienteTeste();
      final r = await reservarPagoNoProximoDia(idCliente);

      await expectLater(
        service.cancelarAgendamento(
          r.idAgendamento,
          agora: proximoDiaAs(10),
          porBarbeiro: true,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
    });

    test('um minuto antes ainda cancela, com multa', () async {
      final idCliente = await criarClienteTeste();
      final r = await reservarPagoNoProximoDia(idCliente);

      final c = await service.cancelarAgendamento(
        r.idAgendamento,
        agora: proximoDiaAs(8, 59),
      );

      expect(c.comMulta, isTrue);
      expect(c.multa, 27.5);
    });
  });

  // -------------------------------------------------------------------------
  group('P03 — resgate e desistência tardia', () {
    /// Troca 500 pontos por uma Coloração no próximo dia de atendimento às 9h.
    /// Devolve (idCliente, idAgendamento).
    Future<(int, int)> resgatarNoProximoDia() async {
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 5,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.resgatarPontos,
      );
      expect(await service.obterPontos(idCliente), 0);
      return (idCliente, r.idAgendamento);
    }

    test('cancelado no prazo, os 500 pontos voltam', () async {
      final (idCliente, id) = await resgatarNoProximoDia();

      final c = await service.cancelarAgendamento(id, agora: proximoDiaAs(7));

      expect(c.pontosAjustados, 500);
      expect(c.pontosRetidos, 0);
      expect(await service.obterPontos(idCliente), 500);
      await expectSaldoConfereComExtrato(idCliente);
    });

    test('cancelado com menos de 1 hora, o cliente perde os pontos, sem '
        'multa em dinheiro', () async {
      final (idCliente, id) = await resgatarNoProximoDia();

      // Antes os 500 pontos voltavam mesmo em cima da hora.
      final c = await service.cancelarAgendamento(id, agora: proximoDiaAs(8, 30));

      expect(c.comMulta, isFalse);
      expect(c.multa, 0);
      expect(c.multaAPagar, 0);
      expect(c.pontosAjustados, 0);
      expect(c.pontosRetidos, 500);
      expect(await service.obterPontos(idCliente), 0);
      await expectSaldoConfereComExtrato(idCliente);

      // Nenhuma cobrança nasce: o resgate continua sendo o lançamento.
      final p = await service.buscarPagamentoDoAgendamento(id);
      expect(p!.natureza, NaturezaPagamento.resgate);
      final rel = await service.gerarRelatorio();
      expect(rel.aReceber, 0);
      expect(rel.faturamento, 0);
      expect(rel.cancelados, 1);
    });

    test('falta num serviço resgatado: perde os pontos, sem multa', () async {
      final (idCliente, id) = await resgatarNoProximoDia();

      final f = await service.registrarFalta(id, agora: proximoDiaAs(10));

      expect(f.comMulta, isFalse);
      expect(f.multaAPagar, 0);
      expect(f.pontosRetidos, 500);
      expect(await service.obterPontos(idCliente), 0);
      final rel = await service.gerarRelatorio();
      expect(rel.aReceber, 0);
      expect(rel.faltas, 1);
    });

    test('a barbearia cancelando em cima da hora devolve os pontos', () async {
      final (idCliente, id) = await resgatarNoProximoDia();

      final c = await service.cancelarAgendamento(
        id,
        agora: proximoDiaAs(8, 30),
        porBarbeiro: true,
      );

      expect(c.pontosAjustados, 500);
      expect(c.pontosRetidos, 0);
      expect(await service.obterPontos(idCliente), 500);
    });
  });

  // -------------------------------------------------------------------------
  // Regras da agenda com datas fixas, que não dependem do dia em que a suíte
  // roda. 07/01/2030 é uma segunda-feira.
  final segunda = DateTime(2030, 1, 7);

  /// [dias] depois da segunda 07/01/2030, no horário informado.
  DateTime naSemana(int dias, [int hora = 0, int minuto = 0]) =>
      DateTime(segunda.year, segunda.month, segunda.day + dias, hora, minuto);

  group('P14 — domingo fechado', () {
    final agora = naSemana(0, 7);

    test('domingo não oferece horários; sábado oferece', () async {
      expect(segunda.weekday, DateTime.monday);

      expect(
        await service.horariosDisponiveis(1, naSemana(6), agora: agora),
        isEmpty,
      );
      expect(
        await service.horariosDisponiveis(1, naSemana(5), agora: agora),
        contains('09:00'),
      );
    });

    test('reserva no domingo é recusada sem gravar nada', () async {
      final idCliente = await criarClienteTeste();

      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: naSemana(6, 9),
          modo: ModoReserva.pagarNaBarbearia,
          agora: agora,
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('domingo'),
          ),
        ),
      );
      expect(await service.contarAgendamentos(), 0);
    });

    test('os dias da agenda não incluem domingo', () {
      final dias = DatabaseService.diasDisponiveis(agora);

      expect(dias.first, segunda);
      expect(dias.where((d) => d.weekday == DateTime.sunday), isEmpty);
    });
  });

  group('P15 — grade e turnos', () {
    final agora = naSemana(0, 7);
    final terca = naSemana(1);

    test('a grade tem 16 horários: de 09:00 a 11:30 e de 13:00 a 17:30', () {
      const grade = DatabaseService.horariosBase;

      expect(grade.length, 16);
      expect(grade.first, '09:00');
      expect(grade, containsAll(['11:30', '13:00', '17:30']));
      expect(grade, isNot(contains('12:00')));
      expect(grade, isNot(contains('12:30')));
      expect(grade, isNot(contains('18:00')));
    });

    test('um serviço de 30 min cabe em todos os horários da grade', () async {
      final livres = await service.horariosDisponiveis(
        1,
        terca,
        duracaoMinutos: 30,
        agora: agora,
      );

      expect(livres, DatabaseService.horariosBase);
    });

    test('serviço que passaria do fim do turno não é oferecido', () async {
      final livres = await service.horariosDisponiveis(
        1,
        terca,
        duracaoMinutos: 60, // Coloração
        agora: agora,
      );

      expect(livres, containsAll(['11:00', '17:00']));
      expect(livres, isNot(contains('11:30'))); // terminaria às 12:30
      expect(livres, isNot(contains('17:30'))); // terminaria às 18:30
    });

    test('reserva que passaria do fim do turno é recusada', () async {
      final idCliente = await criarClienteTeste();
      Future<ResultadoReserva> colorir(int hora, int minuto) =>
          service.reservar(
            idCliente: idCliente,
            idBarbeiro: 1,
            idServico: 5, // Coloração, 60 min
            dataHora: naSemana(1, hora, minuto),
            modo: ModoReserva.pagarNaBarbearia,
            agora: agora,
          );
      final passaDoTurno = throwsA(
        isA<RegraNegocioException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('fim do turno'),
        ),
      );

      await expectLater(colorir(11, 30), passaDoTurno);
      await expectLater(colorir(17, 30), passaDoTurno);
      // 17:00–18:00 cabe no turno da tarde.
      expect((await colorir(17, 0)).idAgendamento, greaterThan(0));
    });
  });

  group('P16 — janela de 14 dias', () {
    // Quarta, 09/01/2030: o 14º dia, contando hoje, é a terça 22/01; o 15º é
    // a quarta 23/01. Nenhum dos dois é domingo.
    final quarta = naSemana(2, 7);

    test('a agenda vai de hoje até 13 dias depois', () {
      final dias = DatabaseService.diasDisponiveis(quarta);

      expect(DatabaseService.ultimoDiaDaAgenda(quarta), DateTime(2030, 1, 22));
      expect(dias.first, DateTime(2030, 1, 9));
      expect(dias.last, DateTime(2030, 1, 22));
      // 14 dias menos os domingos 13/01 e 20/01.
      expect(dias.length, 12);
    });

    test('horários aparecem até o 14º dia e somem no 15º', () async {
      expect(
        await service.horariosDisponiveis(
          1,
          DateTime(2030, 1, 22),
          agora: quarta,
        ),
        isNotEmpty,
      );
      expect(
        await service.horariosDisponiveis(
          1,
          DateTime(2030, 1, 23),
          agora: quarta,
        ),
        isEmpty,
      );
    });

    test('reserva no 14º dia é aceita e no 15º, recusada', () async {
      final idCliente = await criarClienteTeste();
      Future<ResultadoReserva> reservarEm(DateTime dataHora) =>
          service.reservar(
            idCliente: idCliente,
            idBarbeiro: 1,
            idServico: 1,
            dataHora: dataHora,
            modo: ModoReserva.pagarNaBarbearia,
            agora: quarta,
          );

      // Antes o banco aceitava qualquer data futura; só a tela limitava.
      await expectLater(
        reservarEm(DateTime(2030, 1, 23, 9)),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('14 dias'),
          ),
        ),
      );
      expect(
        (await reservarEm(DateTime(2030, 1, 22, 9))).idAgendamento,
        greaterThan(0),
      );
    });
  });

  group('P17 — agenda geral do administrador', () {
    test('lista os agendamentos de todos os barbeiros, com cliente, barbeiro, '
        'serviço e pagamento', () async {
      final ana = await criarClienteTeste(email: 'ana@teste.com');
      final bia = await criarClienteTeste(email: 'bia@teste.com');
      await service.reservar(
        idCliente: ana,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.reservar(
        idCliente: bia,
        idBarbeiro: 2,
        idServico: 3,
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.pagarNaBarbearia,
      );

      final todos = await service.listarTodosAgendamentos();

      expect(todos.length, 2);
      // Mais recente primeiro, como nas outras listagens.
      expect(todos.first.data.hour, 14);
      expect(
        todos.map((a) => a.barbeiro!.nome),
        containsAll(['Carlos Eduardo', 'Rafael Souza']),
      );
      expect(
        todos.map((a) => a.cliente!.email),
        containsAll(['ana@teste.com', 'bia@teste.com']),
      );
      expect(todos.every((a) => a.servico != null), isTrue);
      expect(todos.every((a) => a.pagamento != null), isTrue);
      // O hash da senha dos clientes não sai do banco.
      expect(todos.every((a) => a.cliente!.senhaHash.isEmpty), isTrue);
    });
  });

  group('P22 — configuração inicial da barbearia', () {
    final auth = AuthService.instance;

    /// Troca o banco do teste por um recém-criado, como na primeira abertura
    /// do app: sem administrador e sem dados.
    Future<void> bancoNovo() async {
      await service.resetarParaTeste();
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
    }

    Future<Cliente> configurar({
      String email = 'dono@barbearia.com',
      String senha = 'senhaDoDono1',
      bool dadosDeExemplo = false,
    }) => service.configurarBarbearia(
      nome: 'Dono da Barbearia',
      email: email,
      telefone: '(67) 98765-4321',
      senha: senha,
      aceitouTermos: true,
      dadosDeExemplo: dadosDeExemplo,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
      await bancoNovo();
    });

    test('banco novo nasce vazio, sem administrador nem senha padrão',
        () async {
      // Antes: já nascia com admin@sysbarber.com / admin1234 e três
      // barbeiros fictícios.
      expect(await service.barbeariaConfigurada(), isFalse);
      expect(await todasAsContas(), isEmpty);
      expect(await service.listarBarbeiros(), isEmpty);
      expect(await service.listarServicos(), isEmpty);
    });

    test('configura só o administrador, com a senha escolhida pelo dono',
        () async {
      final admin = await configurar();

      expect(await service.barbeariaConfigurada(), isTrue);
      final clientes = await todasAsContas();
      expect(clientes.single.id, admin.id);
      expect(clientes.single.admin, isTrue);
      expect(clientes.single.email, 'dono@barbearia.com');
      expect(
        Senhas.conferir('senhaDoDono1', clientes.single.senhaHash),
        isTrue,
      );
      expect(await service.obterPontos(admin.id!), 0);
      // Sem os dados de exemplo, a barbearia começa vazia.
      expect(await service.listarBarbeiros(), isEmpty);
      expect(await service.listarServicos(), isEmpty);
    });

    test('com dados de exemplo cria os 3 barbeiros e os 5 serviços',
        () async {
      await configurar(dadosDeExemplo: true);

      final barbeiros = await service.listarBarbeiros();
      expect(barbeiros.length, 3);
      expect(barbeiros.where((b) => !b.ativo).single.nome, 'Marcos Lima');
      expect((await service.listarServicos()).length, 5);
      expect(
        await service.autenticarBarbeiro(
          'carlos.eduardo@sysbarber.com',
          DatabaseService.senhaBarbeirosDeExemplo,
        ),
        isNotNull,
      );
    });

    test('a barbearia é configurada uma vez só', () async {
      await configurar();

      await expectLater(
        configurar(email: 'outro@barbearia.com'),
        throwsA(isA<RegraNegocioException>()),
      );
      final clientes = await todasAsContas();
      expect(clientes.length, 1);
      expect(clientes.where((c) => c.admin).length, 1);
    });

    test('dados inválidos ou e-mail em uso não gravam nada', () async {
      await expectLater(
        configurar(senha: '123'),
        throwsA(isA<RegraNegocioException>()),
      );
      // O e-mail de um barbeiro dos dados de exemplo não pode ser também o
      // do administrador: e-mail é único no sistema.
      await expectLater(
        configurar(
          email: 'carlos.eduardo@sysbarber.com',
          dadosDeExemplo: true,
        ),
        throwsA(isA<RegraNegocioException>()),
      );

      expect(await service.barbeariaConfigurada(), isFalse);
      expect(await todasAsContas(), isEmpty);
      expect(await service.listarBarbeiros(), isEmpty);
    });

    test('dados de exemplo só entram numa barbearia vazia', () async {
      await service.cadastrarBarbeiro(
        const Barbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          iniciais: 'PA',
          salario: 2000,
        ),
      );

      await expectLater(
        configurar(dadosDeExemplo: true),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.barbeariaConfigurada(), isFalse);
      expect((await service.listarBarbeiros()).length, 1);
    });

    test('antes da configuração só a abertura e a configuração abrem',
        () async {
      await auth.carregarConfiguracao();

      expect(auth.barbeariaConfigurada, isFalse);
      expect(auth.podeAcessar('/'), isTrue);
      expect(auth.podeAcessar('/configuracao'), isTrue);
      expect(auth.podeAcessar('/login'), isFalse);
      expect(auth.podeAcessar('/cadastro'), isFalse);
      expect(auth.podeAcessar('/recuperar-senha'), isFalse);
    });

    test('configurar entra como administrador e fecha a configuração',
        () async {
      await auth.carregarConfiguracao();

      final r = await auth.configurarBarbearia(
        nome: 'Dono da Barbearia',
        email: 'dono@barbearia.com',
        telefone: '(67) 98765-4321',
        senha: 'senhaDoDono1',
        aceitouTermos: true,
        dadosDeExemplo: false,
      );

      expect(r.sucesso, isTrue);
      expect(auth.podeAdministrar, isTrue);
      expect(auth.podeAcessar('/admin'), isTrue);
      expect(auth.podeAcessar('/login'), isTrue);
      expect(auth.podeAcessar('/configuracao'), isFalse);

      // A sessão fica salva como a de qualquer cliente.
      auth.esquecerSessaoEmMemoria();
      await auth.carregarSessao();
      expect(auth.usuarioAtual!.email, 'dono@barbearia.com');
      expect(auth.podeAdministrar, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('P24 — recuperação de senha', () {
    final auth = AuthService.instance;
    final t0 = DateTime(2030, 3, 4, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
    });

    /// O código de 6 dígitos do último SMS simulado.
    String codigoDoSms() => RegExp(
      r'\d{6}',
    ).firstMatch(SmsSimulado.instance.ultima.value!.mensagem)!.group(0)!;

    Future<List<Map<String, Object?>>> codigos() =>
        service.database.then((db) => db.query('codigo_senha'));

    test('com e-mail e celular certos, o SMS leva o código, e com ele o '
        'cliente cria uma senha nova e já entra', () async {
      await criarClienteTeste(senha: 'senha123');

      // O celular vale com ou sem máscara.
      final pedido = await auth.pedirCodigoPorSms(
        email: 'NOVO@teste.com ',
        telefone: '67988881234',
      );
      expect(pedido.sucesso, isTrue);
      expect(pedido.telefone, '(67) 98888-1234');
      expect(SmsSimulado.instance.ultima.value!.telefone, '(67) 98888-1234');

      // No banco fica só o hash do código.
      final codigo = codigoDoSms();
      final gravado = (await codigos()).single;
      expect(gravado['codigo_hash'], isNot(contains(codigo)));
      expect(gravado['origem'], 'sms');

      final r = await auth.redefinirSenha(
        email: 'novo@teste.com',
        codigo: codigo,
        novaSenha: 'senhaNova1',
      );

      expect(r.sucesso, isTrue);
      expect(auth.usuarioAtual!.email, 'novo@teste.com');
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNull);
      expect(
        await service.autenticar('novo@teste.com', 'senhaNova1'),
        isNotNull,
      );
      // Uso único: o código foi gasto.
      expect(await codigos(), isEmpty);
    });

    test('e-mail e celular que não são da mesma conta não geram código',
        () async {
      await criarClienteTeste();
      SmsSimulado.instance.ultima.value = null;

      // O celular do administrador com o e-mail do cliente.
      final r = await auth.pedirCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 99999-0000',
      );
      final semConta = await auth.pedirCodigoPorSms(
        email: 'ninguem@teste.com',
        telefone: '(67) 98888-1234',
      );

      expect(r.sucesso, isFalse);
      expect(r.erro, 'E-mail e celular não conferem com nenhuma conta');
      expect(semConta.sucesso, isFalse);
      expect(await codigos(), isEmpty);
      expect(SmsSimulado.instance.ultima.value, isNull);
    });

    test('o barbeiro também recupera a senha pelo SMS', () async {
      final pedido = await auth.pedirCodigoPorSms(
        email: 'carlos.eduardo@sysbarber.com',
        telefone: '(67) 99101-1001',
      );
      expect(pedido.sucesso, isTrue);

      final r = await auth.redefinirSenha(
        email: 'carlos.eduardo@sysbarber.com',
        codigo: codigoDoSms(),
        novaSenha: 'carlosNovo1',
      );

      expect(r.sucesso, isTrue);
      expect(auth.ehBarbeiro, isTrue);
      expect(
        await service.autenticarBarbeiro(
          'carlos.eduardo@sysbarber.com',
          'barbeiro123',
        ),
        isNull,
      );
    });

    test('o administrador também recupera a senha pelo SMS', () async {
      await auth.pedirCodigoPorSms(
        email: emailAdmin,
        telefone: '(67) 99999-0000',
      );

      final r = await auth.redefinirSenha(
        email: emailAdmin,
        codigo: codigoDoSms(),
        novaSenha: 'adminNovo1',
      );

      expect(r.sucesso, isTrue);
      expect(auth.podeAdministrar, isTrue);
    });

    test('o código do SMS vale por 10 minutos', () async {
      await criarClienteTeste(senha: 'senha123');
      final gerado = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
        agora: t0,
      );

      await expectLater(
        service.redefinirSenhaComCodigo(
          email: 'novo@teste.com',
          codigo: gerado.codigo,
          novaSenha: 'senhaNova1',
          agora: t0.add(const Duration(minutes: 10)),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Este código venceu. Peça um novo',
          ),
        ),
      );
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNotNull);
      expect(await codigos(), isEmpty);
    });

    test('um minuto antes de vencer, o código ainda vale', () async {
      await criarClienteTeste();
      final gerado = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
        agora: t0,
      );

      await service.redefinirSenhaComCodigo(
        email: 'novo@teste.com',
        codigo: gerado.codigo,
        novaSenha: 'senhaNova1',
        agora: t0.add(const Duration(minutes: 9)),
      );

      expect(
        await service.autenticar('novo@teste.com', 'senhaNova1'),
        isNotNull,
      );
    });

    test('o código só serve uma vez', () async {
      await criarClienteTeste();
      final gerado = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
      );
      await service.redefinirSenhaComCodigo(
        email: 'novo@teste.com',
        codigo: gerado.codigo,
        novaSenha: 'senhaNova1',
      );

      await expectLater(
        service.redefinirSenhaComCodigo(
          email: 'novo@teste.com',
          codigo: gerado.codigo,
          novaSenha: 'outraSenha1',
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(
        await service.autenticar('novo@teste.com', 'senhaNova1'),
        isNotNull,
      );
    });

    test('5 tentativas erradas cancelam o código', () async {
      await criarClienteTeste(senha: 'senha123');
      final gerado = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
      );
      final errado = gerado.codigo == '000000' ? '111111' : '000000';

      Future<String> tentar(String codigo) async {
        try {
          await service.redefinirSenhaComCodigo(
            email: 'novo@teste.com',
            codigo: codigo,
            novaSenha: 'senhaNova1',
          );
          return 'trocou';
        } on RegraNegocioException catch (e) {
          return e.mensagem;
        }
      }

      expect(await tentar(errado), 'Código incorreto. Restam 4 tentativas');
      await tentar(errado);
      await tentar(errado);
      expect(await tentar(errado), 'Código incorreto. Resta 1 tentativa');
      expect(await tentar(errado), contains('foi cancelado'));

      // Nem o código certo vale mais.
      expect(await tentar(gerado.codigo), 'Código inválido. Peça um novo');
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNotNull);
    });

    test('um novo SMS só sai depois de 1 minuto, e invalida o anterior',
        () async {
      await criarClienteTeste();
      Future<String> pedir(DateTime agora) async => (await service
              .gerarCodigoPorSms(
                email: 'novo@teste.com',
                telefone: '(67) 98888-1234',
                agora: agora,
              ))
          .codigo;

      final primeiro = await pedir(t0);
      await expectLater(
        pedir(t0.add(const Duration(seconds: 59))),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Aguarde 1 minuto para pedir outro código',
          ),
        ),
      );
      final segundo = await pedir(t0.add(const Duration(minutes: 1)));

      expect(await codigos(), hasLength(1));
      if (primeiro != segundo) {
        await expectLater(
          service.redefinirSenhaComCodigo(
            email: 'novo@teste.com',
            codigo: primeiro,
            novaSenha: 'senhaNova1',
            agora: t0.add(const Duration(minutes: 2)),
          ),
          throwsA(isA<RegraNegocioException>()),
        );
      }
      await service.redefinirSenhaComCodigo(
        email: 'novo@teste.com',
        codigo: segundo,
        novaSenha: 'senhaNova1',
        agora: t0.add(const Duration(minutes: 2)),
      );
    });

    test('senha nova curta é recusada e não gasta o código', () async {
      await criarClienteTeste();
      final gerado = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
      );

      await expectLater(
        service.redefinirSenhaComCodigo(
          email: 'novo@teste.com',
          codigo: gerado.codigo,
          novaSenha: '123',
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect((await codigos()).single['tentativas'], 0);
    });

    test('o administrador libera uma nova senha: o cliente entra com o '
        'código e é obrigado a criar uma senha nova', () async {
      final idCliente = await criarClienteTeste(senha: 'senha123');
      await auth.login(emailAdmin, senhaAdmin);
      final liberado = await auth.liberarNovaSenha(idCliente);
      expect(liberado.sucesso, isTrue);
      expect(liberado.codigo, matches(RegExp(r'^\d{6}$')));
      await auth.logout();

      // Com o código no lugar da senha, ainda não entra: cria a senha nova.
      final entrada = await auth.login('novo@teste.com', liberado.codigo!);
      expect(entrada.sucesso, isFalse);
      expect(entrada.criarNovaSenha, isTrue);
      expect(auth.estaLogado, isFalse);

      final r = await auth.redefinirSenha(
        email: 'novo@teste.com',
        codigo: liberado.codigo!,
        novaSenha: 'minhaSenha1',
      );
      expect(r.sucesso, isTrue);
      expect(auth.usuarioAtual!.email, 'novo@teste.com');

      await auth.logout();
      // O código provisório não vale mais, nem a senha antiga.
      final deNovo = await auth.login('novo@teste.com', liberado.codigo!);
      expect(deNovo.criarNovaSenha, isFalse);
      expect(deNovo.erro, 'E-mail ou senha incorretos');
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNull);
    });

    test('só o administrador libera uma nova senha', () async {
      final idCliente = await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');

      final r = await auth.liberarNovaSenha(idCliente);

      expect(r.sucesso, isFalse);
      expect(r.codigo, isNull);
      expect(await codigos(), isEmpty);
    });

    test('o código da barbearia vale por 24 horas', () async {
      final idCliente = await criarClienteTeste();
      final codigo = await service.liberarCodigoDaBarbearia(
        idCliente,
        agora: t0,
      );

      expect(
        await service.codigoDaBarbeariaConfere(
          'novo@teste.com',
          codigo,
          agora: t0.add(const Duration(hours: 23, minutes: 59)),
        ),
        isTrue,
      );
      expect(
        await service.codigoDaBarbeariaConfere(
          'novo@teste.com',
          codigo,
          agora: t0.add(const Duration(hours: 24)),
        ),
        isFalse,
      );
    });

    test('o código do SMS não serve para entrar pelo login', () async {
      await criarClienteTeste();
      await auth.pedirCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
      );

      final r = await auth.login('novo@teste.com', codigoDoSms());

      expect(r.sucesso, isFalse);
      expect(r.criarNovaSenha, isFalse);
      expect(r.erro, 'E-mail ou senha incorretos');
    });

    test('excluir o barbeiro apaga o código dele', () async {
      final id = await service.cadastrarBarbeiro(
        const Barbeiro(
          nome: 'Novo Barbeiro',
          especialidade: 'Cortes',
          iniciais: 'NB',
          telefone: '(67) 99555-5555',
          email: 'novo.barbeiro@sysbarber.com',
          salario: 2000,
        ),
      );
      await service.gerarCodigoPorSms(
        email: 'novo.barbeiro@sysbarber.com',
        telefone: '(67) 99555-5555',
      );

      await service.excluirBarbeiro(id);

      expect(await codigos(), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('P25 — recuperação de senha por e-mail', () {
    final auth = AuthService.instance;
    final t0 = DateTime(2030, 3, 4, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
      auth.envioEmail = EmailSimulado.instance;
      EmailSimulado.instance.ultimo.value = null;
    });

    tearDown(() => auth.envioEmail = EmailSimulado.instance);

    /// O código de 6 dígitos do último e-mail simulado.
    String codigoDoEmail() => RegExp(
      r'\d{6}',
    ).firstMatch(EmailSimulado.instance.ultimo.value!.texto)!.group(0)!;

    Future<List<Map<String, Object?>>> codigos() =>
        service.database.then((db) => db.query('codigo_senha'));

    test('basta o e-mail da conta: o código vai para ele, e com o código o '
        'cliente cria uma senha nova e já entra', () async {
      await criarClienteTeste(senha: 'senha123');

      final pedido = await auth.pedirCodigoPorEmail(email: ' NOVO@teste.com');

      expect(pedido.sucesso, isTrue);
      expect(pedido.email, 'novo@teste.com');
      final email = EmailSimulado.instance.ultimo.value!;
      expect(email.email, 'novo@teste.com');
      expect(email.texto, contains('Novo Cliente'));
      expect((await codigos()).single['origem'], 'email');

      final r = await auth.redefinirSenha(
        email: 'novo@teste.com',
        codigo: codigoDoEmail(),
        novaSenha: 'senhaNova1',
      );

      expect(r.sucesso, isTrue);
      expect(auth.usuarioAtual!.email, 'novo@teste.com');
      expect(await service.autenticar('novo@teste.com', 'senha123'), isNull);
      expect(await codigos(), isEmpty);
    });

    test('e-mail que não é de nenhuma conta não gera código nem envia nada',
        () async {
      final r = await auth.pedirCodigoPorEmail(email: 'ninguem@teste.com');

      expect(r.sucesso, isFalse);
      expect(r.erro, 'Este e-mail não pertence a nenhuma conta');
      expect(await codigos(), isEmpty);
      expect(EmailSimulado.instance.ultimo.value, isNull);
    });

    test('o barbeiro também recebe o código por e-mail', () async {
      await auth.pedirCodigoPorEmail(email: 'rafael.souza@sysbarber.com');

      final r = await auth.redefinirSenha(
        email: 'rafael.souza@sysbarber.com',
        codigo: codigoDoEmail(),
        novaSenha: 'rafaelNovo1',
      );

      expect(r.sucesso, isTrue);
      expect(auth.ehBarbeiro, isTrue);
    });

    test('o intervalo de 1 minuto vale entre os canais, e o código novo '
        'cancela o do outro canal', () async {
      await criarClienteTeste();
      final sms = await service.gerarCodigoPorSms(
        email: 'novo@teste.com',
        telefone: '(67) 98888-1234',
        agora: t0,
      );

      await expectLater(
        service.gerarCodigoPorEmail(
          email: 'novo@teste.com',
          agora: t0.add(const Duration(seconds: 30)),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Aguarde 1 minuto para pedir outro código',
          ),
        ),
      );

      final email = await service.gerarCodigoPorEmail(
        email: 'novo@teste.com',
        agora: t0.add(const Duration(minutes: 1)),
      );
      expect((await codigos()).single['origem'], 'email');
      if (sms.codigo != email.codigo) {
        await expectLater(
          service.redefinirSenhaComCodigo(
            email: 'novo@teste.com',
            codigo: sms.codigo,
            novaSenha: 'senhaNova1',
            agora: t0.add(const Duration(minutes: 2)),
          ),
          throwsA(isA<RegraNegocioException>()),
        );
      }
      await service.redefinirSenhaComCodigo(
        email: 'novo@teste.com',
        codigo: email.codigo,
        novaSenha: 'senhaNova1',
        agora: t0.add(const Duration(minutes: 2)),
      );
    });

    test('se o e-mail não sai, o código é descartado e dá para pedir de novo '
        'na hora', () async {
      await criarClienteTeste();
      auth.envioEmail = _EmailQueFalha();

      final r = await auth.pedirCodigoPorEmail(email: 'novo@teste.com');

      expect(r.sucesso, isFalse);
      expect(r.erro, contains('Não foi possível enviar o e-mail'));
      expect(await codigos(), isEmpty);

      auth.envioEmail = EmailSimulado.instance;
      final deNovo = await auth.pedirCodigoPorEmail(email: 'novo@teste.com');
      expect(deNovo.sucesso, isTrue);
    });

    test('o código do e-mail não serve para entrar pelo login', () async {
      await criarClienteTeste();
      await auth.pedirCodigoPorEmail(email: 'novo@teste.com');

      final r = await auth.login('novo@teste.com', codigoDoEmail());

      expect(r.sucesso, isFalse);
      expect(r.criarNovaSenha, isFalse);
    });
  });

  group('P30 — telas de cada perfil', () {
    Future<Cliente> administrador() async =>
        (await service.buscarClientePorEmail(emailAdmin))!;

    test('o administrador não agenda: o banco recusa a reserva e nada é '
        'gravado', () async {
      final admin = await administrador();
      final antes = await service.listarTodosAgendamentos();

      await expectLater(
        service.reservar(
          idCliente: admin.id!,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: proximoDiaAs(9),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'O administrador não agenda serviços',
          ),
        ),
      );
      expect(await service.listarTodosAgendamentos(), hasLength(antes.length));
      // A revisão do agendamento também avisa, antes do pagamento.
      expect(
        await service.verificarReserva(
          idBarbeiro: 1,
          dataHora: proximoDiaAs(9),
          idServico: 1,
          idCliente: admin.id,
        ),
        'O administrador não agenda serviços',
      );
    });

    test('o administrador não conta como cliente: fica fora da lista, do '
        'painel e dos relatórios', () async {
      final admin = await administrador();
      await service.adicionarPontos(admin.id!, 120, 'Pontos antigos');
      final idCliente = await criarClienteTeste();
      await service.adicionarPontos(idCliente, 30, 'Pontos do cliente');

      final clientes = await service.listarClientes();
      expect(clientes.map((c) => c.id), [idCliente]);
      expect((await service.resumoDoDia()).clientesTotal, 1);
      final relatorio = await service.gerarRelatorio();
      expect(relatorio.totalClientes, 1);
      expect(relatorio.pontosEmCirculacao, 30);
    });

    test('o barbeiro troca a própria senha no Perfil, conferindo a atual',
        () async {
      final auth = AuthService.instance;
      SharedPreferences.setMockInitialValues({});
      await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');

      final errada = await auth.alterarSenha(
        senhaAtual: 'naoEhEssa',
        novaSenha: 'novaSenha1',
      );
      expect(errada.sucesso, isFalse);
      expect(errada.erro, 'Senha atual incorreta');

      final certa = await auth.alterarSenha(
        senhaAtual: 'barbeiro123',
        novaSenha: 'novaSenha1',
      );
      expect(certa.sucesso, isTrue);
      expect(
        await service.autenticarBarbeiro(
          'rafael.souza@sysbarber.com',
          'novaSenha1',
        ),
        isNotNull,
      );
      expect(
        await service.autenticarBarbeiro(
          'rafael.souza@sysbarber.com',
          'barbeiro123',
        ),
        isNull,
      );
      await auth.logout();
    });
  });
  // -------------------------------------------------------------------------
  group('P33 — convite do barbeiro', () {
    final agora = DateTime(2026, 10, 24, 10);

    Future<({ConviteBarbeiro convite, String codigo})> convidar({
      String nome = 'Pedro Alves',
      DateTime? momento,
    }) => service.criarConviteBarbeiro(
      nome: nome,
      especialidade: 'Degradê',
      salario: 2400,
      agora: momento ?? agora,
    );

    Future<Barbeiro> aceitar(
      String codigo, {
      String email = 'pedro.alves@sysbarber.com',
      DateTime? momento,
    }) => service.aceitarConviteBarbeiro(
      codigo: codigo,
      email: email,
      telefone: '(67) 99404-4004',
      senha: 'senha123',
      aceitouTermos: true,
      agora: momento ?? agora,
    );

    test('o convite tem um código de 8 letras e números e vale 7 dias, sem '
        'criar o barbeiro', () async {
      final g = await convidar();

      expect(g.codigo, matches(RegExp(r'^[A-Z2-9]{8}$')));
      // Nem o código em texto nem letras que se confundem ao ditar.
      expect(g.codigo, isNot(matches(RegExp('[01ILO]'))));
      expect(g.convite.codigoHash, isNot(contains(g.codigo)));
      expect(
        DateTime.parse(g.convite.expiraEm),
        agora.add(const Duration(days: 7)),
      );
      expect(await service.listarConvitesBarbeiro(), hasLength(1));
      // Enquanto não usa o convite, ele não aparece para o cliente agendar.
      expect(await service.listarBarbeiros(), hasLength(3));
      expect(
        (await service.listarBarbeirosAtivos()).map((b) => b.nome),
        isNot(contains('Pedro Alves')),
      );
    });

    test('o banco confere o que o administrador informa no convite', () async {
      await expectLater(
        () => service.criarConviteBarbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          salario: 0,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      expect(await service.listarConvitesBarbeiro(), isEmpty);
    });

    test('com o convite, o barbeiro cria a conta: nome, especialidade e '
        'salário vêm do convite', () async {
      final g = await convidar();

      final b = await aceitar(g.codigo);

      expect(b.id, isNotNull);
      expect(b.nome, 'Pedro Alves');
      expect(b.especialidade, 'Degradê');
      expect(b.salario, 2400);
      expect(b.iniciais, 'PA');
      expect(b.ativo, isTrue);
      expect(b.telefone, '(67) 99404-4004');
      expect(await service.listarConvitesBarbeiro(), isEmpty);
      expect(
        await service.autenticarBarbeiro(
          'pedro.alves@sysbarber.com',
          'senha123',
        ),
        isNotNull,
      );
      expect(await service.listarBarbeiros(), hasLength(4));
    });

    test('o código vale com minúsculas e com o hífen', () async {
      final g = await convidar();
      final digitado = '${g.codigo.substring(0, 4)}-${g.codigo.substring(4)}'
          .toLowerCase();

      final b = await aceitar(digitado);

      expect(b.nome, 'Pedro Alves');
    });

    test('o convite vale uma vez só', () async {
      final g = await convidar();
      await aceitar(g.codigo);

      await expectLater(
        () => aceitar(g.codigo, email: 'outro@sysbarber.com'),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            startsWith('Convite não encontrado'),
          ),
        ),
      );
    });

    test('o convite vence em 7 dias', () async {
      final g = await convidar();

      await expectLater(
        () => aceitar(
          g.codigo,
          momento: agora.add(const Duration(days: 7, minutes: 1)),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Este convite venceu. Peça um novo ao administrador',
          ),
        ),
      );
      // Até o fim do sétimo dia, ainda vale.
      final b = await aceitar(
        g.codigo,
        momento: agora.add(const Duration(days: 6, hours: 23)),
      );
      expect(b.nome, 'Pedro Alves');
    });

    test(
      'gerar outro código cancela o anterior e conta a validade de novo',
      () async {
        final g = await convidar();
        final depois = agora.add(const Duration(days: 3));

        final novo = await service.gerarNovoCodigoDoConvite(
          g.convite.id!,
          agora: depois,
        );

        expect(novo.codigo, isNot(g.codigo));
        expect(
          DateTime.parse(novo.convite.expiraEm),
          depois.add(const Duration(days: 7)),
        );
        await expectLater(
          () => aceitar(g.codigo, momento: depois),
          throwsA(isA<RegraNegocioException>()),
        );
        final b = await aceitar(novo.codigo, momento: depois);
        expect(b.nome, 'Pedro Alves');
      },
    );

    test('cancelar o convite invalida o código', () async {
      final g = await convidar();

      await service.cancelarConviteBarbeiro(g.convite.id!);

      expect(await service.listarConvitesBarbeiro(), isEmpty);
      await expectLater(() => aceitar(g.codigo), throwsA(isA<RegraNegocioException>()));
    });

    test('o e-mail continua único: o de um cliente ou de outro barbeiro é '
        'recusado, e o convite continua valendo', () async {
      await criarClienteTeste(email: 'cliente@teste.com');
      final g = await convidar();

      for (final email in [
        'cliente@teste.com',
        'CARLOS.EDUARDO@sysbarber.com',
        emailAdmin,
      ]) {
        await expectLater(
          () => aceitar(g.codigo, email: email),
          throwsA(
            isA<RegraNegocioException>().having(
              (e) => e.mensagem,
              'mensagem',
              'Este e-mail já está cadastrado',
            ),
          ),
        );
      }
      expect(await service.listarConvitesBarbeiro(), hasLength(1));
      expect(await service.listarBarbeiros(), hasLength(3));
    });

    test(
      'o banco confere o e-mail, o telefone e a senha do barbeiro',
      () async {
        final g = await convidar();

        await expectLater(
          () => service.aceitarConviteBarbeiro(
            codigo: g.codigo,
            email: 'pedro',
            telefone: '(67) 99404-4004',
            senha: 'senha123',
            aceitouTermos: true,
            agora: agora,
          ),
          throwsA(isA<RegraNegocioException>()),
        );
        await expectLater(
          () => service.aceitarConviteBarbeiro(
            codigo: g.codigo,
            email: 'pedro.alves@sysbarber.com',
            telefone: '(67) 99404-4004',
            senha: '123',
            aceitouTermos: true,
            agora: agora,
          ),
          throwsA(isA<RegraNegocioException>()),
        );
        expect(await service.listarConvitesBarbeiro(), hasLength(1));
      },
    );

    test(
      'pelo AuthService, quem usa o convite já entra como barbeiro',
      () async {
        final auth = AuthService.instance;
        SharedPreferences.setMockInitialValues({});
        final g = await service.criarConviteBarbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          salario: 2400,
        );

        final conferido = await auth.conferirConvite(g.codigo);
        expect(conferido.convite?.nome, 'Pedro Alves');
        expect((await auth.conferirConvite('AAAA-AAAA')).convite, isNull);

        final r = await auth.aceitarConvite(
          codigo: g.codigo,
          email: 'pedro.alves@sysbarber.com',
          telefone: '(67) 99404-4004',
          senha: 'senha123',
          aceitouTermos: true,
        );

        expect(r.sucesso, isTrue);
        expect(auth.ehBarbeiro, isTrue);
        expect(auth.nomeLogado, 'Pedro Alves');
        expect(auth.podeAcessar(AuthService.rotaConvite), isTrue);
        await auth.logout();
      },
    );

    test('o administrador edita só nome, especialidade e salário', () async {
      final b = (await service.listarBarbeiros()).first;

      await service.atualizarDadosDoBarbeiro(
        b.id!,
        nome: 'Carlos Eduardo Lima',
        especialidade: 'Barba',
        salario: 3100,
      );

      final depois = await service.buscarBarbeiroPorId(b.id!);
      expect(depois!.nome, 'Carlos Eduardo Lima');
      expect(depois.iniciais, 'CL');
      expect(depois.especialidade, 'Barba');
      expect(depois.salario, 3100);
      expect(depois.email, b.email);
      expect(depois.telefone, b.telefone);
      expect(depois.senhaHash, b.senhaHash);
    });

    test('o barbeiro troca o próprio e-mail e telefone, sem repetir o '
        'e-mail de outra conta', () async {
      final auth = AuthService.instance;
      SharedPreferences.setMockInitialValues({});
      await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');

      final repetido = await auth.atualizarContatoBarbeiro(
        email: 'carlos.eduardo@sysbarber.com',
        telefone: '(67) 99777-7777',
      );
      expect(repetido.sucesso, isFalse);
      expect(repetido.erro, 'Este e-mail já está cadastrado');

      // O próprio e-mail, com outro telefone, é aceito.
      final mesmo = await auth.atualizarContatoBarbeiro(
        email: 'rafael.souza@sysbarber.com',
        telefone: '(67) 99777-7777',
      );
      expect(mesmo.sucesso, isTrue);

      final r = await auth.atualizarContatoBarbeiro(
        email: 'Rafael@Barbearia.com',
        telefone: '(67) 99888-8888',
      );
      expect(r.sucesso, isTrue);
      expect(auth.barbeiroAtual!.email, 'rafael@barbearia.com');
      expect(auth.barbeiroAtual!.telefone, '(67) 99888-8888');
      expect(
        await service.autenticarBarbeiro('rafael@barbearia.com', 'barbeiro123'),
        isNotNull,
      );
      await auth.logout();
    });

    test('o administrador libera uma nova senha para o barbeiro, que entra '
        'com o código e cria outra', () async {
      final auth = AuthService.instance;
      SharedPreferences.setMockInitialValues({});
      final b = (await service.listarBarbeiros()).first;

      // Só o administrador libera.
      expect((await auth.liberarNovaSenhaDoBarbeiro(b.id!)).sucesso, isFalse);

      await auth.login(emailAdmin, senhaAdmin);
      final liberado = await auth.liberarNovaSenhaDoBarbeiro(b.id!);
      expect(liberado.sucesso, isTrue);
      await auth.logout();

      final login = await auth.login(b.email, liberado.codigo!);
      expect(login.criarNovaSenha, isTrue);
      final r = await auth.redefinirSenha(
        email: b.email,
        codigo: liberado.codigo!,
        novaSenha: 'outraSenha1',
      );
      expect(r.sucesso, isTrue);
      expect(
        await service.autenticarBarbeiro(b.email, 'outraSenha1'),
        isNotNull,
      );
    });
  });
  // -------------------------------------------------------------------------
  group('P34 — excluir a própria conta e termos de uso', () {
    final auth = AuthService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
    });

    Future<Cliente> criarConta({
      String email = 'joana@teste.com',
      bool aceitouTermos = true,
    }) => service.criarContaCliente(
      nome: 'Joana Lima',
      email: email,
      telefone: '(67) 98888-1234',
      senha: 'senha123',
      aceitouTermos: aceitouTermos,
    );

    test('sem aceitar os termos, o banco não cria a conta do cliente',
        () async {
      await expectLater(
        () => criarConta(aceitouTermos: false),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            DatabaseService.termosNaoAceitos,
          ),
        ),
      );
      expect(await service.buscarClientePorEmail('joana@teste.com'), isNull);

      final c = await criarConta();
      expect(c.termosAceitosEm, isNotNull);
      final gravado = await service.buscarClientePorId(c.id!);
      expect(gravado!.termosAceitosEm, isNotNull);
      expect(await service.obterPontos(c.id!), 0);
    });

    test('o banco confere no cadastro o e-mail de clientes e de barbeiros',
        () async {
      await criarConta();
      for (final email in ['JOANA@teste.com', 'carlos.eduardo@sysbarber.com']) {
        await expectLater(
          () => criarConta(email: email),
          throwsA(
            isA<RegraNegocioException>().having(
              (e) => e.mensagem,
              'mensagem',
              'Este e-mail já está cadastrado',
            ),
          ),
        );
      }
    });

    test('pelo AuthService, o cadastro sem os termos avisa e não entra',
        () async {
      final sem = await auth.cadastrar(
        nome: 'Joana Lima',
        email: 'joana@teste.com',
        telefone: '(67) 98888-1234',
        senha: 'senha123',
        aceitouTermos: false,
      );
      expect(sem.sucesso, isFalse);
      expect(sem.erro, DatabaseService.termosNaoAceitos);
      expect(auth.estaLogado, isFalse);

      final com = await auth.cadastrar(
        nome: 'Joana Lima',
        email: 'joana@teste.com',
        telefone: '(67) 98888-1234',
        senha: 'senha123',
        aceitouTermos: true,
      );
      expect(com.sucesso, isTrue);
      expect(auth.ehCliente, isTrue);
    });

    test('o barbeiro também aceita os termos ao usar o convite', () async {
      final g = await service.criarConviteBarbeiro(
        nome: 'Pedro Alves',
        especialidade: 'Degradê',
        salario: 2400,
      );
      Future<Barbeiro> aceitar(bool aceitou) => service.aceitarConviteBarbeiro(
        codigo: g.codigo,
        email: 'pedro.alves@sysbarber.com',
        telefone: '(67) 99404-4004',
        senha: 'senha123',
        aceitouTermos: aceitou,
      );

      await expectLater(() => aceitar(false), throwsA(isA<RegraNegocioException>()));
      expect(await service.listarConvitesBarbeiro(), hasLength(1));

      final b = await aceitar(true);
      final gravado = await service.buscarBarbeiroPorId(b.id!);
      expect(gravado!.termosAceitosEm, isNotNull);
    });

    test('o administrador aceitou os termos na configuração inicial', () async {
      final admin = (await todasAsContas()).firstWhere((c) => c.admin);
      expect(admin.termosAceitosEm, isNotNull);
    });

    test('excluir a conta apaga os dados pessoais, os pontos e o extrato, e '
        'os atendimentos passados continuam', () async {
      final c = await criarConta();
      await service.adicionarPontos(c.id!, 120, 'Pontos de teste');
      final r = await service.reservar(
        idCliente: c.id!,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.finalizarAgendamento(
        r.idAgendamento,
        agora: proximoDiaAs(9, 30),
      );
      await service.gerarCodigoPorSms(
        email: 'joana@teste.com',
        telefone: '(67) 98888-1234',
      );

      await service.excluirContaCliente(c.id!, senha: 'senha123');

      final depois = await service.buscarClientePorId(c.id!);
      expect(depois!.excluido, isTrue);
      expect(depois.nome, DatabaseService.nomeClienteExcluido);
      expect(depois.email, isNot(contains('joana')));
      expect(depois.telefone, isEmpty);
      expect(depois.senhaHash, isEmpty);
      expect(await service.obterPontos(c.id!), 0);
      expect(await service.listarHistoricoPontos(c.id!), isEmpty);
      final db = await service.database;
      expect(await db.query('codigo_senha'), isEmpty);

      // O atendimento continua nos relatórios, sem o nome.
      final todos = await service.listarTodosAgendamentos();
      final atendimento = todos.firstWhere((a) => a.id == r.idAgendamento);
      expect(atendimento.cliente!.nome, DatabaseService.nomeClienteExcluido);
      expect((await service.gerarRelatorio()).finalizados, 1);

      // Sai da lista e das contagens de clientes, e não entra mais.
      expect(
        (await service.listarClientes()).map((x) => x.id),
        isNot(contains(c.id)),
      );
      expect((await service.resumoDoDia()).clientesTotal, 0);
      expect((await service.gerarRelatorio()).totalClientes, 0);
      expect(await service.autenticar('joana@teste.com', 'senha123'), isNull);
    });

    test('o e-mail da conta excluída pode criar uma conta nova, do zero',
        () async {
      final c = await criarConta();
      await service.adicionarPontos(c.id!, 80, 'Pontos de teste');
      await service.excluirContaCliente(c.id!, senha: 'senha123');

      final nova = await criarConta();

      expect(nova.id, isNot(c.id));
      expect(await service.obterPontos(nova.id!), 0);
      expect(await service.autenticar('joana@teste.com', 'senha123'), isNotNull);
    });

    test('a senha errada não exclui a conta', () async {
      final c = await criarConta();

      await expectLater(
        () => service.excluirContaCliente(c.id!, senha: 'outra123'),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Senha incorreta',
          ),
        ),
      );
      expect((await service.buscarClientePorId(c.id!))!.excluido, isFalse);
    });

    test('com agendamento em aberto, o banco recusa a exclusão', () async {
      final c = await criarConta();
      await service.reservar(
        idCliente: c.id!,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        () => service.excluirContaCliente(c.id!, senha: 'senha123'),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            startsWith('Você tem 1 agendamento em aberto'),
          ),
        ),
      );
      expect((await service.buscarClientePorId(c.id!))!.excluido, isFalse);
    });

    test('quem deve à barbearia paga antes de excluir: multa pendente e '
        'serviço concluído sem pagamento', () async {
      final c = await criarConta();
      final db = await service.database;
      Future<int> pendentes() async => (await db.query(
        'pagamento',
        where: 'status = ?',
        whereArgs: [Pagamento.statusPendente],
      )).length;

      // Cancelou em cima da hora, e ia pagar na barbearia: multa pendente.
      final cancelado = await service.reservar(
        idCliente: c.id!,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      await service.cancelarAgendamento(
        cancelado.idAgendamento,
        agora: proximoDiaAs(8, 30),
      );
      expect(await pendentes(), 1);
      await expectLater(
        () => service.excluirContaCliente(c.id!, senha: 'senha123'),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            allOf(contains('pendente com a barbearia'), contains('balcão')),
          ),
        ),
      );

      // A barbearia recebe a multa, mas fica um serviço concluído sem
      // pagamento.
      final multa = (await db.query(
        'pagamento',
        where: 'status = ?',
        whereArgs: [Pagamento.statusPendente],
      )).single;
      await service.confirmarPagamento(multa['id'] as int, metodo: 'Dinheiro');
      final concluido = await service.reservar(
        idCliente: c.id!,
        idBarbeiro: 1,
        idServico: 1,
        dataHora: proximoDiaAs(10),
        modo: ModoReserva.pagarNaBarbearia,
      );
      await service.finalizarAgendamento(
        concluido.idAgendamento,
        agora: proximoDiaAs(10, 30),
      );
      await expectLater(
        () => service.excluirContaCliente(c.id!, senha: 'senha123'),
        throwsA(isA<RegraNegocioException>()),
      );

      // Tudo pago: a exclusão é liberada.
      final servico = (await db.query(
        'pagamento',
        where: 'status = ?',
        whereArgs: [Pagamento.statusPendente],
      )).single;
      await service.confirmarPagamento(
        servico['id'] as int,
        metodo: 'Dinheiro',
      );
      await service.excluirContaCliente(c.id!, senha: 'senha123');
      expect((await service.buscarClientePorId(c.id!))!.excluido, isTrue);
    });

    test('só o cliente exclui a própria conta, e sai dela', () async {
      await auth.login(emailAdmin, senhaAdmin);
      final doAdmin = await auth.excluirConta(senhaAdmin);
      expect(doAdmin.sucesso, isFalse);
      expect(doAdmin.erro, 'O administrador não pode excluir a própria conta');
      final admin = (await todasAsContas()).firstWhere((c) => c.admin);
      await expectLater(
        () => service.excluirContaCliente(admin.id!, senha: senhaAdmin),
        throwsA(isA<RegraNegocioException>()),
      );
      await auth.logout();

      await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');
      final doBarbeiro = await auth.excluirConta('barbeiro123');
      expect(doBarbeiro.sucesso, isFalse);
      expect(
        doBarbeiro.erro,
        'A conta do barbeiro é excluída pelo administrador',
      );
      await auth.logout();

      await criarConta();
      await auth.login('joana@teste.com', 'senha123');
      final doCliente = await auth.excluirConta('senha123');
      expect(doCliente.sucesso, isTrue);
      expect(auth.estaLogado, isFalse);
      expect((await auth.login('joana@teste.com', 'senha123')).sucesso, isFalse);
    });

    test('os termos abrem para todos, até antes da configuração inicial',
        () async {
      expect(auth.podeAcessar(AuthService.rotaTermos), isTrue);
    });
  });
  // -------------------------------------------------------------------------
  group('P36 — reagendar', () {
    /// Dia de atendimento seguinte ao próximo (pula o domingo).
    DateTime diaSeguinteAs(int hora, [int minuto = 0]) {
      var d = proximoDiaDeAtendimento().add(const Duration(days: 1));
      if (!DatabaseService.atendeNoDia(d)) d = d.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day, hora, minuto);
    }

    /// Reserva do cliente novo com o barbeiro 1 no próximo dia às [hora].
    Future<({int idCliente, int idAgendamento})> reservado({
      int hora = 9,
      int idServico = 1,
      ModoReserva modo = ModoReserva.pagarAgora,
    }) async {
      final idCliente = await criarClienteTeste();
      if (modo == ModoReserva.resgatarPontos) {
        await service.adicionarPontos(idCliente, 500, 'Saldo de teste');
      }
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: idServico,
        dataHora: proximoDiaAs(hora),
        modo: modo,
        metodo: modo == ModoReserva.pagarAgora ? 'Pix' : null,
      );
      return (idCliente: idCliente, idAgendamento: r.idAgendamento);
    }

    Future<Agendamento> buscar(int idCliente, int id) async =>
        (await service.listarAgendamentosCliente(
          idCliente,
        )).firstWhere((a) => a.id == id);

    test('muda o dia, o horário e o barbeiro, e o serviço, o preço e o '
        'pagamento continuam', () async {
      final r = await reservado();
      final antes = await buscar(r.idCliente, r.idAgendamento);

      await service.reagendarAgendamento(
        r.idAgendamento,
        idCliente: r.idCliente,
        idBarbeiro: 2,
        dataHora: diaSeguinteAs(14),
      );

      final depois = await buscar(r.idCliente, r.idAgendamento);
      expect(depois.idBarbeiro, 2);
      expect(depois.data, diaSeguinteAs(14));
      expect(depois.emAberto, isTrue);
      expect(depois.idServico, antes.idServico);
      expect(depois.valor, antes.valor);
      expect(depois.duracaoMinutos, antes.duracaoMinutos);
      expect(depois.pagamento!.id, antes.pagamento!.id);
      expect(depois.pagamento!.confirmado, isTrue);
      expect(await service.obterPontos(r.idCliente), 35);
      expect(await service.contarAgendamentos(), 1);
    });

    test('até 1 hora antes reagenda; com menos de 1 hora, só cancelar',
        () async {
      final r = await reservado();
      final horario = proximoDiaAs(9);

      await expectLater(
        () => service.reagendarAgendamento(
          r.idAgendamento,
          idCliente: r.idCliente,
          idBarbeiro: 1,
          dataHora: proximoDiaAs(10),
          agora: horario.subtract(const Duration(minutes: 59)),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            startsWith('Com menos de 1 hora para o horário'),
          ),
        ),
      );

      // Exatamente 1 hora antes ainda vale.
      await service.reagendarAgendamento(
        r.idAgendamento,
        idCliente: r.idCliente,
        idBarbeiro: 1,
        dataHora: proximoDiaAs(10),
        agora: horario.subtract(const Duration(hours: 1)),
      );
      expect(
        (await buscar(r.idCliente, r.idAgendamento)).data,
        proximoDiaAs(10),
      );
    });

    test('só o próprio cliente reagenda, e só o que está em aberto', () async {
      final r = await reservado();
      final outro = await criarClienteTeste(email: 'outro@teste.com');

      await expectLater(
        () => service.reagendarAgendamento(
          r.idAgendamento,
          idCliente: outro,
          idBarbeiro: 1,
          dataHora: proximoDiaAs(10),
        ),
        throwsA(isA<RegraNegocioException>()),
      );

      await service.cancelarAgendamento(r.idAgendamento);
      await expectLater(
        () => service.reagendarAgendamento(
          r.idAgendamento,
          idCliente: r.idCliente,
          idBarbeiro: 1,
          dataHora: proximoDiaAs(10),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Este atendimento já foi encerrado',
          ),
        ),
      );
    });

    test('o novo horário segue as regras de uma reserva', () async {
      final r = await reservado();
      final outro = await criarClienteTeste(email: 'outro@teste.com');
      await service.reservar(
        idCliente: outro,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: proximoDiaAs(11),
        modo: ModoReserva.pagarNaBarbearia,
      );
      var domingo = proximoDiaAs(10);
      while (DatabaseService.atendeNoDia(domingo)) {
        domingo = domingo.add(const Duration(days: 1));
      }

      final recusados = <DateTime, int>{
        proximoDiaAs(11): 2, // ocupado por outro cliente
        proximoDiaAs(12): 1, // fora da grade (almoço)
        proximoDiaAs(17, 45): 1, // fora da grade
        domingo: 1, // barbearia fechada
        DateTime.now().add(const Duration(days: 20)): 1, // além dos 14 dias
        proximoDiaAs(10): 3, // barbeiro indisponível
      };
      for (final MapEntry(key: dataHora, value: barbeiro) in recusados.entries) {
        await expectLater(
          () => service.reagendarAgendamento(
            r.idAgendamento,
            idCliente: r.idCliente,
            idBarbeiro: barbeiro,
            dataHora: dataHora,
          ),
          throwsA(isA<RegraNegocioException>()),
          reason: '$dataHora com o barbeiro $barbeiro',
        );
      }
      expect(
        (await buscar(r.idCliente, r.idAgendamento)).data,
        proximoDiaAs(9),
      );
    });

    test('o horário que ele ocupa hoje não conta como ocupado', () async {
      // Coloração de 60 min às 09:00: ocupa até as 10:00.
      final r = await reservado(idServico: 5);

      final livres = await service.horariosDisponiveis(
        1,
        proximoDiaAs(9),
        duracaoMinutos: 60,
        idCliente: r.idCliente,
        ignorarAgendamento: r.idAgendamento,
      );
      expect(livres, contains('09:30'));

      await service.reagendarAgendamento(
        r.idAgendamento,
        idCliente: r.idCliente,
        idBarbeiro: 1,
        dataHora: proximoDiaAs(9, 30),
      );
      expect(
        (await buscar(r.idCliente, r.idAgendamento)).data,
        proximoDiaAs(9, 30),
      );
    });

    test('o mesmo horário com o mesmo barbeiro não é um horário novo',
        () async {
      final r = await reservado();

      await expectLater(
        () => service.reagendarAgendamento(
          r.idAgendamento,
          idCliente: r.idCliente,
          idBarbeiro: 1,
          dataHora: proximoDiaAs(9),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Escolha um horário diferente do atual',
          ),
        ),
      );
    });

    test('o cliente não fica com dois atendimentos ao mesmo tempo', () async {
      final r = await reservado();
      await service.reservar(
        idCliente: r.idCliente,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: proximoDiaAs(14),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        () => service.reagendarAgendamento(
          r.idAgendamento,
          idCliente: r.idCliente,
          idBarbeiro: 1,
          dataHora: proximoDiaAs(14),
        ),
        throwsA(
          isA<RegraNegocioException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Você já tem outro atendimento nesse horário',
          ),
        ),
      );
    });

    test('o resgate com pontos continua valendo no novo horário', () async {
      final r = await reservado(modo: ModoReserva.resgatarPontos);
      expect(await service.obterPontos(r.idCliente), 0);

      await service.reagendarAgendamento(
        r.idAgendamento,
        idCliente: r.idCliente,
        idBarbeiro: 2,
        dataHora: diaSeguinteAs(10),
      );

      final depois = await buscar(r.idCliente, r.idAgendamento);
      expect(depois.pagamento!.natureza, NaturezaPagamento.resgate);
      expect(await service.obterPontos(r.idCliente), 0);
      // Cancelado no prazo, no novo horário, os pontos voltam.
      await service.cancelarAgendamento(r.idAgendamento);
      expect(await service.obterPontos(r.idCliente), 500);
    });
  });
}

/// Envio que sempre falha, como sem internet.
class _EmailQueFalha implements EnvioEmail {
  @override
  Future<void> enviarCodigo({
    required String email,
    required String nome,
    required String codigo,
    required int minutos,
  }) async => throw const FalhaNoEnvioDeEmail('sem conexão');
}
