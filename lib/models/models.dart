/// Entidades do domínio SysBarber.
///
/// Todas as classes implementam `toMap()` e `fromMap()` para serialização
/// entre os objetos Dart e as tabelas do SQLite.
library;

// ---------------------------------------------------------------------------
// ENUMS
// ---------------------------------------------------------------------------

enum StatusAgendamento {
  confirmado,
  cancelado,
  finalizado,

  /// O cliente não compareceu ao horário marcado.
  faltou,
}

extension StatusAgendamentoX on StatusAgendamento {
  /// Rótulo exibido na interface (português).
  String get label {
    switch (this) {
      case StatusAgendamento.confirmado:
        return 'Confirmado';
      case StatusAgendamento.cancelado:
        return 'Cancelado';
      case StatusAgendamento.finalizado:
        return 'Finalizado';
      case StatusAgendamento.faltou:
        return 'Não compareceu';
    }
  }

  /// Valor persistido na coluna `status` da tabela `agendamento`.
  String get dbValue {
    switch (this) {
      case StatusAgendamento.confirmado:
        return 'confirmado';
      case StatusAgendamento.cancelado:
        return 'cancelado';
      case StatusAgendamento.finalizado:
        return 'finalizado';
      case StatusAgendamento.faltou:
        return 'faltou';
    }
  }

  /// Converte o valor do banco para o enum. Valores desconhecidos caem
  /// em [StatusAgendamento.confirmado].
  static StatusAgendamento fromDb(String valor) {
    switch (valor) {
      case 'cancelado':
        return StatusAgendamento.cancelado;
      case 'finalizado':
        return StatusAgendamento.finalizado;
      case 'faltou':
        return StatusAgendamento.faltou;
      case 'confirmado':
      default:
        return StatusAgendamento.confirmado;
    }
  }
}

enum MetodoPagamento { pix, cartao, dinheiro }

extension MetodoPagamentoX on MetodoPagamento {
  String get label {
    switch (this) {
      case MetodoPagamento.pix:
        return 'Pix';
      case MetodoPagamento.cartao:
        return 'Cartão';
      case MetodoPagamento.dinheiro:
        return 'Dinheiro';
    }
  }
}

// ---------------------------------------------------------------------------
// CLIENTE
// ---------------------------------------------------------------------------

class Cliente {
  final int? id;
  final String nome;
  final String email;
  final String telefone;
  final String senhaHash;
  final String criadoEm;

  /// Só quem tem esta marca enxerga a área administrativa. Contas criadas
  /// pelo formulário de cadastro nascem sempre como cliente comum.
  final bool admin;

  const Cliente({
    this.id,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.senhaHash,
    required this.criadoEm,
    this.admin = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'email': email,
    'telefone': telefone,
    'senha_hash': senhaHash,
    'criado_em': criadoEm,
    'admin': admin ? 1 : 0,
  };

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
    id: map['id'] as int?,
    nome: map['nome'] as String,
    email: map['email'] as String,
    telefone: map['telefone'] as String,
    senhaHash: map['senha_hash'] as String,
    criadoEm: map['criado_em'] as String,
    admin: ((map['admin'] as num?)?.toInt() ?? 0) == 1,
  );

  Cliente copyWith({
    int? id,
    String? nome,
    String? email,
    String? telefone,
    String? senhaHash,
    String? criadoEm,
    bool? admin,
  }) => Cliente(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    email: email ?? this.email,
    telefone: telefone ?? this.telefone,
    senhaHash: senhaHash ?? this.senhaHash,
    criadoEm: criadoEm ?? this.criadoEm,
    admin: admin ?? this.admin,
  );

  /// Iniciais do nome, usadas no avatar do perfil.
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// BARBEIRO
// ---------------------------------------------------------------------------

class Barbeiro {
  final int? id;
  final String nome;
  final String especialidade;
  final double avaliacao;
  final int avaliacoes;
  final String iniciais;

  /// Dados de contato e acesso do profissional.
  final String telefone;
  final String email;
  final String senhaHash;
  final double salario;

  /// Profissional disponível para receber novos agendamentos. Quem está
  /// inativo continua visível na escolha, porém esmaecido e sem seleção.
  final bool ativo;

  const Barbeiro({
    this.id,
    required this.nome,
    required this.especialidade,
    required this.avaliacao,
    required this.avaliacoes,
    required this.iniciais,
    this.telefone = '',
    this.email = '',
    this.senhaHash = '',
    this.salario = 0,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'especialidade': especialidade,
    'avaliacao': avaliacao,
    'avaliacoes': avaliacoes,
    'iniciais': iniciais,
    'telefone': telefone,
    'email': email,
    'senha_hash': senhaHash,
    'salario': salario,
    'ativo': ativo ? 1 : 0,
  };

  factory Barbeiro.fromMap(Map<String, dynamic> map) => Barbeiro(
    id: map['id'] as int?,
    nome: map['nome'] as String,
    especialidade: map['especialidade'] as String,
    avaliacao: (map['avaliacao'] as num).toDouble(),
    avaliacoes: (map['avaliacoes'] as num).toInt(),
    iniciais: map['iniciais'] as String,
    telefone: (map['telefone'] as String?) ?? '',
    email: (map['email'] as String?) ?? '',
    senhaHash: (map['senha_hash'] as String?) ?? '',
    salario: (map['salario'] as num?)?.toDouble() ?? 0,
    // Bancos anteriores à v4 não têm a coluna: quem não tem marca é ativo.
    ativo: ((map['ativo'] as num?)?.toInt() ?? 1) == 1,
  );

  Barbeiro copyWith({
    int? id,
    String? nome,
    String? especialidade,
    double? avaliacao,
    int? avaliacoes,
    String? iniciais,
    String? telefone,
    String? email,
    String? senhaHash,
    double? salario,
    bool? ativo,
  }) => Barbeiro(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    especialidade: especialidade ?? this.especialidade,
    avaliacao: avaliacao ?? this.avaliacao,
    avaliacoes: avaliacoes ?? this.avaliacoes,
    iniciais: iniciais ?? this.iniciais,
    telefone: telefone ?? this.telefone,
    email: email ?? this.email,
    senhaHash: senhaHash ?? this.senhaHash,
    salario: salario ?? this.salario,
    ativo: ativo ?? this.ativo,
  );

  /// Gera as iniciais a partir do nome (usado ao cadastrar pelo admin).
  static String iniciaisDe(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// SERVICO
// ---------------------------------------------------------------------------

class Servico {
  final int? id;
  final String nome;
  final String descricao;
  final double preco;
  final int duracaoMinutos;
  final String icone;

  const Servico({
    this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.duracaoMinutos,
    required this.icone,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'descricao': descricao,
    'preco': preco,
    'duracao_minutos': duracaoMinutos,
    'icone': icone,
  };

  factory Servico.fromMap(Map<String, dynamic> map) => Servico(
    id: map['id'] as int?,
    nome: map['nome'] as String,
    descricao: map['descricao'] as String,
    preco: (map['preco'] as num).toDouble(),
    duracaoMinutos: (map['duracao_minutos'] as num).toInt(),
    icone: map['icone'] as String,
  );

  Servico copyWith({
    int? id,
    String? nome,
    String? descricao,
    double? preco,
    int? duracaoMinutos,
    String? icone,
  }) => Servico(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    descricao: descricao ?? this.descricao,
    preco: preco ?? this.preco,
    duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
    icone: icone ?? this.icone,
  );
}

// ---------------------------------------------------------------------------
// AGENDAMENTO
// ---------------------------------------------------------------------------

class Agendamento {
  final int? id;
  final int idCliente;
  final int idBarbeiro;
  final int idServico;
  final String dataHora;
  final StatusAgendamento status;

  /// Duração registrada no momento do agendamento. Fica gravada no próprio
  /// agendamento para que alterar o serviço depois não mude o que já foi
  /// marcado. `null` só antes de ir para o banco, que a preenche pelo serviço.
  final int? duracaoMinutos;

  /// Preço do serviço no momento do agendamento, pelo mesmo motivo: um
  /// reajuste depois não pode mudar a multa nem o histórico de quem já marcou.
  final double? preco;

  /// Populados pelo INNER JOIN em [DatabaseService.listarAgendamentosCliente].
  final Barbeiro? barbeiro;
  final Servico? servico;

  /// Populado na agenda do profissional, para saber quem será atendido.
  final Cliente? cliente;

  /// Lançamento principal (serviço, resgate ou multa), trazido pelas
  /// listagens junto com o agendamento.
  final Pagamento? pagamento;

  /// Quanto já foi devolvido ao cliente em estornos.
  final double valorEstornado;

  const Agendamento({
    this.id,
    required this.idCliente,
    required this.idBarbeiro,
    required this.idServico,
    required this.dataHora,
    this.status = StatusAgendamento.confirmado,
    this.duracaoMinutos,
    this.preco,
    this.barbeiro,
    this.servico,
    this.cliente,
    this.pagamento,
    this.valorEstornado = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'id_cliente': idCliente,
    'id_barbeiro': idBarbeiro,
    'id_servico': idServico,
    'data_hora': dataHora,
    'status': status.dbValue,
    if (duracaoMinutos != null) 'duracao_minutos': duracaoMinutos,
    if (preco != null) 'preco': preco,
  };

  factory Agendamento.fromMap(Map<String, dynamic> map) => Agendamento(
    id: map['id'] as int?,
    idCliente: (map['id_cliente'] as num).toInt(),
    idBarbeiro: (map['id_barbeiro'] as num).toInt(),
    idServico: (map['id_servico'] as num).toInt(),
    dataHora: map['data_hora'] as String,
    status: StatusAgendamentoX.fromDb(map['status'] as String),
    duracaoMinutos: (map['duracao_minutos'] as num?)?.toInt(),
    preco: (map['preco'] as num?)?.toDouble(),
  );

  Agendamento copyWith({
    StatusAgendamento? status,
    Barbeiro? barbeiro,
    Servico? servico,
    Cliente? cliente,
    Pagamento? pagamento,
    double? valorEstornado,
  }) => Agendamento(
    id: id,
    idCliente: idCliente,
    idBarbeiro: idBarbeiro,
    idServico: idServico,
    dataHora: dataHora,
    status: status ?? this.status,
    duracaoMinutos: duracaoMinutos,
    preco: preco,
    barbeiro: barbeiro ?? this.barbeiro,
    servico: servico ?? this.servico,
    cliente: cliente ?? this.cliente,
    pagamento: pagamento ?? this.pagamento,
    valorEstornado: valorEstornado ?? this.valorEstornado,
  );

  DateTime get data => DateTime.parse(dataHora);

  /// Valor do atendimento: o registrado no agendamento (ou, em objetos ainda
  /// não gravados, o preço atual do serviço).
  double get valor => preco ?? servico?.preco ?? 0;

  // -------------------------------------------------------------------------
  // Regras de estado — valem para a tela e para o banco.
  //
  // Um atendimento em aberto termina de um destes jeitos: cancelado (antes do
  // horário), concluído (a partir do dia marcado) ou falta (depois do
  // horário). Encerrado, não aceita mais nenhuma ação.
  // -------------------------------------------------------------------------

  /// Ainda não teve desfecho.
  bool get emAberto => status == StatusAgendamento.confirmado;

  /// O horário marcado já chegou.
  bool jaComecou(DateTime agora) => !data.isAfter(agora);

  /// Cancelar só faz sentido antes do horário; depois dele o desfecho é
  /// concluir ou registrar a falta.
  bool podeCancelar(DateTime agora) => emAberto && !jaComecou(agora);

  /// Conclui a partir do dia do atendimento (o cliente pode chegar adiantado),
  /// mas nunca dias antes — e continua possível depois do horário.
  bool podeFinalizar(DateTime agora) {
    if (!emAberto) return false;
    final dia = DateTime(data.year, data.month, data.day);
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return !dia.isAfter(hoje);
  }

  /// Falta só pode ser registrada depois do horário marcado.
  bool podeRegistrarFalta(DateTime agora) => emAberto && jaComecou(agora);

  /// Horário já passou e o profissional ainda não deu o desfecho.
  bool aguardandoConclusao(DateTime agora) => emAberto && jaComecou(agora);
}

// ---------------------------------------------------------------------------
// PAGAMENTO
// ---------------------------------------------------------------------------

/// O que um lançamento financeiro representa.
///
/// Sem esta marca a única pista era o texto do método ("Multa por
/// cancelamento", "Estorno"...), que se perdia assim que o balcão registrava
/// como a multa foi paga — e a multa passava a ser tratada como serviço.
enum NaturezaPagamento {
  /// Pagamento de um serviço agendado. É o único que gera pontos.
  servico,

  /// Multa por cancelamento fora do prazo.
  multa,

  /// Devolução (valor negativo) ao cliente.
  estorno,

  /// Serviço trocado por pontos de fidelidade (valor zero).
  resgate,
}

extension NaturezaPagamentoX on NaturezaPagamento {
  /// Valor persistido na coluna `natureza`.
  String get dbValue => name;

  /// Registros anteriores à coluna são tratados como serviço.
  static NaturezaPagamento fromDb(String? valor) => NaturezaPagamento.values
      .firstWhere((n) => n.name == valor, orElse: () => NaturezaPagamento.servico);
}

class Pagamento {
  /// Valores da coluna `status`.
  static const String statusPendente = 'Pendente';
  static const String statusConfirmado = 'Confirmado';
  static const String statusCancelado = 'Cancelado';

  final int? id;
  final int idAgendamento;
  final double valor;
  final String metodo;
  final String status;
  final String criadoEm;

  /// `antecipado` (paga agora) ou `na_hora` (paga na barbearia).
  final String tipo;

  /// Últimos 4 dígitos do cartão, quando houver. O número completo **nunca**
  /// é armazenado.
  final String? cartaoFinal;

  final NaturezaPagamento natureza;

  const Pagamento({
    this.id,
    required this.idAgendamento,
    required this.valor,
    required this.metodo,
    this.status = statusConfirmado,
    required this.criadoEm,
    this.tipo = 'antecipado',
    this.cartaoFinal,
    this.natureza = NaturezaPagamento.servico,
  });

  bool get confirmado => status == statusConfirmado;
  bool get pendente => status == statusPendente;
  bool get cancelado => status == statusCancelado;

  Map<String, dynamic> toMap() => {
    'id': id,
    'id_agendamento': idAgendamento,
    'valor': valor,
    'metodo': metodo,
    'status': status,
    'criado_em': criadoEm,
    'tipo': tipo,
    'cartao_final': cartaoFinal,
    'natureza': natureza.dbValue,
  };

  factory Pagamento.fromMap(Map<String, dynamic> map) => Pagamento(
    id: map['id'] as int?,
    idAgendamento: (map['id_agendamento'] as num).toInt(),
    valor: (map['valor'] as num).toDouble(),
    metodo: map['metodo'] as String,
    status: map['status'] as String,
    criadoEm: map['criado_em'] as String,
    tipo: (map['tipo'] as String?) ?? 'antecipado',
    cartaoFinal: map['cartao_final'] as String?,
    natureza: NaturezaPagamentoX.fromDb(map['natureza'] as String?),
  );
}

/// Momento em que o cliente escolhe pagar.
enum TipoPagamento { antecipado, naHora }

extension TipoPagamentoX on TipoPagamento {
  String get label => switch (this) {
    TipoPagamento.antecipado => 'Pagar agora',
    TipoPagamento.naHora => 'Pagar na barbearia',
  };

  String get descricao => switch (this) {
    TipoPagamento.antecipado =>
      'Confirma na hora e já credita seus pontos de fidelidade',
    TipoPagamento.naHora =>
      'Fica pendente e é quitado no balcão no dia do atendimento',
  };

  String get dbValue => switch (this) {
    TipoPagamento.antecipado => 'antecipado',
    TipoPagamento.naHora => 'na_hora',
  };
}

// ---------------------------------------------------------------------------
// FIDELIDADE
// ---------------------------------------------------------------------------

class Fidelidade {
  final int? id;
  final int idCliente;
  final int pontos;

  const Fidelidade({this.id, required this.idCliente, this.pontos = 0});

  Map<String, dynamic> toMap() => {
    'id': id,
    'id_cliente': idCliente,
    'pontos': pontos,
  };

  factory Fidelidade.fromMap(Map<String, dynamic> map) => Fidelidade(
    id: map['id'] as int?,
    idCliente: (map['id_cliente'] as num).toInt(),
    pontos: (map['pontos'] as num).toInt(),
  );
}

// ---------------------------------------------------------------------------
// RESERVA
// ---------------------------------------------------------------------------

/// Violação de uma regra de negócio, com mensagem pronta para o usuário.
class RegraNegocioException implements Exception {
  final String mensagem;

  const RegraNegocioException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Como o cliente fecha o agendamento na etapa de pagamento.
enum ModoReserva { pagarAgora, pagarNaBarbearia, resgatarPontos }

/// O que a reserva gravou, para a tela explicar o resultado ao cliente.
class ResultadoReserva {
  final int idAgendamento;
  final int idPagamento;

  /// Valor cobrado — sempre o preço do banco no momento da reserva.
  final double valor;
  final int pontosCreditados;
  final int pontosDebitados;
  final int saldoPontos;

  const ResultadoReserva({
    required this.idAgendamento,
    required this.idPagamento,
    required this.valor,
    this.pontosCreditados = 0,
    this.pontosDebitados = 0,
    required this.saldoPontos,
  });
}

// ---------------------------------------------------------------------------
// RELATÓRIOS
// ---------------------------------------------------------------------------

/// Desfecho financeiro de um cancelamento (regra de negócio 9).
class ResultadoCancelamento {
  /// `true` quando o cancelamento ocorreu dentro do prazo mínimo e houve
  /// cobrança de multa.
  final bool comMulta;

  /// Valor retido pela barbearia a título de multa.
  final double multa;

  /// Valor devolvido ao cliente, quando o serviço já havia sido pago.
  final double estorno;

  /// Multa que ficou pendente de cobrança (caso o cliente ainda não tivesse
  /// pago o serviço).
  final double multaAPagar;

  /// Pontos de fidelidade estornados ou devolvidos ao cliente.
  final int pontosAjustados;

  const ResultadoCancelamento({
    required this.comMulta,
    this.multa = 0,
    this.estorno = 0,
    this.multaAPagar = 0,
    this.pontosAjustados = 0,
  });
}

/// Números do dia corrente exibidos no painel administrativo.
///
/// Cada indicador traz o valor de hoje e o total geral, para que o painel
/// continue informativo mesmo num dia sem movimento.
class ResumoDia {
  final int agendamentosHoje;
  final int agendamentosTotal;
  final int barbeirosHoje;
  final int barbeirosTotal;
  final int clientesHoje;
  final int clientesTotal;
  final int servicosHoje;
  final int servicosTotal;

  const ResumoDia({
    required this.agendamentosHoje,
    required this.agendamentosTotal,
    required this.barbeirosHoje,
    required this.barbeirosTotal,
    required this.clientesHoje,
    required this.clientesTotal,
    required this.servicosHoje,
    required this.servicosTotal,
  });
}

/// Uma linha de ranking dentro do relatório (método, serviço ou barbeiro).
class ItemRelatorio {
  final String rotulo;
  final int quantidade;
  final double valor;

  const ItemRelatorio({
    required this.rotulo,
    required this.quantidade,
    this.valor = 0,
  });
}

/// Indicadores consolidados apresentados na área administrativa.
class RelatorioGeral {
  /// Período coberto (fim exclusivo). `null` nos dois = desde o início.
  final DateTime? inicio;
  final DateTime? fim;

  /// Receita líquida: pagamentos e multas menos estornos.
  final double faturamento;
  final double aReceber;
  final double ticketMedio;
  final double folhaSalarial;
  final int totalAgendamentos;
  final int confirmados;
  final int cancelados;
  final int finalizados;

  /// Atendimentos em que o cliente não compareceu.
  final int faltas;
  final int totalClientes;
  final int pontosEmCirculacao;
  final List<ItemRelatorio> porMetodo;
  final List<ItemRelatorio> porServico;
  final List<ItemRelatorio> porBarbeiro;

  const RelatorioGeral({
    this.inicio,
    this.fim,
    required this.faturamento,
    required this.aReceber,
    required this.ticketMedio,
    required this.folhaSalarial,
    required this.totalAgendamentos,
    required this.confirmados,
    required this.cancelados,
    required this.finalizados,
    this.faltas = 0,
    required this.totalClientes,
    required this.pontosEmCirculacao,
    required this.porMetodo,
    required this.porServico,
    required this.porBarbeiro,
  });

  /// Percentual de agendamentos cancelados — indicador de qualidade.
  double get taxaCancelamento =>
      totalAgendamentos == 0 ? 0 : (cancelados / totalAgendamentos) * 100;
}

// ---------------------------------------------------------------------------
// HISTORICO DE PONTOS
// ---------------------------------------------------------------------------

class HistoricoPonto {
  final int? id;
  final int idCliente;
  final String descricao;
  final int pontos;
  final String criadoEm;

  const HistoricoPonto({
    this.id,
    required this.idCliente,
    required this.descricao,
    required this.pontos,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'id_cliente': idCliente,
    'descricao': descricao,
    'pontos': pontos,
    'criado_em': criadoEm,
  };

  factory HistoricoPonto.fromMap(Map<String, dynamic> map) => HistoricoPonto(
    id: map['id'] as int?,
    idCliente: (map['id_cliente'] as num).toInt(),
    descricao: map['descricao'] as String,
    pontos: (map['pontos'] as num).toInt(),
    criadoEm: map['criado_em'] as String,
  );
}
