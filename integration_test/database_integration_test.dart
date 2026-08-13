import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/database_service.dart';

/// Testes de integração do [DatabaseService].
///
/// Cada teste roda contra um banco SQLite **em memória** criado do zero,
/// garantindo isolamento total entre os casos.
void main() {
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    service = DatabaseService.instance;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: service.criarSchema),
    );
    service.injetarBancoParaTeste(db);
  });

  tearDown(() async => await service.resetarParaTeste());

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

  // -------------------------------------------------------------------------
  group('Dados iniciais (seed)', () {
    test('cria os 3 barbeiros', () async {
      final barbeiros = await service.listarBarbeiros();
      expect(barbeiros.length, 3);
      expect(barbeiros.first.nome, 'Carlos Eduardo');
      expect(barbeiros.first.avaliacao, 4.9);
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
        DatabaseService.emailAdmin,
      );
      expect(admin, isNotNull);
      expect(admin!.nome, 'Administrador');
      expect(admin.admin, isTrue);
      expect(admin.senhaHash, isNot(equals(DatabaseService.senhaAdmin)));
      expect(
        admin.senhaHash,
        DatabaseService.hashSenha(DatabaseService.senhaAdmin),
      );
    });

    test('a conta administradora é a única com privilégio', () async {
      final clientes = await service.listarClientes();
      expect(clientes.where((c) => c.admin).length, 1);
      expect(clientes.firstWhere((c) => c.admin).email,
          DatabaseService.emailAdmin);
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
      expect(await service.emailExiste(DatabaseService.emailAdmin), isTrue);
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

      final amanha = DateTime.now().add(const Duration(days: 1));
      final data = DateTime(amanha.year, amanha.month, amanha.day);

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
      expect(b.senhaHash, DatabaseService.hashSenha('barbeiro123'));
    });

    test('cadastra, edita e exclui um barbeiro', () async {
      final id = await service.cadastrarBarbeiro(
        Barbeiro(
          nome: 'Pedro Alves',
          especialidade: 'Degradê',
          avaliacao: 0,
          avaliacoes: 0,
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

      await service.atualizarBarbeiro(salvo.copyWith(salario: 3000.00));
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
}
