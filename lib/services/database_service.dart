import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Camada única de acesso ao SQLite (padrão Singleton).
///
/// Toda leitura e escrita do aplicativo passa por aqui — nenhuma tela conversa
/// diretamente com o banco.
class DatabaseService {
  DatabaseService._interno();

  static final DatabaseService instance = DatabaseService._interno();

  static const String nomeBanco = 'sysbarber.db';

  /// v2: barbeiro ganhou contato/acesso/salário e pagamento ganhou tipo e
  /// cartão mascarado.
  /// v3: cliente ganhou a marca de administrador e a conta demo virou admin.
  static const int versaoBanco = 3;

  /// Credenciais da conta administradora criada no seed.
  static const String emailAdmin = 'admin@sysbarber.com';
  static const String senhaAdmin = 'admin1234';

  /// Grade de horários atendidos pela barbearia.
  static const List<String> horariosBase = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
  ];

  Database? _db;

  // -------------------------------------------------------------------------
  // ABERTURA / TESTABILIDADE
  // -------------------------------------------------------------------------

  Future<Database> get database async {
    if (_db != null) return _db!;
    final diretorio = await getApplicationDocumentsDirectory();
    final caminho = p.join(diretorio.path, nomeBanco);
    _db = await openDatabase(
      caminho,
      version: versaoBanco,
      onCreate: criarSchema,
      onUpgrade: migrar,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  /// Injeta um banco already-open (usado pelos testes com banco em memória).
  void injetarBancoParaTeste(Database db) {
    _db = db;
  }

  /// Fecha e descarta o banco corrente, isolando um teste do próximo.
  Future<void> resetarParaTeste() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  // -------------------------------------------------------------------------
  // SCHEMA + SEED
  // -------------------------------------------------------------------------

  /// Cria todas as tabelas e insere os dados iniciais.
  ///
  /// Público de propósito: os testes de integração reaproveitam este mesmo
  /// método como `onCreate` do banco em memória.
  Future<void> criarSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cliente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telefone TEXT NOT NULL,
        senha_hash TEXT NOT NULL,
        criado_em TEXT NOT NULL,
        admin INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE barbeiro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        especialidade TEXT NOT NULL,
        avaliacao REAL NOT NULL DEFAULT 0,
        avaliacoes INTEGER NOT NULL DEFAULT 0,
        iniciais TEXT NOT NULL,
        telefone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        senha_hash TEXT NOT NULL DEFAULT '',
        salario REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE servico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT NOT NULL,
        preco REAL NOT NULL,
        duracao_minutos INTEGER NOT NULL,
        icone TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE agendamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente INTEGER NOT NULL,
        id_barbeiro INTEGER NOT NULL,
        id_servico INTEGER NOT NULL,
        data_hora TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'confirmado',
        FOREIGN KEY (id_cliente) REFERENCES cliente(id),
        FOREIGN KEY (id_barbeiro) REFERENCES barbeiro(id),
        FOREIGN KEY (id_servico) REFERENCES servico(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pagamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_agendamento INTEGER NOT NULL,
        valor REAL NOT NULL,
        metodo TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Confirmado',
        criado_em TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'antecipado',
        cartao_final TEXT,
        FOREIGN KEY (id_agendamento) REFERENCES agendamento(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE fidelidade (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente INTEGER NOT NULL UNIQUE,
        pontos INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE historico_ponto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente INTEGER NOT NULL,
        descricao TEXT NOT NULL,
        pontos INTEGER NOT NULL,
        criado_em TEXT NOT NULL,
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
      )
    ''');

    await _popularDadosIniciais(db);
  }

  /// Evolui um banco já existente sem apagar os dados do usuário.
  Future<void> migrar(Database db, int versaoAntiga, int versaoNova) async {
    if (versaoAntiga < 2) {
      await db.execute(
        "ALTER TABLE barbeiro ADD COLUMN telefone TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE barbeiro ADD COLUMN email TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE barbeiro ADD COLUMN senha_hash TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE barbeiro ADD COLUMN salario REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE pagamento ADD COLUMN tipo TEXT NOT NULL "
        "DEFAULT 'antecipado'",
      );
      await db.execute('ALTER TABLE pagamento ADD COLUMN cartao_final TEXT');

      // Preenche o acesso dos barbeiros que já existiam.
      final antigos = await db.query('barbeiro');
      for (final b in antigos) {
        final nome = b['nome'] as String;
        final email = _emailPadraoBarbeiro(nome);
        await db.update(
          'barbeiro',
          {
            'email': email,
            'senha_hash': hashSenha('barbeiro123'),
            'telefone': '(67) 99000-0000',
            'salario': 2500.0,
          },
          where: 'id = ?',
          whereArgs: [b['id']],
        );
      }
    }

    if (versaoAntiga < 3) {
      await db.execute(
        'ALTER TABLE cliente ADD COLUMN admin INTEGER NOT NULL DEFAULT 0',
      );
      // A antiga conta `demo` vira a conta administradora.
      await db.update(
        'cliente',
        {
          'nome': 'Administrador',
          'email': emailAdmin,
          'senha_hash': hashSenha(senhaAdmin),
          'admin': 1,
        },
        where: 'email = ?',
        whereArgs: ['demo@sysbarber.com'],
      );
      // Se o banco já vier de uma instalação sem a conta demo, garante que
      // exista exatamente um administrador.
      final admins = await db.query(
        'cliente',
        where: 'admin = 1',
        limit: 1,
      );
      if (admins.isEmpty) {
        await db.update(
          'cliente',
          {'admin': 1},
          where: 'email = ?',
          whereArgs: [emailAdmin],
        );
      }
    }
  }

  /// `Carlos Eduardo` → `carlos.eduardo@sysbarber.com`
  static String _emailPadraoBarbeiro(String nome) {
    final limpo = nome
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éê]'), 'e')
        .replaceAll(RegExp(r'[í]'), 'i')
        .replaceAll(RegExp(r'[óôõ]'), 'o')
        .replaceAll(RegExp(r'[ú]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .replaceAll(RegExp(r'\s+'), '.');
    return '$limpo@sysbarber.com';
  }

  Future<void> _popularDadosIniciais(Database db) async {
    final lote = db.batch();

    // Senha de acesso de todos os barbeiros do seed: `barbeiro123`.
    final barbeiros = [
      Barbeiro(
        nome: 'Carlos Eduardo',
        especialidade: 'Especialista em barba',
        avaliacao: 4.9,
        avaliacoes: 128,
        iniciais: 'CE',
        telefone: '(67) 99101-1001',
        email: 'carlos.eduardo@sysbarber.com',
        senhaHash: hashSenha('barbeiro123'),
        salario: 2800.00,
      ),
      Barbeiro(
        nome: 'Rafael Souza',
        especialidade: 'Cortes modernos',
        avaliacao: 4.7,
        avaliacoes: 95,
        iniciais: 'RS',
        telefone: '(67) 99202-2002',
        email: 'rafael.souza@sysbarber.com',
        senhaHash: hashSenha('barbeiro123'),
        salario: 2500.00,
      ),
      Barbeiro(
        nome: 'Marcos Lima',
        especialidade: 'Coloração e Corte',
        avaliacao: 4.8,
        avaliacoes: 74,
        iniciais: 'ML',
        telefone: '(67) 99303-3003',
        email: 'marcos.lima@sysbarber.com',
        senhaHash: hashSenha('barbeiro123'),
        salario: 2650.00,
      ),
    ];
    for (final b in barbeiros) {
      lote.insert('barbeiro', b.toMap()..remove('id'));
    }

    const servicos = [
      Servico(
        nome: 'Corte de Cabelo',
        descricao: 'Tesoura ou máquina',
        preco: 35.00,
        duracaoMinutos: 30,
        icone: '✂️',
      ),
      Servico(
        nome: 'Barba',
        descricao: 'Navalha + toalha quente',
        preco: 25.00,
        duracaoMinutos: 25,
        icone: '🪒',
      ),
      Servico(
        nome: 'Corte + Barba',
        descricao: 'Combo completo',
        preco: 55.00,
        duracaoMinutos: 50,
        icone: '💈',
      ),
      Servico(
        nome: 'Hidratação',
        descricao: 'Tratamento capilar',
        preco: 40.00,
        duracaoMinutos: 40,
        icone: '💆',
      ),
      Servico(
        nome: 'Coloração',
        descricao: 'Tintura profissional',
        preco: 80.00,
        duracaoMinutos: 60,
        icone: '🎨',
      ),
    ];
    for (final s in servicos) {
      lote.insert('servico', s.toMap()..remove('id'));
    }

    await lote.commit(noResult: true);

    // Conta administradora usada na apresentação para a banca. É a única com
    // acesso à área administrativa — contas criadas pelo cadastro são
    // sempre clientes comuns.
    final idAdmin = await db.insert('cliente', {
      'nome': 'Administrador',
      'email': emailAdmin,
      'telefone': '(67) 99999-0000',
      'senha_hash': hashSenha(senhaAdmin),
      'criado_em': DateTime.now().toIso8601String(),
      'admin': 1,
    });
    await db.insert('fidelidade', {'id_cliente': idAdmin, 'pontos': 0});
  }

  // -------------------------------------------------------------------------
  // SEGURANÇA
  // -------------------------------------------------------------------------

  /// SHA-256 com salt fixo. Senhas nunca são gravadas em texto puro.
  static String hashSenha(String senha) {
    final bytes = utf8.encode('sysbarber_salt_$senha');
    return sha256.convert(bytes).toString();
  }

  // -------------------------------------------------------------------------
  // CLIENTE
  // -------------------------------------------------------------------------

  /// Insere o cliente e já cria seu registro de fidelidade zerado.
  ///
  /// O e-mail é normalizado para minúsculas porque toda busca é feita assim —
  /// sem isso um cadastro com maiúsculas nunca mais seria encontrado.
  Future<int> cadastrarCliente(Cliente c) async {
    final db = await database;
    final dados = c.toMap()
      ..remove('id')
      ..['email'] = c.email.trim().toLowerCase();
    final id = await db.insert('cliente', dados);
    await db.insert('fidelidade', {'id_cliente': id, 'pontos': 0});
    return id;
  }

  Future<Cliente?> buscarClientePorEmail(String email) async {
    final db = await database;
    final linhas = await db.query(
      'cliente',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Cliente.fromMap(linhas.first);
  }

  Future<Cliente?> buscarClientePorId(int id) async {
    final db = await database;
    final linhas = await db.query(
      'cliente',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Cliente.fromMap(linhas.first);
  }

  Future<bool> emailExiste(String email) async {
    return await buscarClientePorEmail(email) != null;
  }

  /// Retorna o cliente quando e-mail e senha conferem, senão `null`.
  Future<Cliente?> autenticar(String email, String senha) async {
    final cliente = await buscarClientePorEmail(email);
    if (cliente == null) return null;
    if (cliente.senhaHash != hashSenha(senha)) return null;
    return cliente;
  }

  Future<int> atualizarCliente(Cliente c) async {
    final db = await database;
    return db.update(
      'cliente',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> contarClientes() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS total FROM cliente');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // -------------------------------------------------------------------------
  // BARBEIROS E SERVIÇOS
  // -------------------------------------------------------------------------

  Future<List<Barbeiro>> listarBarbeiros() async {
    final db = await database;
    final linhas = await db.query('barbeiro', orderBy: 'id');
    return linhas.map(Barbeiro.fromMap).toList();
  }

  Future<Barbeiro?> buscarBarbeiroPorEmail(String email) async {
    final db = await database;
    final linhas = await db.query(
      'barbeiro',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Barbeiro.fromMap(linhas.first);
  }

  /// Verifica se o e-mail já pertence a outro barbeiro.
  ///
  /// [ignorarId] permite editar um barbeiro sem colidir com ele mesmo.
  Future<bool> emailBarbeiroExiste(String email, {int? ignorarId}) async {
    final existente = await buscarBarbeiroPorEmail(email);
    if (existente == null) return false;
    return existente.id != ignorarId;
  }

  /// Autentica um profissional pelo e-mail e senha de acesso.
  Future<Barbeiro?> autenticarBarbeiro(String email, String senha) async {
    final barbeiro = await buscarBarbeiroPorEmail(email);
    if (barbeiro == null) return null;
    if (barbeiro.senhaHash.isEmpty) return null;
    if (barbeiro.senhaHash != hashSenha(senha)) return null;
    return barbeiro;
  }

  Future<int> cadastrarBarbeiro(Barbeiro b) async {
    final db = await database;
    final dados = b.toMap()
      ..remove('id')
      ..['email'] = b.email.trim().toLowerCase();
    return db.insert('barbeiro', dados);
  }

  Future<int> atualizarBarbeiro(Barbeiro b) async {
    final db = await database;
    final dados = b.toMap()..['email'] = b.email.trim().toLowerCase();
    return db.update('barbeiro', dados, where: 'id = ?', whereArgs: [b.id]);
  }

  Future<int> excluirBarbeiro(int id) async {
    final db = await database;
    return db.delete('barbeiro', where: 'id = ?', whereArgs: [id]);
  }

  /// Quantos agendamentos dependem deste barbeiro.
  ///
  /// Excluir um barbeiro com agendamentos faria esses registros sumirem da
  /// listagem do cliente (o INNER JOIN deixaria de casar), então a interface
  /// usa esta contagem para bloquear a exclusão.
  Future<int> contarAgendamentosDoBarbeiro(int idBarbeiro) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM agendamento WHERE id_barbeiro = ?',
      [idBarbeiro],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Mesma proteção para serviços.
  Future<int> contarAgendamentosDoServico(int idServico) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM agendamento WHERE id_servico = ?',
      [idServico],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<List<Cliente>> listarClientes() async {
    final db = await database;
    final linhas = await db.query('cliente', orderBy: 'nome COLLATE NOCASE');
    return linhas.map(Cliente.fromMap).toList();
  }

  Future<List<Servico>> listarServicos() async {
    final db = await database;
    final linhas = await db.query('servico', orderBy: 'id');
    return linhas.map(Servico.fromMap).toList();
  }

  Future<int> cadastrarServico(Servico s) async {
    final db = await database;
    return db.insert('servico', s.toMap()..remove('id'));
  }

  Future<int> atualizarServico(Servico s) async {
    final db = await database;
    return db.update(
      'servico',
      s.toMap(),
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<int> excluirServico(int id) async {
    final db = await database;
    return db.delete('servico', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // AGENDAMENTOS
  // -------------------------------------------------------------------------

  Future<int> criarAgendamento(Agendamento a) async {
    final db = await database;
    return db.insert('agendamento', a.toMap()..remove('id'));
  }

  /// Lista os agendamentos do cliente já com barbeiro e serviço carregados
  /// via INNER JOIN — evita uma consulta extra por item na tela.
  Future<List<Agendamento>> listarAgendamentosCliente(int idCliente) async {
    final db = await database;
    final linhas = await db.rawQuery(
      '''
      SELECT
        a.id            AS id,
        a.id_cliente    AS id_cliente,
        a.id_barbeiro   AS id_barbeiro,
        a.id_servico    AS id_servico,
        a.data_hora     AS data_hora,
        a.status        AS status,
        b.id            AS b_id,
        b.nome          AS b_nome,
        b.especialidade AS b_especialidade,
        b.avaliacao     AS b_avaliacao,
        b.avaliacoes    AS b_avaliacoes,
        b.iniciais      AS b_iniciais,
        s.id            AS s_id,
        s.nome          AS s_nome,
        s.descricao     AS s_descricao,
        s.preco         AS s_preco,
        s.duracao_minutos AS s_duracao_minutos,
        s.icone         AS s_icone
      FROM agendamento a
      INNER JOIN barbeiro b ON b.id = a.id_barbeiro
      INNER JOIN servico  s ON s.id = a.id_servico
      WHERE a.id_cliente = ?
      ORDER BY a.data_hora DESC
      ''',
      [idCliente],
    );

    return linhas.map((linha) {
      final barbeiro = Barbeiro.fromMap({
        'id': linha['b_id'],
        'nome': linha['b_nome'],
        'especialidade': linha['b_especialidade'],
        'avaliacao': linha['b_avaliacao'],
        'avaliacoes': linha['b_avaliacoes'],
        'iniciais': linha['b_iniciais'],
      });
      final servico = Servico.fromMap({
        'id': linha['s_id'],
        'nome': linha['s_nome'],
        'descricao': linha['s_descricao'],
        'preco': linha['s_preco'],
        'duracao_minutos': linha['s_duracao_minutos'],
        'icone': linha['s_icone'],
      });
      return Agendamento.fromMap(linha).copyWith(
        barbeiro: barbeiro,
        servico: servico,
      );
    }).toList();
  }

  /// Agenda de um profissional, com o cliente e o serviço já carregados.
  ///
  /// É o espelho de [listarAgendamentosCliente]: lá o cliente vê quem vai
  /// atendê-lo; aqui o barbeiro vê quem vai atender.
  Future<List<Agendamento>> listarAgendamentosBarbeiro(int idBarbeiro) async {
    final db = await database;
    final linhas = await db.rawQuery(
      '''
      SELECT
        a.id            AS id,
        a.id_cliente    AS id_cliente,
        a.id_barbeiro   AS id_barbeiro,
        a.id_servico    AS id_servico,
        a.data_hora     AS data_hora,
        a.status        AS status,
        c.id            AS c_id,
        c.nome          AS c_nome,
        c.email         AS c_email,
        c.telefone      AS c_telefone,
        c.senha_hash    AS c_senha_hash,
        c.criado_em     AS c_criado_em,
        c.admin         AS c_admin,
        s.id            AS s_id,
        s.nome          AS s_nome,
        s.descricao     AS s_descricao,
        s.preco         AS s_preco,
        s.duracao_minutos AS s_duracao_minutos,
        s.icone         AS s_icone
      FROM agendamento a
      INNER JOIN cliente c ON c.id = a.id_cliente
      INNER JOIN servico s ON s.id = a.id_servico
      WHERE a.id_barbeiro = ?
      ORDER BY a.data_hora DESC
      ''',
      [idBarbeiro],
    );

    return linhas.map((linha) {
      final cliente = Cliente.fromMap({
        'id': linha['c_id'],
        'nome': linha['c_nome'],
        'email': linha['c_email'],
        'telefone': linha['c_telefone'],
        'senha_hash': linha['c_senha_hash'],
        'criado_em': linha['c_criado_em'],
        'admin': linha['c_admin'],
      });
      final servico = Servico.fromMap({
        'id': linha['s_id'],
        'nome': linha['s_nome'],
        'descricao': linha['s_descricao'],
        'preco': linha['s_preco'],
        'duracao_minutos': linha['s_duracao_minutos'],
        'icone': linha['s_icone'],
      });
      return Agendamento.fromMap(
        linha,
      ).copyWith(cliente: cliente, servico: servico);
    }).toList();
  }

  Future<int> atualizarStatusAgendamento(
    int id,
    StatusAgendamento status,
  ) async {
    final db = await database;
    return db.update(
      'agendamento',
      {'status': status.dbValue},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> contarAgendamentos() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS total FROM agendamento');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Horários da grade que continuam livres para o barbeiro naquela data.
  ///
  /// Agendamentos cancelados não bloqueiam o horário (regra de negócio 2).
  Future<List<String>> horariosDisponiveis(
    int idBarbeiro,
    DateTime data,
  ) async {
    final db = await database;
    final dia = _formatarDia(data);
    final linhas = await db.query(
      'agendamento',
      columns: ['data_hora'],
      where: 'id_barbeiro = ? AND status != ? AND data_hora LIKE ?',
      whereArgs: [idBarbeiro, StatusAgendamento.cancelado.dbValue, '$dia%'],
    );

    final ocupados = linhas
        .map((l) => DateTime.parse(l['data_hora'] as String))
        .map((d) => '${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}')
        .toSet();

    return horariosBase.where((h) => !ocupados.contains(h)).toList();
  }

  // -------------------------------------------------------------------------
  // PAGAMENTOS E FIDELIDADE
  // -------------------------------------------------------------------------

  Future<int> criarPagamento(Pagamento p) async {
    final db = await database;
    return db.insert('pagamento', p.toMap()..remove('id'));
  }

  Future<Pagamento?> buscarPagamentoDoAgendamento(int idAgendamento) async {
    final db = await database;
    final linhas = await db.query(
      'pagamento',
      where: 'id_agendamento = ?',
      whereArgs: [idAgendamento],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Pagamento.fromMap(linhas.first);
  }

  Future<List<Pagamento>> listarPagamentos() async {
    final db = await database;
    final linhas = await db.query('pagamento', orderBy: 'id DESC');
    return linhas.map(Pagamento.fromMap).toList();
  }

  /// Efetiva um pagamento pendente e só então credita os pontos.
  ///
  /// Regra de negócio 4: fidelidade acompanha dinheiro que entrou. Um
  /// pagamento marcado para "pagar na barbearia" não pontua enquanto não for
  /// quitado. A operação é idempotente — confirmar duas vezes não duplica os
  /// pontos.
  Future<bool> confirmarPagamento(int idPagamento) async {
    final db = await database;
    final linhas = await db.query(
      'pagamento',
      where: 'id = ?',
      whereArgs: [idPagamento],
      limit: 1,
    );
    if (linhas.isEmpty) return false;

    final pagamento = Pagamento.fromMap(linhas.first);
    if (pagamento.confirmado) return false;

    final agendamentos = await db.query(
      'agendamento',
      columns: ['id_cliente'],
      where: 'id = ?',
      whereArgs: [pagamento.idAgendamento],
      limit: 1,
    );
    if (agendamentos.isEmpty) return false;
    final idCliente = (agendamentos.first['id_cliente'] as num).toInt();

    await db.update(
      'pagamento',
      {'status': 'Confirmado'},
      where: 'id = ?',
      whereArgs: [idPagamento],
    );

    final servico = await db.rawQuery(
      '''
      SELECT s.nome AS nome
      FROM agendamento a
      INNER JOIN servico s ON s.id = a.id_servico
      WHERE a.id = ?
      ''',
      [pagamento.idAgendamento],
    );
    final nomeServico = servico.isEmpty
        ? 'Serviço'
        : servico.first['nome'] as String;

    await adicionarPontos(
      idCliente,
      pagamento.valor.round(),
      'Pagamento — $nomeServico',
    );
    return true;
  }

  // -------------------------------------------------------------------------
  // PAINEL DO DIA
  // -------------------------------------------------------------------------

  /// Movimento do dia informado (por padrão, hoje).
  ///
  /// Agendamentos cancelados não entram: o painel mostra a operação que
  /// realmente acontece no dia.
  Future<ResumoDia> resumoDoDia([DateTime? data]) async {
    final db = await database;
    final dia = _formatarDia(data ?? DateTime.now());
    const cancelado = 'cancelado';

    Future<int> conta(String sql, [List<Object?>? args]) async {
      final r = await db.rawQuery(sql, args);
      return Sqflite.firstIntValue(r) ?? 0;
    }

    return ResumoDia(
      agendamentosHoje: await conta(
        'SELECT COUNT(*) FROM agendamento '
        'WHERE data_hora LIKE ? AND status != ?',
        ['$dia%', cancelado],
      ),
      agendamentosTotal: await conta('SELECT COUNT(*) FROM agendamento'),
      barbeirosHoje: await conta(
        'SELECT COUNT(DISTINCT id_barbeiro) FROM agendamento '
        'WHERE data_hora LIKE ? AND status != ?',
        ['$dia%', cancelado],
      ),
      barbeirosTotal: await conta('SELECT COUNT(*) FROM barbeiro'),
      clientesHoje: await conta(
        'SELECT COUNT(DISTINCT id_cliente) FROM agendamento '
        'WHERE data_hora LIKE ? AND status != ?',
        ['$dia%', cancelado],
      ),
      clientesTotal: await conta('SELECT COUNT(*) FROM cliente'),
      servicosHoje: await conta(
        'SELECT COUNT(DISTINCT id_servico) FROM agendamento '
        'WHERE data_hora LIKE ? AND status != ?',
        ['$dia%', cancelado],
      ),
      servicosTotal: await conta('SELECT COUNT(*) FROM servico'),
    );
  }

  // -------------------------------------------------------------------------
  // RELATÓRIOS
  // -------------------------------------------------------------------------

  /// Indicadores consolidados para a tela de Relatórios.
  Future<RelatorioGeral> gerarRelatorio() async {
    final db = await database;

    Future<double> soma(String sql, [List<Object?>? args]) async {
      final r = await db.rawQuery(sql, args);
      final v = r.isEmpty ? null : r.first.values.first;
      return (v as num?)?.toDouble() ?? 0;
    }

    Future<int> conta(String sql, [List<Object?>? args]) async {
      final r = await db.rawQuery(sql, args);
      return Sqflite.firstIntValue(r) ?? 0;
    }

    final faturamento = await soma(
      "SELECT SUM(valor) FROM pagamento WHERE status = 'Confirmado'",
    );
    final aReceber = await soma(
      "SELECT SUM(valor) FROM pagamento WHERE status = 'Pendente'",
    );
    final pagamentosConfirmados = await conta(
      "SELECT COUNT(*) FROM pagamento WHERE status = 'Confirmado'",
    );
    final folha = await soma('SELECT SUM(salario) FROM barbeiro');

    final porMetodo = await db.rawQuery(
      '''
      SELECT metodo, COUNT(*) AS qtd, SUM(valor) AS total
      FROM pagamento WHERE status = 'Confirmado'
      GROUP BY metodo ORDER BY total DESC
      ''',
    );

    final porServico = await db.rawQuery(
      '''
      SELECT s.nome AS nome, COUNT(*) AS qtd
      FROM agendamento a
      INNER JOIN servico s ON s.id = a.id_servico
      WHERE a.status != 'cancelado'
      GROUP BY s.id ORDER BY qtd DESC LIMIT 5
      ''',
    );

    final porBarbeiro = await db.rawQuery(
      '''
      SELECT b.nome AS nome, COUNT(*) AS qtd
      FROM agendamento a
      INNER JOIN barbeiro b ON b.id = a.id_barbeiro
      WHERE a.status != 'cancelado'
      GROUP BY b.id ORDER BY qtd DESC LIMIT 5
      ''',
    );

    return RelatorioGeral(
      faturamento: faturamento,
      aReceber: aReceber,
      ticketMedio: pagamentosConfirmados == 0
          ? 0
          : faturamento / pagamentosConfirmados,
      folhaSalarial: folha,
      totalAgendamentos: await conta('SELECT COUNT(*) FROM agendamento'),
      confirmados: await conta(
        "SELECT COUNT(*) FROM agendamento WHERE status = 'confirmado'",
      ),
      cancelados: await conta(
        "SELECT COUNT(*) FROM agendamento WHERE status = 'cancelado'",
      ),
      finalizados: await conta(
        "SELECT COUNT(*) FROM agendamento WHERE status = 'finalizado'",
      ),
      totalClientes: await conta('SELECT COUNT(*) FROM cliente'),
      pontosEmCirculacao: await conta('SELECT SUM(pontos) FROM fidelidade'),
      porMetodo: porMetodo
          .map(
            (l) => ItemRelatorio(
              rotulo: l['metodo'] as String,
              quantidade: (l['qtd'] as num).toInt(),
              valor: (l['total'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      porServico: porServico
          .map(
            (l) => ItemRelatorio(
              rotulo: l['nome'] as String,
              quantidade: (l['qtd'] as num).toInt(),
            ),
          )
          .toList(),
      porBarbeiro: porBarbeiro
          .map(
            (l) => ItemRelatorio(
              rotulo: l['nome'] as String,
              quantidade: (l['qtd'] as num).toInt(),
            ),
          )
          .toList(),
    );
  }

  Future<int> obterPontos(int idCliente) async {
    final db = await database;
    final linhas = await db.query(
      'fidelidade',
      columns: ['pontos'],
      where: 'id_cliente = ?',
      whereArgs: [idCliente],
      limit: 1,
    );
    if (linhas.isEmpty) return 0;
    return (linhas.first['pontos'] as num).toInt();
  }

  /// Credita (ou debita, com valor negativo) pontos e registra no histórico.
  Future<void> adicionarPontos(
    int idCliente,
    int pontos,
    String descricao,
  ) async {
    final db = await database;
    final atual = await obterPontos(idCliente);
    final existe = await db.query(
      'fidelidade',
      where: 'id_cliente = ?',
      whereArgs: [idCliente],
      limit: 1,
    );

    if (existe.isEmpty) {
      await db.insert('fidelidade', {
        'id_cliente': idCliente,
        'pontos': pontos,
      });
    } else {
      await db.update(
        'fidelidade',
        {'pontos': atual + pontos},
        where: 'id_cliente = ?',
        whereArgs: [idCliente],
      );
    }

    await db.insert('historico_ponto', {
      'id_cliente': idCliente,
      'descricao': descricao,
      'pontos': pontos,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<List<HistoricoPonto>> listarHistoricoPontos(int idCliente) async {
    final db = await database;
    final linhas = await db.query(
      'historico_ponto',
      where: 'id_cliente = ?',
      whereArgs: [idCliente],
      orderBy: 'id DESC',
    );
    return linhas.map(HistoricoPonto.fromMap).toList();
  }

  // -------------------------------------------------------------------------
  // AUXILIARES
  // -------------------------------------------------------------------------

  static String _doisDigitos(int n) => n.toString().padLeft(2, '0');

  static String _formatarDia(DateTime d) =>
      '${d.year}-${_doisDigitos(d.month)}-${_doisDigitos(d.day)}';
}
