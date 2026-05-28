import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/models/models.dart';

/// ============================================================
/// TESTES DE INTEGRAÇÃO — Banco de Dados
/// Testam o fluxo completo de operações no banco SQLite,
/// usando um banco EM MEMÓRIA (não afeta o banco real).
///
/// Verifica a integração entre: Entidades + DatabaseService + SQLite
/// ============================================================
void main() {
  // Inicializa o sqflite para rodar em ambiente de teste (desktop)
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService service;

  setUp(() async {
    // Cria um banco novo EM MEMÓRIA antes de cada teste
    service = DatabaseService.instance;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: service.criarSchema,
      ),
    );
    service.injetarBancoParaTeste(db);
  });

  tearDown(() async {
    await service.resetarParaTeste();
  });

  group('Integração: Seed inicial do banco', () {
    test('deve ter 3 barbeiros pré-cadastrados', () async {
      final barbeiros = await service.listarBarbeiros();
      expect(barbeiros.length, 3);
    });

    test('deve ter 5 serviços pré-cadastrados', () async {
      final servicos = await service.listarServicos();
      expect(servicos.length, 5);
    });

    test('deve ter o cliente demo cadastrado', () async {
      final demo = await service.buscarClientePorEmail('demo@sysbarber.com');
      expect(demo, isNotNull);
      expect(demo!.nome, 'Cliente Demo');
    });
  });

  group('Integração: Cadastro e Autenticação de Cliente', () {
    test('deve cadastrar um novo cliente e recuperá-lo', () async {
      final novoCliente = Cliente(
        nome: 'Pedro Teste',
        email: 'pedro@teste.com',
        telefone: '(67) 91234-5678',
        senhaHash: DatabaseService.hashSenha('senha123'),
      );

      final id = await service.cadastrarCliente(novoCliente);
      expect(id, greaterThan(0));

      final recuperado = await service.buscarClientePorEmail('pedro@teste.com');
      expect(recuperado, isNotNull);
      expect(recuperado!.nome, 'Pedro Teste');
    });

    test('autenticação com senha correta deve retornar o cliente', () async {
      final cliente = Cliente(
        nome: 'Ana Login',
        email: 'ana@teste.com',
        telefone: '(67) 90000-0000',
        senhaHash: DatabaseService.hashSenha('minhasenha'),
      );
      await service.cadastrarCliente(cliente);

      final autenticado =
          await service.autenticar('ana@teste.com', 'minhasenha');
      expect(autenticado, isNotNull);
      expect(autenticado!.email, 'ana@teste.com');
    });

    test('autenticação com senha errada deve retornar null', () async {
      final cliente = Cliente(
        nome: 'Carlos',
        email: 'carlos@teste.com',
        telefone: '(67) 90000-1111',
        senhaHash: DatabaseService.hashSenha('correta'),
      );
      await service.cadastrarCliente(cliente);

      final resultado =
          await service.autenticar('carlos@teste.com', 'senhaErrada');
      expect(resultado, isNull);
    });

    test('emailExiste deve detectar e-mail já cadastrado', () async {
      final cliente = Cliente(
        nome: 'Duplicado',
        email: 'dup@teste.com',
        telefone: '(67) 90000-2222',
        senhaHash: 'hash',
      );
      await service.cadastrarCliente(cliente);

      expect(await service.emailExiste('dup@teste.com'), true);
      expect(await service.emailExiste('naoexiste@teste.com'), false);
    });

    test('cadastrar cliente deve criar registro de fidelidade com 0 pontos',
        () async {
      final cliente = Cliente(
        nome: 'Fidelidade Teste',
        email: 'fid@teste.com',
        telefone: '(67) 90000-3333',
        senhaHash: 'hash',
      );
      final id = await service.cadastrarCliente(cliente);

      final pontos = await service.obterPontos(id);
      expect(pontos, 0);
    });
  });

  group('Integração: Fluxo completo de Agendamento', () {
    test('deve criar agendamento e recuperá-lo com dados do barbeiro/serviço',
        () async {
      // Cliente
      final idCliente = await service.cadastrarCliente(Cliente(
        nome: 'Cliente Agenda',
        email: 'agenda@teste.com',
        telefone: '(67) 90000-4444',
        senhaHash: 'hash',
      ));

      // Pega barbeiro e serviço do seed
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();

      // Cria agendamento
      final idAg = await service.criarAgendamento(Agendamento(
        idCliente: idCliente,
        idBarbeiro: barbeiros.first.id!,
        idServico: servicos.first.id!,
        dataHora: DateTime(2026, 12, 25, 10, 0),
      ));
      expect(idAg, greaterThan(0));

      // Recupera (testa o JOIN)
      final agendamentos =
          await service.listarAgendamentosCliente(idCliente);
      expect(agendamentos.length, 1);
      expect(agendamentos.first.barbeiro, isNotNull);
      expect(agendamentos.first.servico, isNotNull);
      expect(agendamentos.first.barbeiro!.nome, barbeiros.first.nome);
    });

    test('cancelar agendamento deve mudar o status', () async {
      final idCliente = await service.cadastrarCliente(Cliente(
        nome: 'Cancela Teste',
        email: 'cancela@teste.com',
        telefone: '(67) 90000-5555',
        senhaHash: 'hash',
      ));
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();

      final idAg = await service.criarAgendamento(Agendamento(
        idCliente: idCliente,
        idBarbeiro: barbeiros.first.id!,
        idServico: servicos.first.id!,
        dataHora: DateTime(2026, 12, 25, 14, 0),
      ));

      await service.atualizarStatusAgendamento(
          idAg, StatusAgendamento.cancelado);

      final agendamentos =
          await service.listarAgendamentosCliente(idCliente);
      expect(agendamentos.first.status, StatusAgendamento.cancelado);
    });

    test('horário agendado deve ficar indisponível', () async {
      final idCliente = await service.cadastrarCliente(Cliente(
        nome: 'Horario Teste',
        email: 'horario@teste.com',
        telefone: '(67) 90000-6666',
        senhaHash: 'hash',
      ));
      final barbeiros = await service.listarBarbeiros();
      final servicos = await service.listarServicos();
      final data = DateTime(2026, 12, 26);

      // Horários antes do agendamento
      final antes =
          await service.horariosDisponiveis(barbeiros.first.id!, data);
      expect(antes.contains('10:00'), true);

      // Agenda às 10:00
      await service.criarAgendamento(Agendamento(
        idCliente: idCliente,
        idBarbeiro: barbeiros.first.id!,
        idServico: servicos.first.id!,
        dataHora: DateTime(2026, 12, 26, 10, 0),
      ));

      // Horários depois — 10:00 não deve mais aparecer
      final depois =
          await service.horariosDisponiveis(barbeiros.first.id!, data);
      expect(depois.contains('10:00'), false);
    });
  });

  group('Integração: Sistema de Fidelidade', () {
    test('adicionar pontos deve atualizar o saldo e o histórico', () async {
      final idCliente = await service.cadastrarCliente(Cliente(
        nome: 'Pontos Teste',
        email: 'pontos@teste.com',
        telefone: '(67) 90000-7777',
        senhaHash: 'hash',
      ));

      await service.adicionarPontos(idCliente, 55, 'Corte + Barba');
      await service.adicionarPontos(idCliente, 25, 'Barba');

      final pontos = await service.obterPontos(idCliente);
      expect(pontos, 80);

      final historico = await service.listarHistoricoPontos(idCliente);
      expect(historico.length, 2);
    });
  });

  group('Integração: CRUD de Serviços (Admin)', () {
    test('deve cadastrar, editar e excluir um serviço', () async {
      // Cadastra
      final id = await service.cadastrarServico(Servico(
        nome: 'Sobrancelha',
        descricao: 'Design de sobrancelha',
        preco: 15.0,
        duracaoMinutos: 15,
        icone: '✨',
      ));
      expect(id, greaterThan(0));

      var servicos = await service.listarServicos();
      expect(servicos.length, 6); // 5 do seed + 1 novo

      // Edita
      await service.atualizarServico(Servico(
        id: id,
        nome: 'Sobrancelha Premium',
        descricao: 'Design + henna',
        preco: 25.0,
        duracaoMinutos: 20,
        icone: '✨',
      ));

      // Exclui
      await service.excluirServico(id);
      servicos = await service.listarServicos();
      expect(servicos.length, 5); // voltou ao original
    });
  });
}
