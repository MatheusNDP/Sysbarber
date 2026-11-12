import 'package:sysbarber/models/models.dart';
import 'package:sysbarber/services/database_service.dart';
import 'package:sysbarber/services/senhas.dart';

/// Ponto de partida dos testes: os 3 barbeiros e os 5 serviços que a
/// configuração inicial criava com "Começar com dados de exemplo". A opção
/// saiu do app (a barbearia começa vazia), mas os testes continuam contando
/// com estes ids, nomes, e-mails e preços.

/// Senha de acesso dos barbeiros de teste.
const senhaBarbeirosDeTeste = 'barbeiro123';

/// Ids 1, 2 e 3, nesta ordem. Marcos Lima começa indisponível (regra de
/// negócio 14).
const barbeirosDeTeste = [
  Barbeiro(
    nome: 'Carlos Eduardo',
    especialidade: 'Especialista em barba',
    iniciais: 'CE',
    telefone: '(67) 99101-1001',
    email: 'carlos.eduardo@sysbarber.com',
    salario: 2800.00,
  ),
  Barbeiro(
    nome: 'Rafael Souza',
    especialidade: 'Cortes modernos',
    iniciais: 'RS',
    telefone: '(67) 99202-2002',
    email: 'rafael.souza@sysbarber.com',
    salario: 2500.00,
  ),
  Barbeiro(
    nome: 'Marcos Lima',
    especialidade: 'Coloração e Corte',
    iniciais: 'ML',
    telefone: '(67) 99303-3003',
    email: 'marcos.lima@sysbarber.com',
    salario: 2650.00,
    ativo: false,
  ),
];

/// Ids 1 a 5, nesta ordem.
const servicosDeTeste = [
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

/// Cria os barbeiros e os serviços de teste no banco do [service], ainda
/// sem nenhum, para eles ganharem os ids na ordem das listas.
Future<void> criarBarbeirosEServicosDeTeste(DatabaseService service) async {
  final hashes = await Future.wait([
    for (final _ in barbeirosDeTeste)
      Senhas.gerarHashEmSegundoPlano(senhaBarbeirosDeTeste),
  ]);
  final db = await service.database;
  await db.transaction((txn) async {
    for (var i = 0; i < barbeirosDeTeste.length; i++) {
      await txn.insert(
        'barbeiro',
        barbeirosDeTeste[i].copyWith(senhaHash: hashes[i]).toMap()
          ..remove('id'),
      );
    }
    for (final servico in servicosDeTeste) {
      await txn.insert('servico', servico.toMap()..remove('id'));
    }
  });
}
