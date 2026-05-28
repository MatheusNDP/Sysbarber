class Cliente {
  final int? id;
  final String nome;
  final String email;
  final String telefone;
  final String senhaHash;
  final DateTime criadoEm;

  Cliente({
    this.id,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.senhaHash,
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'senha_hash': senhaHash,
        'criado_em': criadoEm.toIso8601String(),
      };

  factory Cliente.fromMap(Map<String, dynamic> m) => Cliente(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        email: m['email'] as String,
        telefone: m['telefone'] as String,
        senhaHash: m['senha_hash'] as String,
        criadoEm: DateTime.parse(m['criado_em'] as String),
      );
}

class Barbeiro {
  final int? id;
  final String nome;
  final String especialidade;
  final double avaliacao;
  final int avaliacoes;
  final String iniciais;

  Barbeiro({
    this.id,
    required this.nome,
    required this.especialidade,
    required this.avaliacao,
    required this.avaliacoes,
    required this.iniciais,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'especialidade': especialidade,
        'avaliacao': avaliacao,
        'avaliacoes': avaliacoes,
        'iniciais': iniciais,
      };

  factory Barbeiro.fromMap(Map<String, dynamic> m) => Barbeiro(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        especialidade: m['especialidade'] as String,
        avaliacao: (m['avaliacao'] as num).toDouble(),
        avaliacoes: m['avaliacoes'] as int,
        iniciais: m['iniciais'] as String,
      );
}

class Servico {
  final int? id;
  final String nome;
  final String descricao;
  final double preco;
  final int duracaoMinutos;
  final String icone;

  Servico({
    this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.duracaoMinutos,
    required this.icone,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'descricao': descricao,
        'preco': preco,
        'duracao_minutos': duracaoMinutos,
        'icone': icone,
      };

  factory Servico.fromMap(Map<String, dynamic> m) => Servico(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        descricao: m['descricao'] as String,
        preco: (m['preco'] as num).toDouble(),
        duracaoMinutos: m['duracao_minutos'] as int,
        icone: m['icone'] as String,
      );
}

enum StatusAgendamento { confirmado, cancelado, finalizado }

extension StatusAgendamentoX on StatusAgendamento {
  String get label => switch (this) {
        StatusAgendamento.confirmado => 'Confirmado',
        StatusAgendamento.cancelado => 'Cancelado',
        StatusAgendamento.finalizado => 'Finalizado',
      };
  String get dbValue => name;
  static StatusAgendamento fromDb(String s) =>
      StatusAgendamento.values.firstWhere((e) => e.name == s,
          orElse: () => StatusAgendamento.confirmado);
}

class Agendamento {
  final int? id;
  final int idCliente;
  final int idBarbeiro;
  final int idServico;
  final DateTime dataHora;
  StatusAgendamento status;

  // Campos populados via join
  Barbeiro? barbeiro;
  Servico? servico;

  Agendamento({
    this.id,
    required this.idCliente,
    required this.idBarbeiro,
    required this.idServico,
    required this.dataHora,
    this.status = StatusAgendamento.confirmado,
    this.barbeiro,
    this.servico,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'id_cliente': idCliente,
        'id_barbeiro': idBarbeiro,
        'id_servico': idServico,
        'data_hora': dataHora.toIso8601String(),
        'status': status.dbValue,
      };

  factory Agendamento.fromMap(Map<String, dynamic> m) => Agendamento(
        id: m['id'] as int?,
        idCliente: m['id_cliente'] as int,
        idBarbeiro: m['id_barbeiro'] as int,
        idServico: m['id_servico'] as int,
        dataHora: DateTime.parse(m['data_hora'] as String),
        status: StatusAgendamentoX.fromDb(m['status'] as String),
      );
}

enum MetodoPagamento { pix, cartao, dinheiro }

extension MetodoPagamentoX on MetodoPagamento {
  String get label => switch (this) {
        MetodoPagamento.pix => 'Pix',
        MetodoPagamento.cartao => 'Cartão',
        MetodoPagamento.dinheiro => 'Dinheiro',
      };
}

class Pagamento {
  final int? id;
  final int idAgendamento;
  final double valor;
  final MetodoPagamento metodo;
  final String status;
  final DateTime criadoEm;

  Pagamento({
    this.id,
    required this.idAgendamento,
    required this.valor,
    required this.metodo,
    this.status = 'Confirmado',
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'id_agendamento': idAgendamento,
        'valor': valor,
        'metodo': metodo.name,
        'status': status,
        'criado_em': criadoEm.toIso8601String(),
      };
}

class HistoricoPonto {
  final int? id;
  final int idCliente;
  final String descricao;
  final int pontos;
  final DateTime criadoEm;

  HistoricoPonto({
    this.id,
    required this.idCliente,
    required this.descricao,
    required this.pontos,
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'id_cliente': idCliente,
        'descricao': descricao,
        'pontos': pontos,
        'criado_em': criadoEm.toIso8601String(),
      };

  factory HistoricoPonto.fromMap(Map<String, dynamic> m) => HistoricoPonto(
        id: m['id'] as int?,
        idCliente: m['id_cliente'] as int,
        descricao: m['descricao'] as String,
        pontos: m['pontos'] as int,
        criadoEm: DateTime.parse(m['criado_em'] as String),
      );
}
