import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'senhas.dart';
import 'validators.dart';

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
  /// v3: cliente ganhou a marca de administrador (a migração não promove
  /// ninguém: sem administrador, o app pede a configuração inicial).
  /// v4: barbeiro ganhou a marca de disponibilidade para novos agendamentos.
  /// v5: pagamento ganhou a natureza do lançamento (serviço, multa, estorno
  /// ou resgate); agendamento guarda a própria duração e o preço da época;
  /// índices únicos por barbeiro e horário e por e-mail de barbeiro (só
  /// quando o banco antigo não tem duplicados) e índices de consulta.
  static const int versaoBanco = 5;

  /// Senha de acesso dos barbeiros dos dados de exemplo (regra de negócio
  /// 15). Não existe senha padrão de administrador: ela é escolhida por quem
  /// configura a barbearia.
  static const String senhaBarbeirosDeExemplo = 'barbeiro123';

  /// Pontos necessários para trocar por um serviço gratuito
  /// (regra de negócio 6).
  static const int pontosParaPremio = 500;

  /// Antecedência mínima para cancelar sem multa (regra de negócio 7).
  static const Duration prazoCancelamento = Duration(hours: 1);

  /// Percentual do serviço cobrado em cancelamentos fora do prazo.
  static const double percentualMulta = 0.5;

  /// Método com que estornos eram registrados até a v4. Desde a v5 o estorno
  /// sai pela mesma forma em que o cliente pagou e é identificado pela
  /// natureza; a constante ficou para a migração reconhecer os antigos.
  static const String metodoEstorno = 'Estorno';

  /// Método registrado na multa por cancelamento em cima da hora.
  static const String metodoMulta = 'Multa por cancelamento';

  /// Método registrado quando o serviço é trocado por pontos.
  static const String metodoResgate = 'Pontos de fidelidade';

  /// Passo da grade, usado como duração quando nenhuma é informada.
  static const int intervaloGrade = 30;

  /// Turnos de atendimento: das 09:00 às 12:00 e das 13:00 às 18:00. O
  /// serviço inteiro precisa terminar dentro do turno em que começa.
  static const List<({String inicio, String fim})> turnos = [
    (inicio: '09:00', fim: '12:00'),
    (inicio: '13:00', fim: '18:00'),
  ];

  /// Grade de horários: de 30 em 30 minutos dentro de cada turno.
  static const List<String> horariosBase = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
  ];

  /// Até quantos dias à frente o cliente pode agendar, contando hoje: de hoje
  /// até 13 dias depois.
  static const int diasDeAgenda = 14;

  /// A barbearia atende de segunda a sábado; domingo não abre.
  static bool atendeNoDia(DateTime dia) => dia.weekday != DateTime.sunday;

  /// Último dia que aceita reserva, contando a partir de [hoje].
  static DateTime ultimoDiaDaAgenda(DateTime hoje) =>
      DateTime(hoje.year, hoje.month, hoje.day + diasDeAgenda - 1);

  /// Dias oferecidos na agenda: de hoje até [ultimoDiaDaAgenda], sem os
  /// domingos. A tela de horário usa esta mesma lista.
  static List<DateTime> diasDisponiveis([DateTime? hoje]) {
    final h = hoje ?? DateTime.now();
    return [
      for (var i = 0; i < diasDeAgenda; i++)
        DateTime(h.year, h.month, h.day + i),
    ].where(atendeNoDia).toList();
  }

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
      onConfigure: configurar,
    );
    return _db!;
  }

  /// Configuração aplicada a cada abertura do banco (também usada pelos
  /// testes, para que rodem com as mesmas garantias do aparelho).
  static Future<void> configurar(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
  // SCHEMA E MIGRAÇÕES
  // -------------------------------------------------------------------------

  /// Cria todas as tabelas, vazias.
  ///
  /// O administrador e os dados de exemplo nascem depois, na configuração
  /// inicial ([configurarBarbearia]). Público de propósito: os testes de
  /// integração reaproveitam este mesmo método como `onCreate` do banco em
  /// memória.
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
        salario REAL NOT NULL DEFAULT 0,
        ativo INTEGER NOT NULL DEFAULT 1
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
        duracao_minutos INTEGER NOT NULL DEFAULT 30,
        preco REAL NOT NULL DEFAULT 0,
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
        natureza TEXT NOT NULL DEFAULT 'servico',
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

    await _criarIndiceHorario(db);
    await _criarIndicesDeConsulta(db);
    await _criarIndiceEmailBarbeiro(db);
  }

  /// Índices das consultas mais frequentes: grade do barbeiro, histórico do
  /// cliente, pagamento de cada agendamento e extrato de pontos.
  static Future<void> _criarIndicesDeConsulta(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_agendamento_barbeiro_data '
      'ON agendamento (id_barbeiro, data_hora)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_agendamento_cliente '
      'ON agendamento (id_cliente, data_hora)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pagamento_agendamento '
      'ON pagamento (id_agendamento)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_historico_cliente '
      'ON historico_ponto (id_cliente)',
    );
  }

  /// O e-mail de acesso identifica o barbeiro no login, então não pode se
  /// repetir. (Vazios, de cadastros antigos sem acesso, não contam.)
  static Future<void> _criarIndiceEmailBarbeiro(DatabaseExecutor db) =>
      db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_barbeiro_email '
        "ON barbeiro (email) WHERE email != ''",
      );

  /// Última barreira contra horário duplicado: o próprio banco recusa dois
  /// agendamentos ativos do mesmo barbeiro no mesmo horário. (A sobreposição
  /// por duração é conferida em [reservar], dentro da transação.)
  static Future<void> _criarIndiceHorario(DatabaseExecutor db) =>
      db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_agendamento_horario
        ON agendamento (id_barbeiro, data_hora)
        WHERE status != 'cancelado'
      ''');

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
            'senha_hash': hashSenha(senhaBarbeirosDeExemplo),
            'telefone': '(67) 99000-0000',
            'salario': 2500.0,
          },
          where: 'id = ?',
          whereArgs: [b['id']],
        );
      }
    }

    if (versaoAntiga < 3) {
      // Ninguém é promovido nem criado aqui: sem administrador, o app abre
      // na configuração inicial (regra de negócio 15). Antes, a migração
      // promovia a conta demo — ou criava uma conta — com a senha padrão.
      await db.execute(
        'ALTER TABLE cliente ADD COLUMN admin INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (versaoAntiga < 4) {
      // Quem já estava cadastrado continua disponível.
      await db.execute(
        'ALTER TABLE barbeiro ADD COLUMN ativo INTEGER NOT NULL DEFAULT 1',
      );
    }

    if (versaoAntiga < 5) {
      await db.execute(
        "ALTER TABLE pagamento ADD COLUMN natureza TEXT NOT NULL "
        "DEFAULT 'servico'",
      );
      // Até aqui a natureza só podia ser deduzida pelo texto do método.
      await db.rawUpdate(
        "UPDATE pagamento SET natureza = 'multa' WHERE metodo = ?",
        [metodoMulta],
      );
      await db.rawUpdate(
        "UPDATE pagamento SET natureza = 'estorno' WHERE metodo LIKE ?",
        ['$metodoEstorno%'],
      );
      await db.rawUpdate(
        "UPDATE pagamento SET natureza = 'resgate' WHERE metodo = ?",
        [metodoResgate],
      );
      // Estornos antigos passam a sair pela forma do pagamento original.
      await db.execute('''
        UPDATE pagamento SET metodo = COALESCE(
          (SELECT p2.metodo FROM pagamento p2
           WHERE p2.id_agendamento = pagamento.id_agendamento
             AND p2.natureza = 'servico'
           ORDER BY p2.id LIMIT 1),
          metodo)
        WHERE natureza = 'estorno'
      ''');

      await db.execute(
        'ALTER TABLE agendamento ADD COLUMN duracao_minutos INTEGER '
        'NOT NULL DEFAULT $intervaloGrade',
      );
      await db.execute('''
        UPDATE agendamento SET duracao_minutos = COALESCE(
          (SELECT s.duracao_minutos FROM servico s
           WHERE s.id = agendamento.id_servico),
          $intervaloGrade)
      ''');

      // O preço da época não foi guardado; o atual é a melhor aproximação.
      await db.execute(
        'ALTER TABLE agendamento ADD COLUMN preco REAL NOT NULL DEFAULT 0',
      );
      await db.execute('''
        UPDATE agendamento SET preco = COALESCE(
          (SELECT s.preco FROM servico s WHERE s.id = agendamento.id_servico),
          0)
      ''');

      // Bancos antigos podem já ter horários duplicados (o bug que o índice
      // previne). Nesse caso o índice não pode ser criado sem apagar dados;
      // a checagem transacional de [reservar] continua protegendo.
      final duplicados = Sqflite.firstIntValue(
        await db.rawQuery('''
          SELECT COUNT(*) FROM (
            SELECT 1 FROM agendamento WHERE status != 'cancelado'
            GROUP BY id_barbeiro, data_hora HAVING COUNT(*) > 1
          )
        '''),
      );
      if ((duplicados ?? 0) == 0) await _criarIndiceHorario(db);

      await _criarIndicesDeConsulta(db);

      // Mesma cautela com e-mails de barbeiro repetidos (a migração v2 os
      // gerava pelo nome, e dois homônimos colidiriam).
      final emailsRepetidos = Sqflite.firstIntValue(
        await db.rawQuery('''
          SELECT COUNT(*) FROM (
            SELECT 1 FROM barbeiro WHERE email != ''
            GROUP BY email HAVING COUNT(*) > 1
          )
        '''),
      );
      if ((emailsRepetidos ?? 0) == 0) await _criarIndiceEmailBarbeiro(db);
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

  // -------------------------------------------------------------------------
  // CONFIGURAÇÃO INICIAL
  // -------------------------------------------------------------------------

  /// Barbeiros de demonstração, criados quando o dono marca "Começar com
  /// dados de exemplo". A senha de todos é [senhaBarbeirosDeExemplo].
  static const List<Barbeiro> _barbeirosDeExemplo = [
    Barbeiro(
      nome: 'Carlos Eduardo',
      especialidade: 'Especialista em barba',
      avaliacao: 4.9,
      avaliacoes: 128,
      iniciais: 'CE',
      telefone: '(67) 99101-1001',
      email: 'carlos.eduardo@sysbarber.com',
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
      salario: 2650.00,
      // Indisponível para demonstrar a regra 14.
      ativo: false,
    ),
  ];

  /// Serviços de demonstração, criados junto com os barbeiros de exemplo.
  static const List<Servico> _servicosDeExemplo = [
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

  /// E-mails de acesso dos barbeiros de exemplo, para quem configura a
  /// barbearia saber como eles entram.
  static List<String> get emailsBarbeirosDeExemplo =>
      _barbeirosDeExemplo.map((b) => b.email).toList();

  /// A barbearia já foi configurada, isto é, já existe o administrador?
  ///
  /// Enquanto não existe, o app abre na configuração inicial (regra de
  /// negócio 15).
  Future<bool> barbeariaConfigurada() async =>
      _existeAdministrador(await database);

  Future<bool> _existeAdministrador(DatabaseExecutor db) async {
    final linhas = await db.query(
      'cliente',
      columns: ['id'],
      where: 'admin = 1',
      limit: 1,
    );
    return linhas.isNotEmpty;
  }

  /// Configuração inicial da barbearia (regra de negócio 15).
  ///
  /// Cria a conta do administrador — a única, e só enquanto não existe
  /// nenhuma — com os dados escolhidos pelo dono. Com [dadosDeExemplo], cria
  /// também os barbeiros e os serviços de demonstração, o que só é aceito
  /// numa barbearia ainda vazia.
  ///
  /// Os hashes das senhas são calculados antes, em outro isolate. A gravação
  /// acontece numa única transação, que confere tudo de novo: ou a barbearia
  /// fica configurada por inteiro, ou nada muda. Devolve o administrador.
  Future<Cliente> configurarBarbearia({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
    bool dadosDeExemplo = false,
  }) async {
    final erro = Validators.validarCadastro(
      nome: nome,
      email: email,
      telefone: telefone,
      senha: senha,
    );
    if (erro != null) throw RegraNegocioException(erro);

    final emailNormalizado = email.trim().toLowerCase();
    final db = await database;

    // Conferido antes de calcular os hashes, que são caros, e de novo dentro
    // da transação, que é quem garante a regra.
    final antes = await _impedimentoConfiguracao(
      db,
      emailNormalizado,
      dadosDeExemplo,
    );
    if (antes != null) throw RegraNegocioException(antes);

    final senhaHash = await Senhas.gerarHashEmSegundoPlano(senha);
    final hashesBarbeiros = dadosDeExemplo
        ? await Future.wait([
            for (final _ in _barbeirosDeExemplo)
              Senhas.gerarHashEmSegundoPlano(senhaBarbeirosDeExemplo),
          ])
        : const <String>[];

    return db.transaction((txn) async {
      final impedimento = await _impedimentoConfiguracao(
        txn,
        emailNormalizado,
        dadosDeExemplo,
      );
      if (impedimento != null) throw RegraNegocioException(impedimento);

      final admin = Cliente(
        nome: nome.trim(),
        email: emailNormalizado,
        telefone: telefone.trim(),
        senhaHash: senhaHash,
        criadoEm: DateTime.now().toIso8601String(),
        admin: true,
      );
      final id = await txn.insert('cliente', admin.toMap()..remove('id'));
      await txn.insert('fidelidade', {'id_cliente': id, 'pontos': 0});

      if (dadosDeExemplo) {
        for (var i = 0; i < _barbeirosDeExemplo.length; i++) {
          await txn.insert(
            'barbeiro',
            _barbeirosDeExemplo[i]
                .copyWith(senhaHash: hashesBarbeiros[i])
                .toMap()
              ..remove('id'),
          );
        }
        for (final servico in _servicosDeExemplo) {
          await txn.insert('servico', servico.toMap()..remove('id'));
        }
      }
      return admin.copyWith(id: id);
    });
  }

  /// Por que a configuração inicial não pode acontecer, ou `null` se pode.
  Future<String?> _impedimentoConfiguracao(
    DatabaseExecutor db,
    String email,
    bool dadosDeExemplo,
  ) async {
    if (await _existeAdministrador(db)) {
      return 'A barbearia já foi configurada';
    }

    // E-mail é único no sistema (regra de negócio 12), inclusive entre o
    // administrador e os barbeiros que os dados de exemplo vão criar.
    Future<bool> emUso(String tabela) async => (await db.query(
      tabela,
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    )).isNotEmpty;
    if (await emUso('cliente') || await emUso('barbeiro')) {
      return 'Este e-mail já está cadastrado';
    }
    if (dadosDeExemplo && emailsBarbeirosDeExemplo.contains(email)) {
      return 'Este e-mail é de um barbeiro dos dados de exemplo';
    }

    if (dadosDeExemplo) {
      final cadastros =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT (SELECT COUNT(*) FROM barbeiro) + '
              '(SELECT COUNT(*) FROM servico)',
            ),
          ) ??
          0;
      if (cadastros > 0) {
        return 'Os dados de exemplo só podem ser criados numa barbearia vazia';
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // SEGURANÇA
  // -------------------------------------------------------------------------

  /// PBKDF2 com salt individual ([Senhas]). Senhas nunca são gravadas em
  /// texto puro, e a mesma senha gera hashes diferentes em cada conta.
  static String hashSenha(String senha) => Senhas.gerarHash(senha);

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
    // Cliente e fidelidade nascem juntos ou não nascem.
    return db.transaction((txn) async {
      final id = await txn.insert('cliente', dados);
      await txn.insert('fidelidade', {'id_cliente': id, 'pontos': 0});
      return id;
    });
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
  ///
  /// Um hash no formato antigo é regravado no novo assim que a senha confere
  /// — é o único momento em que o app conhece a senha para refazer o hash.
  Future<Cliente?> autenticar(String email, String senha) async {
    final cliente = await buscarClientePorEmail(email);
    if (cliente == null) return null;
    if (!await Senhas.conferirEmSegundoPlano(senha, cliente.senhaHash)) {
      return null;
    }
    if (!Senhas.precisaAtualizar(cliente.senhaHash)) return cliente;

    final novo = await Senhas.gerarHashEmSegundoPlano(senha);
    final db = await database;
    await db.update(
      'cliente',
      {'senha_hash': novo},
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
    return cliente.copyWith(senhaHash: novo);
  }

  /// Atualiza só os dados de contato do cliente.
  ///
  /// E-mail, senha e marca de administrador ficam de fora de propósito: o
  /// antigo `atualizarCliente` gravava o objeto inteiro e podia sobrescrever
  /// o hash da senha ou o privilégio de admin com um valor desatualizado.
  Future<int> atualizarContatoCliente(
    int id, {
    required String nome,
    required String telefone,
  }) async {
    final db = await database;
    return db.update(
      'cliente',
      {'nome': nome.trim(), 'telefone': telefone.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Troca a senha do cliente, exigindo a senha atual.
  Future<void> alterarSenhaCliente(
    int id, {
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final cliente = await buscarClientePorId(id);
    if (cliente == null) {
      throw const RegraNegocioException('Conta não encontrada');
    }
    if (!await Senhas.conferirEmSegundoPlano(senhaAtual, cliente.senhaHash)) {
      throw const RegraNegocioException('Senha atual incorreta');
    }
    if (!Validators.senhaValida(novaSenha)) {
      throw const RegraNegocioException(
        'A nova senha deve ter no mínimo 6 caracteres',
      );
    }
    final hash = await Senhas.gerarHashEmSegundoPlano(novaSenha);
    final db = await database;
    await db.update(
      'cliente',
      {'senha_hash': hash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------------------------------
  // BARBEIROS E SERVIÇOS
  // -------------------------------------------------------------------------

  Future<List<Barbeiro>> listarBarbeiros() async {
    final db = await database;
    final linhas = await db.query('barbeiro', orderBy: 'id');
    return linhas.map(Barbeiro.fromMap).toList();
  }

  /// Somente os profissionais disponíveis para novos agendamentos.
  Future<List<Barbeiro>> listarBarbeirosAtivos() async {
    final db = await database;
    final linhas = await db.query(
      'barbeiro',
      where: 'ativo = 1',
      orderBy: 'id',
    );
    return linhas.map(Barbeiro.fromMap).toList();
  }

  /// Liga ou desliga o barbeiro para novos agendamentos.
  ///
  /// Não mexe nos atendimentos já marcados: quem ficou indisponível ainda
  /// precisa fechar a agenda que assumiu.
  Future<int> definirBarbeiroAtivo(int id, bool ativo) async {
    final db = await database;
    return db.update(
      'barbeiro',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Barbeiro?> buscarBarbeiroPorId(int id) async {
    final db = await database;
    final linhas = await db.query(
      'barbeiro',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Barbeiro.fromMap(linhas.first);
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

  /// Autentica um profissional pelo e-mail e senha de acesso, atualizando
  /// o hash antigo como em [autenticar].
  Future<Barbeiro?> autenticarBarbeiro(String email, String senha) async {
    final barbeiro = await buscarBarbeiroPorEmail(email);
    if (barbeiro == null) return null;
    if (barbeiro.senhaHash.isEmpty) return null;
    if (!await Senhas.conferirEmSegundoPlano(senha, barbeiro.senhaHash)) {
      return null;
    }
    if (!Senhas.precisaAtualizar(barbeiro.senhaHash)) return barbeiro;

    final novo = await Senhas.gerarHashEmSegundoPlano(senha);
    final db = await database;
    await db.update(
      'barbeiro',
      {'senha_hash': novo},
      where: 'id = ?',
      whereArgs: [barbeiro.id],
    );
    return barbeiro.copyWith(senhaHash: novo);
  }

  Future<int> cadastrarBarbeiro(Barbeiro b) async {
    final db = await database;
    final dados = b.toMap()
      ..remove('id')
      ..['email'] = b.email.trim().toLowerCase();
    return db.insert('barbeiro', dados);
  }

  /// Atualiza o cadastro do profissional.
  ///
  /// A disponibilidade (`ativo`) fica de fora de propósito: ela só muda por
  /// [definirBarbeiroAtivo]. Antes, salvar o formulário de um barbeiro
  /// indisponível o reativava sem ninguém pedir.
  Future<int> atualizarBarbeiro(Barbeiro b) async {
    final db = await database;
    final dados = b.toMap()
      ..remove('ativo')
      ..['email'] = b.email.trim().toLowerCase();
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

  /// Grava um agendamento. Duração e preço não informados são copiados do
  /// serviço naquele momento.
  Future<int> criarAgendamento(Agendamento a) async {
    final db = await database;
    final servico = await _buscarServico(db, a.idServico);
    final dados = a.toMap()..remove('id');
    dados['duracao_minutos'] ??= servico?.duracaoMinutos ?? intervaloGrade;
    dados['preco'] ??= servico?.preco ?? 0;
    return db.insert('agendamento', dados);
  }

  Future<Servico?> _buscarServico(DatabaseExecutor db, int idServico) async {
    final linhas = await db.query(
      'servico',
      where: 'id = ?',
      whereArgs: [idServico],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Servico.fromMap(linhas.first);
  }

  /// Colunas do pagamento principal e do total estornado, comuns às duas
  /// listagens: a tela recebe tudo numa consulta só, em vez de buscar o
  /// pagamento de cada agendamento separadamente.
  static const String _colunasPagamento = '''
        (SELECT COALESCE(-SUM(e.valor), 0) FROM pagamento e
         WHERE e.id_agendamento = a.id AND e.natureza = 'estorno')
                          AS valor_estornado,
        p.id              AS p_id,
        p.valor           AS p_valor,
        p.metodo          AS p_metodo,
        p.status          AS p_status,
        p.criado_em       AS p_criado_em,
        p.tipo            AS p_tipo,
        p.cartao_final    AS p_cartao_final,
        p.natureza        AS p_natureza''';

  /// O pagamento "do" agendamento é o último lançamento que não é estorno —
  /// o do serviço, o do resgate ou a multa. O estorno aparece à parte, em
  /// `valor_estornado`.
  static const String _juncaoPagamento = '''
      LEFT JOIN pagamento p ON p.id = (
        SELECT p2.id FROM pagamento p2
        WHERE p2.id_agendamento = a.id AND p2.natureza != 'estorno'
        ORDER BY p2.id DESC LIMIT 1
      )''';

  static Agendamento _agendamentoDaLinha(
    Map<String, Object?> linha, {
    Barbeiro? barbeiro,
    Cliente? cliente,
  }) {
    final servico = Servico.fromMap({
      'id': linha['s_id'],
      'nome': linha['s_nome'],
      'descricao': linha['s_descricao'],
      'preco': linha['s_preco'],
      'duracao_minutos': linha['s_duracao_minutos'],
      'icone': linha['s_icone'],
    });
    final pagamento = linha['p_id'] == null
        ? null
        : Pagamento.fromMap({
            'id': linha['p_id'],
            'id_agendamento': linha['id'],
            'valor': linha['p_valor'],
            'metodo': linha['p_metodo'],
            'status': linha['p_status'],
            'criado_em': linha['p_criado_em'],
            'tipo': linha['p_tipo'],
            'cartao_final': linha['p_cartao_final'],
            'natureza': linha['p_natureza'],
          });
    return Agendamento.fromMap(linha).copyWith(
      barbeiro: barbeiro,
      cliente: cliente,
      servico: servico,
      pagamento: pagamento,
      valorEstornado: (linha['valor_estornado'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Lista os agendamentos do cliente já com barbeiro, serviço e pagamento
  /// carregados — evita uma consulta extra por item na tela.
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
        a.duracao_minutos AS duracao_minutos,
        a.preco         AS preco,
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
        s.icone         AS s_icone,
        $_colunasPagamento
      FROM agendamento a
      INNER JOIN barbeiro b ON b.id = a.id_barbeiro
      INNER JOIN servico  s ON s.id = a.id_servico
      $_juncaoPagamento
      WHERE a.id_cliente = ?
      ORDER BY a.data_hora DESC
      ''',
      [idCliente],
    );

    return linhas
        .map(
          (linha) =>
              _agendamentoDaLinha(linha, barbeiro: _barbeiroDaLinha(linha)),
        )
        .toList();
  }

  /// Barbeiro trazido pelas listagens (colunas `b_*`).
  static Barbeiro _barbeiroDaLinha(Map<String, Object?> linha) =>
      Barbeiro.fromMap({
        'id': linha['b_id'],
        'nome': linha['b_nome'],
        'especialidade': linha['b_especialidade'],
        'avaliacao': linha['b_avaliacao'],
        'avaliacoes': linha['b_avaliacoes'],
        'iniciais': linha['b_iniciais'],
      });

  /// Cliente trazido pelas listagens (colunas `c_*`), só com os dados de
  /// contato: o hash da senha não sai do banco.
  static Cliente _clienteDaLinha(Map<String, Object?> linha) => Cliente.fromMap({
    'id': linha['c_id'],
    'nome': linha['c_nome'],
    'email': linha['c_email'],
    'telefone': linha['c_telefone'],
    'senha_hash': '',
    'criado_em': linha['c_criado_em'],
  });

  /// Agenda de um profissional, com o cliente, o serviço e o pagamento já
  /// carregados.
  ///
  /// É o espelho de [listarAgendamentosCliente]: lá o cliente vê quem vai
  /// atendê-lo; aqui o barbeiro vê quem vai atender. Do cliente vêm só os
  /// dados de contato — o hash da senha não sai do banco.
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
        a.duracao_minutos AS duracao_minutos,
        a.preco         AS preco,
        c.id            AS c_id,
        c.nome          AS c_nome,
        c.email         AS c_email,
        c.telefone      AS c_telefone,
        c.criado_em     AS c_criado_em,
        s.id            AS s_id,
        s.nome          AS s_nome,
        s.descricao     AS s_descricao,
        s.preco         AS s_preco,
        s.duracao_minutos AS s_duracao_minutos,
        s.icone         AS s_icone,
        $_colunasPagamento
      FROM agendamento a
      INNER JOIN cliente c ON c.id = a.id_cliente
      INNER JOIN servico s ON s.id = a.id_servico
      $_juncaoPagamento
      WHERE a.id_barbeiro = ?
      ORDER BY a.data_hora DESC
      ''',
      [idBarbeiro],
    );

    return linhas
        .map(
          (linha) =>
              _agendamentoDaLinha(linha, cliente: _clienteDaLinha(linha)),
        )
        .toList();
  }

  /// Agenda geral do administrador: todos os agendamentos, de todos os
  /// barbeiros, com barbeiro, cliente, serviço e pagamento numa consulta só.
  /// Como na agenda do barbeiro, do cliente vêm só os dados de contato.
  Future<List<Agendamento>> listarTodosAgendamentos() async {
    final db = await database;
    final linhas = await db.rawQuery('''
      SELECT
        a.id            AS id,
        a.id_cliente    AS id_cliente,
        a.id_barbeiro   AS id_barbeiro,
        a.id_servico    AS id_servico,
        a.data_hora     AS data_hora,
        a.status        AS status,
        a.duracao_minutos AS duracao_minutos,
        a.preco         AS preco,
        b.id            AS b_id,
        b.nome          AS b_nome,
        b.especialidade AS b_especialidade,
        b.avaliacao     AS b_avaliacao,
        b.avaliacoes    AS b_avaliacoes,
        b.iniciais      AS b_iniciais,
        c.id            AS c_id,
        c.nome          AS c_nome,
        c.email         AS c_email,
        c.telefone      AS c_telefone,
        c.criado_em     AS c_criado_em,
        s.id            AS s_id,
        s.nome          AS s_nome,
        s.descricao     AS s_descricao,
        s.preco         AS s_preco,
        s.duracao_minutos AS s_duracao_minutos,
        s.icone         AS s_icone,
        $_colunasPagamento
      FROM agendamento a
      INNER JOIN barbeiro b ON b.id = a.id_barbeiro
      INNER JOIN cliente  c ON c.id = a.id_cliente
      INNER JOIN servico  s ON s.id = a.id_servico
      $_juncaoPagamento
      ORDER BY a.data_hora DESC
    ''');

    return linhas
        .map(
          (linha) => _agendamentoDaLinha(
            linha,
            barbeiro: _barbeiroDaLinha(linha),
            cliente: _clienteDaLinha(linha),
          ),
        )
        .toList();
  }

  Future<int> atualizarStatusAgendamento(
    int id,
    StatusAgendamento status,
  ) async =>
      _atualizarStatusAgendamento(await database, id, status);

  Future<int> _atualizarStatusAgendamento(
    DatabaseExecutor db,
    int id,
    StatusAgendamento status,
  ) {
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
  /// Um horário só é oferecido se o serviço inteiro ([duracaoMinutos]) cabe
  /// no turno e sem invadir outro atendimento do barbeiro — e, com
  /// [idCliente], sem conflitar com outro horário do próprio cliente.
  /// Agendamentos cancelados não bloqueiam nada (regra de negócio 2). Domingo,
  /// dias além da janela de agendamento e profissional indisponível não
  /// oferecem horário nenhum.
  Future<List<String>> horariosDisponiveis(
    int idBarbeiro,
    DateTime data, {
    int? duracaoMinutos,
    int? idCliente,
    DateTime? agora,
  }) async => _horariosLivres(
    await database,
    idBarbeiro,
    data,
    duracaoMinutos: duracaoMinutos,
    idCliente: idCliente,
    agora: agora,
  );

  Future<List<String>> _horariosLivres(
    DatabaseExecutor db,
    int idBarbeiro,
    DateTime data, {
    DateTime? agora,
    int? duracaoMinutos,
    int? idCliente,
  }) async {
    final barbeiro = await db.query(
      'barbeiro',
      columns: ['ativo'],
      where: 'id = ?',
      whereArgs: [idBarbeiro],
      limit: 1,
    );
    if (barbeiro.isEmpty || (barbeiro.first['ativo'] as num).toInt() != 1) {
      return [];
    }

    final referencia = agora ?? DateTime.now();
    if (!atendeNoDia(data) || _depoisDaJanela(data, referencia)) return [];

    final doBarbeiro = await _ocupacoes(db, data, idBarbeiro: idBarbeiro);
    final doCliente = idCliente == null
        ? const <_Intervalo>[]
        : await _ocupacoes(db, data, idCliente: idCliente);
    final duracao = Duration(minutes: duracaoMinutos ?? intervaloGrade);

    return horariosBase.where((h) {
      final inicio = _naGrade(data, h);
      // Horários que já passaram não podem ser oferecidos — sem isto o app
      // aceita agendar para as 09:00 quando já são 15:00.
      if (!inicio.isAfter(referencia)) return false;
      final fim = inicio.add(duracao);
      if (_passaDoTurno(inicio, fim)) return false;
      return !_sobrepoe(inicio, fim, doBarbeiro) &&
          !_sobrepoe(inicio, fim, doCliente);
    }).toList();
  }

  /// Intervalos já ocupados no dia, do barbeiro ou do cliente.
  Future<List<_Intervalo>> _ocupacoes(
    DatabaseExecutor db,
    DateTime dia, {
    int? idBarbeiro,
    int? idCliente,
  }) async {
    final coluna = idBarbeiro != null ? 'id_barbeiro' : 'id_cliente';
    final linhas = await db.query(
      'agendamento',
      columns: ['data_hora', 'duracao_minutos'],
      where: '$coluna = ? AND status != ? AND data_hora LIKE ?',
      whereArgs: [
        idBarbeiro ?? idCliente,
        StatusAgendamento.cancelado.dbValue,
        '${_formatarDia(dia)}%',
      ],
    );
    return linhas.map((l) {
      final inicio = DateTime.parse(l['data_hora'] as String);
      final minutos =
          (l['duracao_minutos'] as num?)?.toInt() ?? intervaloGrade;
      return (inicio: inicio, fim: inicio.add(Duration(minutes: minutos)));
    }).toList();
  }

  /// O intervalo `[inicio, fim)` cruza algum dos ocupados?
  static bool _sobrepoe(
    DateTime inicio,
    DateTime fim,
    List<_Intervalo> ocupados,
  ) => ocupados.any((o) => inicio.isBefore(o.fim) && o.inicio.isBefore(fim));

  static DateTime _naGrade(DateTime dia, String hora) {
    final partes = hora.split(':');
    return DateTime(
      dia.year,
      dia.month,
      dia.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );
  }

  /// Fim do turno em que [inicio] cai, ou `null` se estiver fora dos turnos.
  static DateTime? _fimDoTurno(DateTime inicio) {
    for (final t in turnos) {
      final abre = _naGrade(inicio, t.inicio);
      final fecha = _naGrade(inicio, t.fim);
      if (!inicio.isBefore(abre) && inicio.isBefore(fecha)) return fecha;
    }
    return null;
  }

  /// O atendimento de [inicio] a [fim] passa do fim do turno em que começa?
  static bool _passaDoTurno(DateTime inicio, DateTime fim) {
    final fecha = _fimDoTurno(inicio);
    return fecha == null || fim.isAfter(fecha);
  }

  /// [dia] fica depois do último dia da janela de agendamento?
  static bool _depoisDaJanela(DateTime dia, DateTime referencia) =>
      DateTime(dia.year, dia.month, dia.day)
          .isAfter(ultimoDiaDaAgenda(referencia));

  /// Confere, sem gravar nada, se o horário ainda pode ser reservado.
  ///
  /// Devolve a mensagem do impedimento ou `null` quando está tudo certo. A
  /// tela usa isto para avisar cedo; [reservar] repete a checagem dentro da
  /// transação, que é quem de fato garante a regra.
  Future<String?> verificarReserva({
    required int idBarbeiro,
    required DateTime dataHora,
    int? idServico,
    int? idCliente,
    DateTime? agora,
  }) async {
    final db = await database;
    return _impedimentoReserva(
      db,
      idBarbeiro: idBarbeiro,
      dataHora: dataHora,
      duracaoMinutos: idServico == null
          ? null
          : (await _buscarServico(db, idServico))?.duracaoMinutos,
      idCliente: idCliente,
      agora: agora,
    );
  }

  Future<String?> _impedimentoReserva(
    DatabaseExecutor db, {
    required int idBarbeiro,
    required DateTime dataHora,
    int? duracaoMinutos,
    int? idCliente,
    DateTime? agora,
  }) async {
    final barbeiro = await db.query(
      'barbeiro',
      columns: ['nome', 'ativo'],
      where: 'id = ?',
      whereArgs: [idBarbeiro],
      limit: 1,
    );
    if (barbeiro.isEmpty) return 'Profissional não encontrado';
    if ((barbeiro.first['ativo'] as num).toInt() != 1) {
      return '${barbeiro.first['nome']} não está mais disponível para '
          'agendamentos';
    }

    final referencia = agora ?? DateTime.now();
    if (!dataHora.isAfter(referencia)) return 'Este horário já passou';
    if (!atendeNoDia(dataHora)) return 'A barbearia não abre aos domingos';
    if (_depoisDaJanela(dataHora, referencia)) {
      return 'Só é possível agendar até $diasDeAgenda dias à frente';
    }

    final hora =
        '${_doisDigitos(dataHora.hour)}:${_doisDigitos(dataHora.minute)}';
    if (!horariosBase.contains(hora)) {
      return 'O horário $hora não faz parte da agenda';
    }

    final fim = dataHora.add(
      Duration(minutes: duracaoMinutos ?? intervaloGrade),
    );
    if (_passaDoTurno(dataHora, fim)) {
      return 'Começando às $hora, o serviço passaria do fim do turno';
    }
    final doBarbeiro = await _ocupacoes(db, dataHora, idBarbeiro: idBarbeiro);
    if (_sobrepoe(dataHora, fim, doBarbeiro)) {
      return 'O horário $hora não está mais livre';
    }
    if (idCliente != null) {
      final doCliente = await _ocupacoes(db, dataHora, idCliente: idCliente);
      if (_sobrepoe(dataHora, fim, doCliente)) {
        return 'Você já tem outro atendimento nesse horário';
      }
    }
    return null;
  }

  /// Fecha o agendamento **junto** com o pagamento, numa única transação.
  ///
  /// Antes o agendamento era gravado na tela de confirmação e o pagamento só
  /// depois: quem voltava ou fechava o app deixava um horário ocupado sem
  /// pagamento. Agora ou os dois registros nascem, ou nenhum nasce.
  ///
  /// O preço vem do banco (e não da tela), a disponibilidade é conferida de
  /// novo aqui dentro e, no resgate, o saldo também. Qualquer impedimento
  /// lança [RegraNegocioException] sem deixar rastro no banco.
  Future<ResultadoReserva> reservar({
    required int idCliente,
    required int idBarbeiro,
    required int idServico,
    required DateTime dataHora,
    required ModoReserva modo,
    String? metodo,
    String? cartaoFinal,
    DateTime? agora,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final linhas = await txn.query(
        'servico',
        where: 'id = ?',
        whereArgs: [idServico],
        limit: 1,
      );
      if (linhas.isEmpty) {
        throw const RegraNegocioException('Serviço não encontrado');
      }
      final servico = Servico.fromMap(linhas.first);

      final impedimento = await _impedimentoReserva(
        txn,
        idBarbeiro: idBarbeiro,
        dataHora: dataHora,
        duracaoMinutos: servico.duracaoMinutos,
        idCliente: idCliente,
        agora: agora,
      );
      if (impedimento != null) throw RegraNegocioException(impedimento);

      if (modo == ModoReserva.resgatarPontos &&
          await _obterPontos(txn, idCliente) < pontosParaPremio) {
        throw const RegraNegocioException(
          'Saldo de pontos insuficiente para o resgate',
        );
      }

      final idAgendamento = await txn.insert(
        'agendamento',
        Agendamento(
          idCliente: idCliente,
          idBarbeiro: idBarbeiro,
          idServico: idServico,
          dataHora: dataHora.toIso8601String(),
          duracaoMinutos: servico.duracaoMinutos,
          preco: servico.preco,
        ).toMap()
          ..remove('id'),
      );

      final criadoEm = DateTime.now().toIso8601String();
      late final int idPagamento;
      var creditados = 0;
      var debitados = 0;

      switch (modo) {
        case ModoReserva.resgatarPontos:
          idPagamento = await _registrarResgate(
            txn,
            idCliente: idCliente,
            idAgendamento: idAgendamento,
            nomeServico: servico.nome,
          );
          debitados = pontosParaPremio;
        case ModoReserva.pagarAgora:
          idPagamento = await _criarPagamento(
            txn,
            Pagamento(
              idAgendamento: idAgendamento,
              valor: servico.preco,
              metodo: metodo ?? MetodoPagamento.pix.label,
              status: Pagamento.statusConfirmado,
              criadoEm: criadoEm,
              tipo: TipoPagamento.antecipado.dbValue,
              cartaoFinal: cartaoFinal,
            ),
          );
          creditados = servico.preco.round();
          await _movimentarPontos(
            txn,
            idCliente,
            creditados,
            'Pagamento — ${servico.nome}',
          );
        case ModoReserva.pagarNaBarbearia:
          idPagamento = await _criarPagamento(
            txn,
            Pagamento(
              idAgendamento: idAgendamento,
              valor: servico.preco,
              metodo: 'A combinar',
              status: Pagamento.statusPendente,
              criadoEm: criadoEm,
              tipo: TipoPagamento.naHora.dbValue,
            ),
          );
      }

      return ResultadoReserva(
        idAgendamento: idAgendamento,
        idPagamento: idPagamento,
        valor: modo == ModoReserva.resgatarPontos ? 0 : servico.preco,
        pontosCreditados: creditados,
        pontosDebitados: debitados,
        saldoPontos: await _obterPontos(txn, idCliente),
      );
    });
  }

  // -------------------------------------------------------------------------
  // PAGAMENTOS E FIDELIDADE
  // -------------------------------------------------------------------------

  Future<int> criarPagamento(Pagamento p) async {
    final db = await database;
    return db.transaction((txn) => _criarPagamento(txn, p));
  }

  /// Grava um lançamento. Um agendamento tem no máximo um pagamento de
  /// serviço (ou resgate) valendo: um segundo seria cobrança em dobro.
  Future<int> _criarPagamento(DatabaseExecutor db, Pagamento p) async {
    if (p.natureza == NaturezaPagamento.servico ||
        p.natureza == NaturezaPagamento.resgate) {
      final existente = await db.query(
        'pagamento',
        columns: ['id'],
        where:
            "id_agendamento = ? AND natureza IN ('servico', 'resgate') "
            'AND status != ?',
        whereArgs: [p.idAgendamento, Pagamento.statusCancelado],
        limit: 1,
      );
      if (existente.isNotEmpty) {
        throw const RegraNegocioException(
          'Este agendamento já tem um pagamento registrado',
        );
      }
    }
    return db.insert('pagamento', p.toMap()..remove('id'));
  }

  Future<Pagamento?> buscarPagamentoDoAgendamento(int idAgendamento) async =>
      _buscarPagamentoDoAgendamento(await database, idAgendamento);

  /// O pagamento do agendamento: serviço, resgate ou multa — nunca o
  /// estorno, que é um lançamento complementar.
  Future<Pagamento?> _buscarPagamentoDoAgendamento(
    DatabaseExecutor db,
    int idAgendamento,
  ) async {
    final linhas = await db.query(
      'pagamento',
      where: 'id_agendamento = ? AND natureza != ?',
      whereArgs: [idAgendamento, NaturezaPagamento.estorno.dbValue],
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

  /// O cancelamento ainda está dentro do prazo sem multa?
  static bool dentroDoPrazo(DateTime dataHora, {DateTime? agora}) =>
      dataHora.difference(agora ?? DateTime.now()) >= prazoCancelamento;

  /// Cancela o agendamento aplicando a política de multa
  /// (regra de negócio 7).
  ///
  /// Fora do prazo, a barbearia retém [percentualMulta] do valor do serviço.
  /// O acerto financeiro depende de o cliente já ter pago:
  ///
  /// - **pago antecipado**: lança um estorno com valor negativo. A soma dos
  ///   lançamentos deixa no faturamento apenas o que foi efetivamente retido,
  ///   preservando o histórico em vez de apagar o pagamento original.
  /// - **pendente**: o pagamento é cancelado quando não há multa, ou passa a
  ///   valer somente a multa, que segue devida.
  ///
  /// Os pontos creditados pelo pagamento são revertidos, já que o serviço não
  /// foi prestado. Num serviço obtido por resgate, os pontos fazem o papel do
  /// pagamento: voltam no prazo e ficam retidos fora dele, sem multa em
  /// dinheiro. [porBarbeiro] isenta a multa: quando a falta é da barbearia,
  /// não faz sentido penalizar o cliente, que recebe tudo de volta.
  ///
  /// Tudo acontece numa única transação: ou o cancelamento inteiro (status,
  /// estorno, multa e pontos) é gravado, ou nada é.
  ///
  /// Só um agendamento em aberto pode ser cancelado (cancelar um atendimento
  /// já concluído estornaria um serviço prestado), e só antes do horário
  /// marcado ([Agendamento.podeCancelar]): depois dele, o desfecho é concluir
  /// ou registrar a falta.
  Future<ResultadoCancelamento> cancelarAgendamento(
    int idAgendamento, {
    DateTime? agora,
    bool porBarbeiro = false,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final a = await _buscarAgendamento(txn, idAgendamento);
      if (a != null && a.emAberto && !a.podeCancelar(agora ?? DateTime.now())) {
        throw const RegraNegocioException(
          'O horário deste atendimento já chegou e ele não pode mais ser '
          'cancelado',
        );
      }
      return _encerrarSemAtendimento(
        txn,
        idAgendamento,
        novoStatus: StatusAgendamento.cancelado,
        agora: agora,
        porBarbeiro: porBarbeiro,
      );
    });
  }

  /// Registra que o cliente não compareceu.
  ///
  /// Só é aceito depois do horário marcado e segue a política de
  /// cancelamento fora do prazo: a multa é cobrada (ou retida, se já pagou) e
  /// os pontos do serviço não prestado são revertidos.
  Future<ResultadoCancelamento> registrarFalta(
    int idAgendamento, {
    DateTime? agora,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final a = await _buscarAgendamento(txn, idAgendamento);
      if (a == null) {
        throw const RegraNegocioException('Agendamento não encontrado');
      }
      if (!a.podeRegistrarFalta(agora ?? DateTime.now())) {
        throw RegraNegocioException(
          a.emAberto
              ? 'A falta só pode ser registrada depois do horário marcado'
              : 'Este atendimento já foi encerrado',
        );
      }
      return _encerrarSemAtendimento(
        txn,
        idAgendamento,
        novoStatus: StatusAgendamento.faltou,
        agora: agora,
      );
    });
  }

  Future<Agendamento?> _buscarAgendamento(DatabaseExecutor db, int id) async {
    final linhas = await db.query(
      'agendamento',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (linhas.isEmpty) return null;
    return Agendamento.fromMap(linhas.first);
  }

  /// Encerra um atendimento que não aconteceu (cancelamento ou falta) e faz
  /// o acerto financeiro descrito em [cancelarAgendamento].
  Future<ResultadoCancelamento> _encerrarSemAtendimento(
    DatabaseExecutor txn,
    int idAgendamento, {
    required StatusAgendamento novoStatus,
    DateTime? agora,
    bool porBarbeiro = false,
  }) async {
    final linhas = await txn.rawQuery(
      '''
      SELECT a.id_cliente AS id_cliente, a.data_hora AS data_hora,
             a.status AS status, a.preco AS preco, s.nome AS nome
      FROM agendamento a
      INNER JOIN servico s ON s.id = a.id_servico
      WHERE a.id = ?
      ''',
      [idAgendamento],
    );
    if (linhas.isEmpty) return const ResultadoCancelamento(comMulta: false);

    final status = StatusAgendamentoX.fromDb(
      linhas.first['status'] as String,
    );
    if (status != StatusAgendamento.confirmado) {
      throw const RegraNegocioException(
        'Este agendamento já foi encerrado e não pode ser cancelado',
      );
    }
    final motivo =
        novoStatus == StatusAgendamento.faltou ? 'falta' : 'cancelamento';

    final idCliente = (linhas.first['id_cliente'] as num).toInt();
    final dataHora = DateTime.parse(linhas.first['data_hora'] as String);
    final preco = (linhas.first['preco'] as num).toDouble();
    final nomeServico = linhas.first['nome'] as String;

    final noPrazo = porBarbeiro || dentroDoPrazo(dataHora, agora: agora);
    final multa = noPrazo ? 0.0 : _emCentavos(preco * percentualMulta);

    await _atualizarStatusAgendamento(txn, idAgendamento, novoStatus);

    final pagamento = await _buscarPagamentoDoAgendamento(
      txn,
      idAgendamento,
    );
    if (pagamento == null) {
      // Sem pagamento registrado, a multa nasce como pendência.
      if (multa > 0) {
        await _criarPagamento(
          txn,
          Pagamento(
            idAgendamento: idAgendamento,
            valor: multa,
            metodo: metodoMulta,
            status: Pagamento.statusPendente,
            criadoEm: DateTime.now().toIso8601String(),
            tipo: TipoPagamento.naHora.dbValue,
            natureza: NaturezaPagamento.multa,
          ),
        );
      }
      return ResultadoCancelamento(
        comMulta: multa > 0,
        multa: multa,
        multaAPagar: multa,
      );
    }

    // Serviço obtido com pontos: os pontos fazem o papel do pagamento. No
    // prazo (ou se a barbearia cancelar) eles voltam; fora do prazo e na
    // falta ficam retidos, sem multa em dinheiro.
    if (pagamento.natureza == NaturezaPagamento.resgate) {
      if (!noPrazo) {
        return const ResultadoCancelamento(
          comMulta: false,
          pontosRetidos: pontosParaPremio,
        );
      }
      await txn.update(
        'pagamento',
        {'status': Pagamento.statusCancelado},
        where: 'id = ?',
        whereArgs: [pagamento.id],
      );
      await _movimentarPontos(
        txn,
        idCliente,
        pontosParaPremio,
        'Devolução por $motivo — $nomeServico',
      );
      return const ResultadoCancelamento(
        comMulta: false,
        pontosAjustados: pontosParaPremio,
      );
    }

    if (pagamento.pendente) {
      if (multa > 0) {
        // O que era cobrança do serviço passa a ser cobrança da multa.
        await txn.update(
          'pagamento',
          {
            'valor': multa,
            'metodo': metodoMulta,
            'natureza': NaturezaPagamento.multa.dbValue,
          },
          where: 'id = ?',
          whereArgs: [pagamento.id],
        );
      } else {
        await txn.update(
          'pagamento',
          {'status': Pagamento.statusCancelado},
          where: 'id = ?',
          whereArgs: [pagamento.id],
        );
      }
      return ResultadoCancelamento(
        comMulta: multa > 0,
        multa: multa,
        multaAPagar: multa,
      );
    }

    // Pagamento já confirmado: devolve o que não for retido como multa.
    final estorno = _emCentavos(pagamento.valor - multa);
    if (estorno > 0) {
      await _criarPagamento(
        txn,
        Pagamento(
          idAgendamento: idAgendamento,
          valor: -estorno,
          // Devolve pela mesma forma em que o cliente pagou: assim o
          // relatório por forma de pagamento mostra o valor líquido.
          metodo: pagamento.metodo,
          status: Pagamento.statusConfirmado,
          criadoEm: DateTime.now().toIso8601String(),
          tipo: pagamento.tipo,
          natureza: NaturezaPagamento.estorno,
        ),
      );
    }

    // O serviço não foi prestado, então os pontos dele não se sustentam — e
    // são revertidos por inteiro, mesmo que o saldo fique negativo. Limitar
    // ao saldo abria uma brecha: pagar, usar os pontos num prêmio e cancelar
    // o serviço pago devolvia o dinheiro e deixava o prêmio de graça.
    final aReverter = pagamento.valor.round();
    if (aReverter > 0) {
      await _movimentarPontos(
        txn,
        idCliente,
        -aReverter,
        'Estorno por $motivo — $nomeServico',
      );
    }

    return ResultadoCancelamento(
      comMulta: multa > 0,
      multa: multa,
      estorno: estorno,
      pontosAjustados: -aReverter,
    );
  }

  /// Marca o atendimento como concluído.
  ///
  /// Sem isto o status `finalizado` nunca seria atribuído e o indicador de
  /// atendimentos concluídos dos relatórios ficaria sempre em zero. Só vale
  /// para atendimento em aberto e a partir do dia marcado
  /// ([Agendamento.podeFinalizar]).
  Future<int> finalizarAgendamento(int id, {DateTime? agora}) async {
    final db = await database;
    return db.transaction((txn) async {
      final a = await _buscarAgendamento(txn, id);
      if (a == null) {
        throw const RegraNegocioException('Agendamento não encontrado');
      }
      if (!a.emAberto) {
        throw const RegraNegocioException('Este atendimento já foi encerrado');
      }
      if (!a.podeFinalizar(agora ?? DateTime.now())) {
        throw const RegraNegocioException(
          'O atendimento só pode ser concluído a partir do dia marcado',
        );
      }
      return _atualizarStatusAgendamento(
        txn,
        id,
        StatusAgendamento.finalizado,
      );
    });
  }

  /// Efetiva um pagamento **pendente** e só então credita os pontos.
  ///
  /// Regra de negócio 5: fidelidade acompanha dinheiro que entrou. Um
  /// pagamento marcado para "pagar na barbearia" não pontua enquanto não for
  /// quitado. A operação é idempotente — confirmar duas vezes não duplica os
  /// pontos — e atômica: a leitura do status e o crédito acontecem na mesma
  /// transação, então duas confirmações simultâneas não passam juntas.
  ///
  /// Pagamentos cancelados não podem ser recebidos, e a quitação de uma
  /// multa é receita mas não gera pontos: pontos premiam serviço prestado.
  Future<bool> confirmarPagamento(int idPagamento, {String? metodo}) async {
    final db = await database;
    return db.transaction((txn) async {
      final linhas = await txn.query(
        'pagamento',
        where: 'id = ?',
        whereArgs: [idPagamento],
        limit: 1,
      );
      if (linhas.isEmpty) return false;

      final pagamento = Pagamento.fromMap(linhas.first);
      if (!pagamento.pendente) return false;

      final agendamentos = await txn.query(
        'agendamento',
        columns: ['id_cliente'],
        where: 'id = ?',
        whereArgs: [pagamento.idAgendamento],
        limit: 1,
      );
      if (agendamentos.isEmpty) return false;
      final idCliente = (agendamentos.first['id_cliente'] as num).toInt();

      // O método só é conhecido no balcão: até aqui o registro fica como
      // 'A combinar', o que sujaria o relatório por forma de pagamento.
      await txn.update(
        'pagamento',
        {
          'status': Pagamento.statusConfirmado,
          if (metodo != null) 'metodo': metodo,
        },
        where: 'id = ?',
        whereArgs: [idPagamento],
      );

      if (pagamento.natureza != NaturezaPagamento.servico) return true;

      final servico = await txn.rawQuery(
        '''
        SELECT s.nome AS nome
        FROM agendamento a
        INNER JOIN servico s ON s.id = a.id_servico
        WHERE a.id = ?
        ''',
        [pagamento.idAgendamento],
      );
      final nomeServico =
          servico.isEmpty ? 'Serviço' : servico.first['nome'] as String;

      await _movimentarPontos(
        txn,
        idCliente,
        pagamento.valor.round(),
        'Pagamento — $nomeServico',
      );
      return true;
    });
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
  ///
  /// Com [inicio] e [fim] (fim exclusivo), os valores ficam restritos ao
  /// período: pagamentos pela data do lançamento (regime de caixa) e
  /// agendamentos pela data do atendimento. "A receber", clientes e pontos
  /// são posições atuais e não dependem do período.
  ///
  /// Regras que mantêm os números honestos:
  /// - **faturamento** é o líquido: pagamentos e multas menos estornos;
  /// - **ticket médio** considera só pagamentos de serviços que de fato
  ///   aconteceram (sem estornos, resgates de valor zero ou multas);
  /// - **por forma de pagamento** mostra o líquido de cada forma — o estorno
  ///   sai da mesma forma em que o cliente pagou — e deixa resgates de fora.
  Future<RelatorioGeral> gerarRelatorio({
    DateTime? inicio,
    DateTime? fim,
  }) async {
    final db = await database;

    // Datas ISO-8601 locais comparam corretamente como texto.
    String periodo(String coluna) => [
      if (inicio != null) "$coluna >= '${inicio.toIso8601String()}'",
      if (fim != null) "$coluna < '${fim.toIso8601String()}'",
    ].map((c) => ' AND $c').join();
    final noCaixa = periodo('p.criado_em');
    final naAgenda = periodo('a.data_hora');

    Future<double> soma(String sql) async {
      final r = await db.rawQuery(sql);
      final v = r.isEmpty ? null : r.first.values.first;
      return (v as num?)?.toDouble() ?? 0;
    }

    Future<int> conta(String sql) async {
      final r = await db.rawQuery(sql);
      return Sqflite.firstIntValue(r) ?? 0;
    }

    Future<int> agendamentos([String? status]) => conta(
      'SELECT COUNT(*) FROM agendamento a WHERE 1 = 1'
      '${status == null ? '' : " AND a.status = '$status'"}$naAgenda',
    );

    final faturamento = await soma(
      "SELECT SUM(p.valor) FROM pagamento p "
      "WHERE p.status = 'Confirmado'$noCaixa",
    );
    final aReceber = await soma(
      "SELECT SUM(p.valor) FROM pagamento p WHERE p.status = 'Pendente'",
    );

    final atendimentos = await db.rawQuery('''
      SELECT COUNT(*) AS qtd, SUM(p.valor) AS total
      FROM pagamento p
      INNER JOIN agendamento a ON a.id = p.id_agendamento
      WHERE p.status = 'Confirmado' AND p.natureza = 'servico'
        AND a.status NOT IN ('cancelado', 'faltou')$noCaixa
    ''');
    final qtdAtendimentos = (atendimentos.first['qtd'] as num?)?.toInt() ?? 0;
    final totalAtendimentos =
        (atendimentos.first['total'] as num?)?.toDouble() ?? 0;

    final folha = await soma('SELECT SUM(salario) FROM barbeiro');

    final porMetodo = await db.rawQuery('''
      SELECT p.metodo AS metodo,
             SUM(CASE WHEN p.natureza != 'estorno' THEN 1 ELSE 0 END) AS qtd,
             SUM(p.valor) AS total
      FROM pagamento p
      WHERE p.status = 'Confirmado' AND p.natureza != 'resgate'$noCaixa
      GROUP BY p.metodo ORDER BY total DESC
    ''');

    final porServico = await db.rawQuery('''
      SELECT s.nome AS nome, COUNT(*) AS qtd
      FROM agendamento a
      INNER JOIN servico s ON s.id = a.id_servico
      WHERE a.status != 'cancelado'$naAgenda
      GROUP BY s.id ORDER BY qtd DESC LIMIT 5
    ''');

    final porBarbeiro = await db.rawQuery('''
      SELECT b.nome AS nome, COUNT(*) AS qtd
      FROM agendamento a
      INNER JOIN barbeiro b ON b.id = a.id_barbeiro
      WHERE a.status != 'cancelado'$naAgenda
      GROUP BY b.id ORDER BY qtd DESC LIMIT 5
    ''');

    return RelatorioGeral(
      inicio: inicio,
      fim: fim,
      faturamento: faturamento,
      aReceber: aReceber,
      ticketMedio: qtdAtendimentos == 0
          ? 0
          : totalAtendimentos / qtdAtendimentos,
      folhaSalarial: folha,
      totalAgendamentos: await agendamentos(),
      confirmados: await agendamentos('confirmado'),
      cancelados: await agendamentos('cancelado'),
      finalizados: await agendamentos('finalizado'),
      faltas: await agendamentos('faltou'),
      totalClientes: await conta('SELECT COUNT(*) FROM cliente'),
      pontosEmCirculacao: await conta('SELECT SUM(pontos) FROM fidelidade'),
      porMetodo: porMetodo
          .map(
            (l) => ItemRelatorio(
              rotulo: l['metodo'] as String,
              quantidade: (l['qtd'] as num?)?.toInt() ?? 0,
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

  Future<int> obterPontos(int idCliente) async =>
      _obterPontos(await database, idCliente);

  Future<int> _obterPontos(DatabaseExecutor db, int idCliente) async {
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
    await db.transaction(
      (txn) => _movimentarPontos(txn, idCliente, pontos, descricao),
    );
  }

  /// Movimenta o saldo com um `UPDATE` relativo (`pontos = pontos + ?`).
  ///
  /// Ler o saldo, somar em Dart e gravar o resultado perde créditos quando
  /// duas operações se cruzam — cada uma sobrescreve a outra.
  Future<void> _movimentarPontos(
    DatabaseExecutor db,
    int idCliente,
    int pontos,
    String descricao,
  ) async {
    await db.rawInsert(
      'INSERT OR IGNORE INTO fidelidade (id_cliente, pontos) VALUES (?, 0)',
      [idCliente],
    );
    await db.rawUpdate(
      'UPDATE fidelidade SET pontos = pontos + ? WHERE id_cliente = ?',
      [pontos, idCliente],
    );
    await db.insert('historico_ponto', {
      'id_cliente': idCliente,
      'descricao': descricao,
      'pontos': pontos,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  /// Quantos prêmios o cliente consegue resgatar com o saldo atual.
  ///
  /// Saldo devedor (negativo, após um estorno) não libera prêmio nenhum.
  Future<int> premiosDisponiveis(int idCliente) async {
    final pontos = await obterPontos(idCliente);
    return pontos <= 0 ? 0 : pontos ~/ pontosParaPremio;
  }

  /// Troca [pontosParaPremio] pontos por um serviço gratuito
  /// (regra de negócio 6).
  ///
  /// A conferência do saldo, o débito e o pagamento de valor zero acontecem
  /// numa única transação: dois resgates simultâneos não conseguem gastar o
  /// mesmo saldo, e nunca sobra um resgate sem pagamento — ou o contrário.
  /// O valor zero mantém o faturamento dos relatórios honesto: o serviço foi
  /// prestado, mas não entrou dinheiro.
  ///
  /// Retorna o id do pagamento criado, ou `null` se o saldo for insuficiente.
  Future<int?> resgatarPremio({
    required int idCliente,
    required int idAgendamento,
    required String nomeServico,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final saldo = await _obterPontos(txn, idCliente);
      if (saldo < pontosParaPremio) return null;

      return _registrarResgate(
        txn,
        idCliente: idCliente,
        idAgendamento: idAgendamento,
        nomeServico: nomeServico,
      );
    });
  }

  /// Pagamento de valor zero + débito dos pontos do prêmio.
  Future<int> _registrarResgate(
    DatabaseExecutor db, {
    required int idCliente,
    required int idAgendamento,
    required String nomeServico,
  }) async {
    final idPagamento = await _criarPagamento(
      db,
      Pagamento(
        idAgendamento: idAgendamento,
        valor: 0,
        metodo: metodoResgate,
        criadoEm: DateTime.now().toIso8601String(),
        natureza: NaturezaPagamento.resgate,
      ),
    );

    await _movimentarPontos(
      db,
      idCliente,
      -pontosParaPremio,
      'Resgate — $nomeServico',
    );
    return idPagamento;
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

  /// Arredonda para centavos: 50% de R$ 35,55 é 17,775, e o que se cobra é
  /// 17,77 — com o estorno de 17,78 fechando exatamente o valor pago.
  static double _emCentavos(double valor) => (valor * 100).round() / 100;

  static String _formatarDia(DateTime d) =>
      '${d.year}-${_doisDigitos(d.month)}-${_doisDigitos(d.day)}';
}

/// Trecho da agenda já ocupado, com início e fim.
typedef _Intervalo = ({DateTime inicio, DateTime fim});
