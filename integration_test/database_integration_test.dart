import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/auth_service.dart';
import 'package:sysbarber/services/booking_flow.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/senhas.dart';

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
        Senhas.conferir(DatabaseService.senhaAdmin, admin.senhaHash),
        isTrue,
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
      expect(Senhas.conferir('barbeiro123', b.senhaHash), isTrue);
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
      final amanha = DateTime.now().add(const Duration(days: 1));

      final livres = await service.horariosDisponiveis(barbeiro.id!, amanha);
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

  /// Agendamento de teste para amanhã no horário informado.
  Future<int> agendarAmanha(
    int idCliente, {
    int hora = 9,
    int minuto = 0,
    int idBarbeiro = 1,
    int idServico = 1,
  }) {
    final d = DateTime.now().add(const Duration(days: 1));
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
      final a1 = await agendarAmanha(idCliente, hora: 9);
      final a2 = await agendarAmanha(idCliente, hora: 14);

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
      final a = await agendarAmanha(idCliente);
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

  /// Amanhã no horário informado.
  DateTime amanhaAs(int hora, [int minuto = 0]) {
    final d = DateTime.now().add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day, hora, minuto);
  }

  group('Correção 2 — reserva atômica (agendamento + pagamento)', () {
    test('pagar agora grava os dois registros e credita os pontos', () async {
      final idCliente = await criarClienteTeste();

      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // Corte + Barba, R$ 55
        dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
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
          dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(10),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: c2,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: amanhaAs(10),
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
        await service.horariosDisponiveis(inativo.id!, amanhaAs(0)),
        isEmpty,
      );
      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: inativo.id!,
          idServico: 1,
          dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
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
        await service.verificarReserva(idBarbeiro: 1, dataHora: amanhaAs(9)),
        isNull,
      );
      await agendarAmanha(idCliente, hora: 9);
      expect(
        await service.verificarReserva(idBarbeiro: 1, dataHora: amanhaAs(9)),
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
        dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      final gratis = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: amanhaAs(14),
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
      final id = await agendarAmanha(idCliente);

      await expectLater(
        service.finalizarAgendamento(id),
        throwsA(isA<RegraNegocioException>()),
      );
      final lista = await service.listarAgendamentosCliente(idCliente);
      expect(lista.first.status, StatusAgendamento.confirmado);
    });

    test('conclui depois do horário marcado', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarAmanha(idCliente, hora: 9);

      // Antes a opção sumia da tela exatamente neste momento.
      final depois = amanhaAs(11);
      expect(await service.finalizarAgendamento(id, agora: depois), 1);
    });

    test('atendimento concluído não pode ser cancelado nem estornado',
        () async {
      final idCliente = await criarClienteTeste();
      final r = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3,
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.finalizarAgendamento(r.idAgendamento, agora: amanhaAs(10));

      await expectLater(
        service.cancelarAgendamento(r.idAgendamento, porBarbeiro: true),
        throwsA(isA<RegraNegocioException>()),
      );
      expect((await service.gerarRelatorio()).faturamento, 55);
      expect(await service.obterPontos(idCliente), 55);
    });

    test('cancelar duas vezes é recusado', () async {
      final idCliente = await criarClienteTeste();
      final id = await agendarAmanha(idCliente);
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.registrarFalta(r.idAgendamento, agora: amanhaAs(8)),
        throwsA(isA<RegraNegocioException>()),
      );

      final resultado = await service.registrarFalta(
        r.idAgendamento,
        agora: amanhaAs(10),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 5, // prêmio → sobram 15 pontos
        dataHora: amanhaAs(14),
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
          dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      final livres = await service.horariosDisponiveis(1, amanhaAs(0));
      expect(livres, isNot(contains('09:00')));
      expect(livres, isNot(contains('09:30'))); // antes: oferecido
      expect(livres, contains('10:00'));
    });

    test('serviço longo não é oferecido onde não cabe', () async {
      final idCliente = await criarClienteTeste();
      await agendarAmanha(idCliente, hora: 10); // Corte, 30 min

      final livres = await service.horariosDisponiveis(
        1,
        amanhaAs(0),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: c2,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: amanhaAs(9, 30),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );

      await expectLater(
        service.reservar(
          idCliente: idCliente,
          idBarbeiro: 2,
          idServico: 1,
          dataHora: amanhaAs(9, 30),
          modo: ModoReserva.pagarNaBarbearia,
        ),
        throwsA(isA<RegraNegocioException>()),
      );
      // Na grade do cliente, o horário também some.
      final livres = await service.horariosDisponiveis(
        2,
        amanhaAs(0),
        idCliente: idCliente,
      );
      expect(livres, isNot(contains('09:30')));
      expect(livres, contains('10:00'));
    });

    test('o banco recusa dois agendamentos no mesmo horário', () async {
      final idCliente = await criarClienteTeste();
      await agendarAmanha(idCliente, hora: 11);

      await expectLater(
        agendarAmanha(idCliente, hora: 11),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      // Encurtar o serviço depois não libera o que já foi marcado.
      final coloracao = (await service.listarServicos()).firstWhere(
        (s) => s.id == 5,
      );
      await service.atualizarServico(coloracao.copyWith(duracaoMinutos: 30));

      final livres = await service.horariosDisponiveis(1, amanhaAs(0));
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
      await service.atualizarBarbeiro(
        Barbeiro(
          id: inativo.id,
          nome: inativo.nome,
          especialidade: 'Coloração, Corte e Barba',
          avaliacao: inativo.avaliacao,
          avaliacoes: inativo.avaliacoes,
          iniciais: inativo.iniciais,
          telefone: inativo.telefone,
          email: inativo.email,
          senhaHash: inativo.senhaHash,
          salario: 2700,
        ),
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
        dataHora: amanhaAs(9),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      final estornado = await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 1,
        idServico: 3, // R$ 55, cancelado no prazo
        dataHora: amanhaAs(14),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.resgatarPontos,
      );
      await service.reservar(
        idCliente: idCliente,
        idBarbeiro: 2,
        idServico: 1,
        dataHora: amanhaAs(14),
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
      final id = await agendarAmanha(idCliente);
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );
      // Cancelado 30 min antes: retém 27,50 e estorna 27,50.
      await service.cancelarAgendamento(
        r.idAgendamento,
        agora: amanhaAs(8, 30),
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarNaBarbearia,
      );
      await agendarAmanha(idCliente, hora: 14); // sem pagamento

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
        dataHora: amanhaAs(9),
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
      await agendarAmanha(idCliente);

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
      await service.atualizarBarbeiro(
        b.copyWith(senhaHash: Senhas.hashLegado('barbeiro123')),
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

    test('cliente comum com o e-mail oficial não é promovido nem quebra a '
        'migração', () async {
      final db = await bancoV2();
      await inserirCliente(db, 'demo@sysbarber.com');
      final intruso = await inserirCliente(db, DatabaseService.emailAdmin);

      // Antes: o UPDATE violava o UNIQUE do e-mail e o app não abria.
      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final lista = await admins(db);
      expect(lista.length, 1);
      expect(lista.single['email'], 'demo@sysbarber.com');
      expect(lista.single['id'], isNot(intruso));
      await db.close();
    });

    test('sem conta demo e com o e-mail oficial tomado, cria uma '
        'administradora própria', () async {
      final db = await bancoV2();
      final intruso = await inserirCliente(db, DatabaseService.emailAdmin);

      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final lista = await admins(db);
      expect(lista.length, 1);
      expect(lista.single['id'], isNot(intruso));
      expect(lista.single['email'], DatabaseService.emailAdminAlternativo);
      await db.close();
    });

    test('caminho feliz: a conta demo vira a administradora oficial',
        () async {
      final db = await bancoV2();
      await inserirCliente(db, 'demo@sysbarber.com');

      await service.migrar(db, 2, DatabaseService.versaoBanco);

      final lista = await admins(db);
      expect(lista.single['email'], DatabaseService.emailAdmin);
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
  });

  group('Correção 13 — sessão do barbeiro e acesso às rotas', () {
    final auth = AuthService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await auth.logout();
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
      expect(auth.rotaInicial, '/agendamentos');
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
          avaliacao: 0,
          avaliacoes: 0,
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
      expect(auth.podeAcessar('/home'), isFalse);
      expect(auth.podeAcessar('/admin'), isFalse);

      // Cliente comum.
      await criarClienteTeste(senha: 'senha123');
      await auth.login('novo@teste.com', 'senha123');
      expect(auth.podeAcessar('/home'), isTrue);
      expect(auth.podeAcessar('/pagamento'), isTrue);
      expect(auth.podeAcessar('/agendamentos'), isTrue);
      expect(auth.podeAcessar('/admin'), isFalse);

      // Administrador.
      await auth.login(DatabaseService.emailAdmin, DatabaseService.senhaAdmin);
      expect(auth.podeAcessar('/admin'), isTrue);

      // Barbeiro: só a própria agenda.
      await auth.login('rafael.souza@sysbarber.com', 'barbeiro123');
      expect(auth.podeAcessar('/agendamentos'), isTrue);
      expect(auth.podeAcessar('/home'), isFalse);
      expect(auth.podeAcessar('/admin'), isFalse);
    });
  });

  group('Correção 14 — rascunho do agendamento', () {
    final auth = AuthService.instance;

    Future<void> preencherRascunho() async {
      BookingFlow.iniciar((await service.listarServicos()).first);
      BookingFlow.barbeiroSelecionado = (await service.listarBarbeiros()).first;
      BookingFlow.dataSelecionada = amanhaAs(0);
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

      await auth.login(DatabaseService.emailAdmin, DatabaseService.senhaAdmin);

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
      await auth.login(DatabaseService.emailAdmin, DatabaseService.senhaAdmin);
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
            avaliacao: 0,
            avaliacoes: 0,
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
        dataHora: amanhaAs(9),
        modo: ModoReserva.pagarAgora,
        metodo: 'Pix',
      );

      final c = await service.cancelarAgendamento(
        r.idAgendamento,
        agora: amanhaAs(8, 30),
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
}
