import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  /// Permite injetar um banco de dados (usado nos testes com banco em memória).
  /// Em produção, deixe como null para usar o banco padrão no dispositivo.
  void injetarBancoParaTeste(Database db) {
    _db = db;
  }

  /// Fecha e limpa a referência do banco (útil entre testes).
  Future<void> resetarParaTeste() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'sysbarber.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: criarSchema,
    );
  }

  /// Cria todo o schema do banco (tabelas + dados iniciais).
  /// Exposto publicamente para reuso nos testes.
  Future<void> criarSchema(Database db, int version) async {
    // Tabela CLIENTE
    await db.execute('''
      CREATE TABLE cliente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telefone TEXT NOT NULL,
        senha_hash TEXT NOT NULL,
        criado_em TEXT NOT NULL
      )
    ''');

    // Tabela BARBEIRO
    await db.execute('''
      CREATE TABLE barbeiro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        especialidade TEXT NOT NULL,
        avaliacao REAL NOT NULL DEFAULT 0,
        avaliacoes INTEGER NOT NULL DEFAULT 0,
        iniciais TEXT NOT NULL
      )
    ''');

    // Tabela SERVICO
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

    // Tabela AGENDAMENTO
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

    // Tabela PAGAMENTO
    await db.execute('''
      CREATE TABLE pagamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_agendamento INTEGER NOT NULL,
        valor REAL NOT NULL,
        metodo TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Confirmado',
        criado_em TEXT NOT NULL,
        FOREIGN KEY (id_agendamento) REFERENCES agendamento(id)
      )
    ''');

    // Tabela FIDELIDADE
    await db.execute('''
      CREATE TABLE fidelidade (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente INTEGER NOT NULL UNIQUE,
        pontos INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
      )
    ''');

    // Tabela HISTORICO_PONTOS
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

    // Seed: dados iniciais
    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    // Barbeiros
    final barbeiros = [
      {
        'nome': 'Carlos Eduardo',
        'especialidade': 'Especialista em barba',
        'avaliacao': 4.9,
        'avaliacoes': 128,
        'iniciais': 'CE',
      },
      {
        'nome': 'Rafael Souza',
        'especialidade': 'Cortes modernos',
        'avaliacao': 4.7,
        'avaliacoes': 95,
        'iniciais': 'RS',
      },
      {
        'nome': 'Marcos Lima',
        'especialidade': 'Coloração e Corte',
        'avaliacao': 4.8,
        'avaliacoes': 74,
        'iniciais': 'ML',
      },
    ];
    for (final b in barbeiros) {
      await db.insert('barbeiro', b);
    }

    // Serviços
    final servicos = [
      {
        'nome': 'Corte de Cabelo',
        'descricao': 'Tesoura ou máquina',
        'preco': 35.0,
        'duracao_minutos': 30,
        'icone': '✂️',
      },
      {
        'nome': 'Barba',
        'descricao': 'Navalha + toalha quente',
        'preco': 25.0,
        'duracao_minutos': 25,
        'icone': '🪒',
      },
      {
        'nome': 'Corte + Barba',
        'descricao': 'Combo completo',
        'preco': 55.0,
        'duracao_minutos': 50,
        'icone': '💈',
      },
      {
        'nome': 'Hidratação',
        'descricao': 'Tratamento capilar',
        'preco': 40.0,
        'duracao_minutos': 40,
        'icone': '💆',
      },
      {
        'nome': 'Coloração',
        'descricao': 'Tintura profissional',
        'preco': 80.0,
        'duracao_minutos': 60,
        'icone': '🎨',
      },
    ];
    for (final s in servicos) {
      await db.insert('servico', s);
    }

    // Cliente DEMO pra facilitar apresentação
    final senhaDemo = hashSenha('demo1234');
    final idCliente = await db.insert('cliente', {
      'nome': 'Cliente Demo',
      'email': 'demo@sysbarber.com',
      'telefone': '(67) 99999-0000',
      'senha_hash': senhaDemo,
      'criado_em': DateTime.now().toIso8601String(),
    });

    // Fidelidade inicial
    await db.insert('fidelidade', {
      'id_cliente': idCliente,
      'pontos': 0,
    });
  }

  // ─── Hash de senha ────────────────────────────────────────────────
  static String hashSenha(String senha) {
    final bytes = utf8.encode('sysbarber_salt_$senha');
    return sha256.convert(bytes).toString();
  }

  // ─── CRUD CLIENTE ─────────────────────────────────────────────────
  Future<int> cadastrarCliente(Cliente c) async {
    final db = await database;
    final id = await db.insert('cliente', c.toMap());
    // Criar fidelidade automaticamente
    await db.insert('fidelidade', {'id_cliente': id, 'pontos': 0});
    return id;
  }

  Future<Cliente?> buscarClientePorEmail(String email) async {
    final db = await database;
    final rows =
        await db.query('cliente', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return null;
    return Cliente.fromMap(rows.first);
  }

  Future<Cliente?> buscarClientePorId(int id) async {
    final db = await database;
    final rows = await db.query('cliente', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Cliente.fromMap(rows.first);
  }

  Future<bool> emailExiste(String email) async {
    final c = await buscarClientePorEmail(email);
    return c != null;
  }

  Future<Cliente?> autenticar(String email, String senha) async {
    final c = await buscarClientePorEmail(email);
    if (c == null) return null;
    if (c.senhaHash != hashSenha(senha)) return null;
    return c;
  }

  Future<int> atualizarCliente(Cliente c) async {
    final db = await database;
    return await db
        .update('cliente', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  // ─── BARBEIROS ────────────────────────────────────────────────────
  Future<List<Barbeiro>> listarBarbeiros() async {
    final db = await database;
    final rows = await db.query('barbeiro', orderBy: 'nome');
    return rows.map(Barbeiro.fromMap).toList();
  }

  // ─── SERVIÇOS ─────────────────────────────────────────────────────
  Future<List<Servico>> listarServicos() async {
    final db = await database;
    final rows = await db.query('servico', orderBy: 'id');
    return rows.map(Servico.fromMap).toList();
  }

  Future<int> cadastrarServico(Servico s) async {
    final db = await database;
    return await db.insert('servico', s.toMap());
  }

  Future<int> atualizarServico(Servico s) async {
    final db = await database;
    return await db
        .update('servico', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> excluirServico(int id) async {
    final db = await database;
    return await db.delete('servico', where: 'id = ?', whereArgs: [id]);
  }

  // ─── AGENDAMENTOS ─────────────────────────────────────────────────
  Future<int> criarAgendamento(Agendamento a) async {
    final db = await database;
    return await db.insert('agendamento', a.toMap());
  }

  Future<List<Agendamento>> listarAgendamentosCliente(int idCliente) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*, 
             b.nome AS b_nome, b.especialidade AS b_esp, 
             b.avaliacao AS b_aval, b.avaliacoes AS b_avs, b.iniciais AS b_ini,
             s.nome AS s_nome, s.descricao AS s_desc, 
             s.preco AS s_preco, s.duracao_minutos AS s_dur, s.icone AS s_ico
      FROM agendamento a
      INNER JOIN barbeiro b ON a.id_barbeiro = b.id
      INNER JOIN servico s ON a.id_servico = s.id
      WHERE a.id_cliente = ?
      ORDER BY a.data_hora DESC
    ''', [idCliente]);

    return rows.map((r) {
      final ag = Agendamento.fromMap({
        'id': r['id'],
        'id_cliente': r['id_cliente'],
        'id_barbeiro': r['id_barbeiro'],
        'id_servico': r['id_servico'],
        'data_hora': r['data_hora'],
        'status': r['status'],
      });
      ag.barbeiro = Barbeiro(
        id: r['id_barbeiro'] as int,
        nome: r['b_nome'] as String,
        especialidade: r['b_esp'] as String,
        avaliacao: (r['b_aval'] as num).toDouble(),
        avaliacoes: r['b_avs'] as int,
        iniciais: r['b_ini'] as String,
      );
      ag.servico = Servico(
        id: r['id_servico'] as int,
        nome: r['s_nome'] as String,
        descricao: r['s_desc'] as String,
        preco: (r['s_preco'] as num).toDouble(),
        duracaoMinutos: r['s_dur'] as int,
        icone: r['s_ico'] as String,
      );
      return ag;
    }).toList();
  }

  Future<int> atualizarStatusAgendamento(
      int id, StatusAgendamento status) async {
    final db = await database;
    return await db.update(
      'agendamento',
      {'status': status.dbValue},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> contarAgendamentos() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM agendamento');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> contarClientes() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM cliente');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Retorna horários disponíveis (que ainda não foram agendados) para um barbeiro em uma data.
  Future<List<String>> horariosDisponiveis(
      int idBarbeiro, DateTime data) async {
    const todos = [
      '09:00', '09:30', '10:00', '10:30', '11:00',
      '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
    ];
    final db = await database;
    final ini = DateTime(data.year, data.month, data.day);
    final fim = ini.add(const Duration(days: 1));
    final rows = await db.query(
      'agendamento',
      where:
          'id_barbeiro = ? AND data_hora >= ? AND data_hora < ? AND status != ?',
      whereArgs: [
        idBarbeiro,
        ini.toIso8601String(),
        fim.toIso8601String(),
        'cancelado',
      ],
    );
    final ocupados = rows.map((r) {
      final d = DateTime.parse(r['data_hora'] as String);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }).toSet();
    return todos.where((h) => !ocupados.contains(h)).toList();
  }

  // ─── PAGAMENTOS ───────────────────────────────────────────────────
  Future<int> criarPagamento(Pagamento p) async {
    final db = await database;
    return await db.insert('pagamento', p.toMap());
  }

  // ─── FIDELIDADE ───────────────────────────────────────────────────
  Future<int> obterPontos(int idCliente) async {
    final db = await database;
    final r = await db
        .query('fidelidade', where: 'id_cliente = ?', whereArgs: [idCliente]);
    if (r.isEmpty) return 0;
    return r.first['pontos'] as int;
  }

  Future<void> adicionarPontos(int idCliente, int pontos, String descricao) async {
    final db = await database;
    final atual = await obterPontos(idCliente);
    await db.update('fidelidade', {'pontos': atual + pontos},
        where: 'id_cliente = ?', whereArgs: [idCliente]);
    await db.insert('historico_ponto', {
      'id_cliente': idCliente,
      'descricao': descricao,
      'pontos': pontos,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<List<HistoricoPonto>> listarHistoricoPontos(int idCliente) async {
    final db = await database;
    final rows = await db.query(
      'historico_ponto',
      where: 'id_cliente = ?',
      whereArgs: [idCliente],
      orderBy: 'criado_em DESC',
    );
    return rows.map(HistoricoPonto.fromMap).toList();
  }
}
