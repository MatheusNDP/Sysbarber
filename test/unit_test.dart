import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/lembretes.dart';
import 'package:sysbarber/services/senhas.dart';

/// Testes unitários das regras puras: hash de senha e serialização das
/// entidades. Nenhum deles toca no banco de dados.
void main() {
  group('Hash de senha (PBKDF2 com salt individual)', () {
    setUpAll(() => Senhas.iteracoes = 1000);

    test('o hash é diferente da senha original', () {
      const senha = 'minhaSenha123';
      final hash = DatabaseService.hashSenha(senha);
      expect(hash, isNot(equals(senha)));
      expect(hash.contains(senha), isFalse);
    });

    test('a mesma senha gera hashes diferentes, e ambos conferem', () {
      final a = Senhas.gerarHash('demo1234');
      final b = Senhas.gerarHash('demo1234');
      // Salt individual: o mesmo texto não gera o mesmo hash, então uma
      // tabela pré-calculada não serve para o banco inteiro.
      expect(a, isNot(equals(b)));
      expect(Senhas.conferir('demo1234', a), isTrue);
      expect(Senhas.conferir('demo1234', b), isTrue);
    });

    test('senha errada não confere', () {
      final hash = Senhas.gerarHash('demo1234');
      expect(Senhas.conferir('demo12345', hash), isFalse);
      expect(Senhas.conferir('', hash), isFalse);
    });

    test('o hash registra algoritmo, iterações, salt e resultado', () {
      final partes = Senhas.gerarHash('qualquer').split(r'$');
      expect(partes.length, 4);
      expect(partes[0], 'pbkdf2-sha256');
      expect(int.parse(partes[1]), Senhas.iteracoes);
    });

    test('PBKDF2 bate com o vetor de referência (RFC 7914)', () {
      final saida = Senhas.pbkdf2(
        utf8.encode('password'),
        utf8.encode('salt'),
        4096,
        32,
      );
      expect(
        saida.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('o formato antigo continua entrando e pede atualização', () {
      final legado = Senhas.hashLegado('admin1234');
      expect(legado.length, 64);
      expect(Senhas.conferir('admin1234', legado), isTrue);
      expect(Senhas.conferir('outra', legado), isFalse);
      expect(Senhas.precisaAtualizar(legado), isTrue);
      expect(Senhas.precisaAtualizar(Senhas.gerarHash('x')), isFalse);
    });
  });

  group('Entidade Cliente', () {
    const cliente = Cliente(
      id: 1,
      nome: 'João da Silva',
      email: 'joao@teste.com',
      telefone: '(67) 99999-1111',
      senhaHash: 'hash_qualquer',
      criadoEm: '2026-08-10T10:00:00.000',
    );

    test('toMap() converte para as colunas do banco', () {
      final mapa = cliente.toMap();
      expect(mapa['id'], 1);
      expect(mapa['nome'], 'João da Silva');
      expect(mapa['email'], 'joao@teste.com');
      expect(mapa['telefone'], '(67) 99999-1111');
      expect(mapa['senha_hash'], 'hash_qualquer');
      expect(mapa['criado_em'], '2026-08-10T10:00:00.000');
    });

    test('fromMap() reconstrói o objeto corretamente', () {
      final reconstruido = Cliente.fromMap(cliente.toMap());
      expect(reconstruido.id, cliente.id);
      expect(reconstruido.nome, cliente.nome);
      expect(reconstruido.email, cliente.email);
      expect(reconstruido.telefone, cliente.telefone);
      expect(reconstruido.senhaHash, cliente.senhaHash);
      expect(reconstruido.criadoEm, cliente.criadoEm);
    });
  });

  group('Entidade Servico', () {
    test('toMap() → fromMap() preserva todos os dados', () {
      const original = Servico(
        id: 3,
        nome: 'Corte + Barba',
        descricao: 'Combo completo',
        preco: 55.00,
        duracaoMinutos: 50,
        icone: '💈',
      );

      final reconstruido = Servico.fromMap(original.toMap());

      expect(reconstruido.id, original.id);
      expect(reconstruido.nome, original.nome);
      expect(reconstruido.descricao, original.descricao);
      expect(reconstruido.preco, original.preco);
      expect(reconstruido.duracaoMinutos, original.duracaoMinutos);
      expect(reconstruido.icone, original.icone);
    });
  });

  group('Entidade Barbeiro', () {
    test('a foto vai e volta pelo banco, e sem a coluna não há foto', () {
      final foto = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      final barbeiro = Barbeiro(
        id: 1,
        nome: 'Carlos Eduardo',
        especialidade: 'Cortes clássicos',
        iniciais: 'CE',
        foto: foto,
      );

      final mapa = barbeiro.toMap();
      expect(mapa['foto'], foto);
      expect(Barbeiro.fromMap(mapa).foto, foto);
      // Atualizar o hash da senha no login não leva a foto embora.
      expect(barbeiro.copyWith(senhaHash: 'novo').foto, foto);
      // As listagens de agendamentos não trazem a coluna.
      final daLista = Barbeiro.fromMap({
        'id': 1,
        'nome': 'Carlos Eduardo',
        'especialidade': 'Cortes clássicos',
        'iniciais': 'CE',
      });
      expect(daLista.foto, isNull);
    });
  });

  group('Enum StatusAgendamento', () {
    test('dbValue e fromDb são simétricos para todos os valores', () {
      for (final status in StatusAgendamento.values) {
        expect(StatusAgendamentoX.fromDb(status.dbValue), status);
      }
      expect(StatusAgendamento.confirmado.dbValue, 'confirmado');
      expect(StatusAgendamento.cancelado.dbValue, 'cancelado');
      expect(StatusAgendamento.finalizado.dbValue, 'finalizado');
    });

    test('os labels estão em português', () {
      expect(StatusAgendamento.confirmado.label, 'Confirmado');
      expect(StatusAgendamento.cancelado.label, 'Cancelado');
      expect(StatusAgendamento.finalizado.label, 'Concluído');
    });

    test('um valor desconhecido cai em confirmado', () {
      expect(StatusAgendamentoX.fromDb('valor_invalido'),
          StatusAgendamento.confirmado);
      expect(StatusAgendamentoX.fromDb(''), StatusAgendamento.confirmado);
    });
  });

  group('Enum MetodoPagamento', () {
    test('os labels estão corretos', () {
      expect(MetodoPagamento.pix.label, 'Pix');
      expect(MetodoPagamento.cartao.label, 'Cartão');
      expect(MetodoPagamento.dinheiro.label, 'Dinheiro');
    });
  });

  group('Entidade Agendamento', () {
    test('toMap() inclui todas as chaves estrangeiras', () {
      const agendamento = Agendamento(
        id: 7,
        idCliente: 1,
        idBarbeiro: 2,
        idServico: 3,
        dataHora: '2026-08-11T09:00:00.000',
        status: StatusAgendamento.confirmado,
      );

      final mapa = agendamento.toMap();

      expect(mapa.containsKey('id_cliente'), isTrue);
      expect(mapa.containsKey('id_barbeiro'), isTrue);
      expect(mapa.containsKey('id_servico'), isTrue);
      expect(mapa['id_cliente'], 1);
      expect(mapa['id_barbeiro'], 2);
      expect(mapa['id_servico'], 3);
      expect(mapa['data_hora'], '2026-08-11T09:00:00.000');
      expect(mapa['status'], 'confirmado');
    });
  });

  group('Entidade Pagamento', () {
    test('a natureza vai e volta pelo banco', () {
      const multa = Pagamento(
        idAgendamento: 1,
        valor: 27.5,
        metodo: 'Pix',
        criadoEm: '2026-08-10T10:00:00.000',
        natureza: NaturezaPagamento.multa,
      );
      final mapa = multa.toMap();
      expect(mapa['natureza'], 'multa');
      expect(Pagamento.fromMap(mapa).natureza, NaturezaPagamento.multa);
    });

    test('registro antigo, sem a coluna, é tratado como serviço', () {
      final p = Pagamento.fromMap({
        'id': 1,
        'id_agendamento': 1,
        'valor': 35.0,
        'metodo': 'Pix',
        'status': 'Cancelado',
        'criado_em': '2026-08-10T10:00:00.000',
      });
      expect(p.natureza, NaturezaPagamento.servico);
      expect(p.cancelado, isTrue);
      expect(p.pendente, isFalse);
    });
  });

  group('Entidade CodigoSenha', () {
    const codigo = CodigoSenha(
      idBarbeiro: 2,
      origem: OrigemCodigo.barbearia,
      codigoHash: 'hash',
      criadoEm: '2030-03-04T10:00:00.000',
      expiraEm: '2030-03-05T10:00:00.000',
      tentativas: 3,
    );

    test('vai e volta pelo banco, de cliente ou de barbeiro', () {
      final mapa = codigo.toMap();
      expect(mapa['id_cliente'], isNull);
      expect(mapa['origem'], 'barbearia');

      final lido = CodigoSenha.fromMap(mapa);
      expect(lido.idBarbeiro, 2);
      expect(lido.origem, OrigemCodigo.barbearia);
      expect(lido.tentativas, 3);
    });

    test('a origem e-mail também vai e volta pelo banco', () {
      expect(OrigemCodigo.email.dbValue, 'email');
      expect(OrigemCodigoX.fromDb('email'), OrigemCodigo.email);
      expect(OrigemCodigoX.fromDb('sms'), OrigemCodigo.sms);
    });

    test('vence exatamente no fim da validade', () {
      expect(codigo.vencido(DateTime(2030, 3, 5, 9, 59)), isFalse);
      expect(codigo.vencido(DateTime(2030, 3, 5, 10)), isTrue);
    });
  });

  group('Entidade ConviteBarbeiro', () {
    const convite = ConviteBarbeiro(
      id: 4,
      nome: 'Pedro Alves',
      especialidade: 'Degradê',
      salario: 2400,
      codigoHash: 'hash',
      criadoEm: '2030-03-04T10:00:00.000',
      expiraEm: '2030-03-11T10:00:00.000',
    );

    test('vai e volta pelo banco, vence no fim da validade e normaliza o '
        'código digitado', () {
      final lido = ConviteBarbeiro.fromMap(convite.toMap());
      expect(lido.nome, 'Pedro Alves');
      expect(lido.salario, 2400);
      expect(lido.iniciais, 'PA');
      expect(convite.vencido(DateTime(2030, 3, 11, 9, 59)), isFalse);
      expect(convite.vencido(DateTime(2030, 3, 11, 10)), isTrue);
      expect(ConviteBarbeiro.normalizarCodigo(' k7mp-q2xr '), 'K7MPQ2XR');
    });
  });

  group('Lembretes do horário', () {
    final agora = DateTime(2030, 3, 4, 8);
    Agendamento marcado(
      int id,
      DateTime quando, [
      StatusAgendamento status = StatusAgendamento.confirmado,
    ]) => Agendamento(
      id: id,
      idCliente: 1,
      idBarbeiro: 2,
      idServico: 1,
      dataHora: quando.toIso8601String(),
      status: status,
      servico: const Servico(
        nome: 'Corte de Cabelo',
        descricao: 'Tesoura ou máquina',
        preco: 35,
        duracaoMinutos: 30,
        icone: 'corte',
      ),
      barbeiro: const Barbeiro(
        nome: 'Rafael Souza',
        especialidade: 'Cortes modernos',
        iniciais: 'RS',
      ),
    );

    test('um lembrete por agendamento em aberto, 2 horas antes, com o prazo '
        'para cancelar sem multa', () {
      final lembretes = lembretesDe([
        marcado(7, DateTime(2030, 3, 4, 14, 30)),
      ], agora);

      expect(lembretes, hasLength(1));
      final l = lembretes.single;
      expect(l.id, 7);
      expect(l.quando, DateTime(2030, 3, 4, 12, 30));
      expect(l.titulo, 'Seu horário é às 14:30');
      expect(l.texto, contains('Corte de Cabelo com Rafael Souza'));
      expect(l.texto, contains('até as 13:30, sem multa'));
    });

    test('sem lembrete para o que já foi encerrado ou quando faltam menos de '
        '2 horas', () {
      final lembretes = lembretesDe([
        marcado(1, DateTime(2030, 3, 5, 9), StatusAgendamento.cancelado),
        marcado(2, DateTime(2030, 3, 5, 9), StatusAgendamento.finalizado),
        marcado(3, DateTime(2030, 3, 4, 9, 30)),
        // Exatamente 2 horas antes: o momento do lembrete já chegou.
        marcado(4, DateTime(2030, 3, 4, 10)),
      ], agora);

      expect(lembretes, isEmpty);
    });
  });

  group('Regras de estado do Agendamento', () {
    Agendamento em(DateTime quando, [StatusAgendamento? status]) =>
        Agendamento(
          idCliente: 1,
          idBarbeiro: 1,
          idServico: 1,
          dataHora: quando.toIso8601String(),
          status: status ?? StatusAgendamento.confirmado,
        );

    final marcado = DateTime(2026, 8, 20, 10, 0);

    test('antes do horário: cancela, mas não conclui nem registra falta', () {
      final a = em(marcado);
      final diaAnterior = DateTime(2026, 8, 19, 18, 0);
      expect(a.podeCancelar(diaAnterior), isTrue);
      expect(a.podeFinalizar(diaAnterior), isFalse);
      expect(a.podeRegistrarFalta(diaAnterior), isFalse);
    });

    test('no dia, antes do horário: já pode concluir (cliente adiantado)', () {
      final a = em(marcado);
      final cedo = DateTime(2026, 8, 20, 9, 30);
      expect(a.podeFinalizar(cedo), isTrue);
      expect(a.podeCancelar(cedo), isTrue);
      expect(a.podeRegistrarFalta(cedo), isFalse);
    });

    test('depois do horário: conclui ou registra falta, não cancela', () {
      final a = em(marcado);
      final depois = DateTime(2026, 8, 20, 11, 0);
      expect(a.podeFinalizar(depois), isTrue);
      expect(a.podeRegistrarFalta(depois), isTrue);
      expect(a.podeCancelar(depois), isFalse);
      expect(a.aguardandoConclusao(depois), isTrue);
    });

    test('encerrado não aceita mais nenhuma ação', () {
      final depois = DateTime(2026, 8, 21);
      for (final status in [
        StatusAgendamento.finalizado,
        StatusAgendamento.cancelado,
        StatusAgendamento.faltou,
      ]) {
        final a = em(marcado, status);
        expect(a.podeCancelar(depois), isFalse, reason: status.name);
        expect(a.podeFinalizar(depois), isFalse, reason: status.name);
        expect(a.podeRegistrarFalta(depois), isFalse, reason: status.name);
      }
    });

    test('falta tem valor e rótulo próprios', () {
      expect(StatusAgendamento.faltou.dbValue, 'faltou');
      expect(StatusAgendamento.faltou.label, 'Não compareceu');
      expect(StatusAgendamentoX.fromDb('faltou'), StatusAgendamento.faltou);
    });
  });
}
