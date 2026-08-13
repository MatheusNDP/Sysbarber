# Documentação Técnica — SysBarber

> Documento de apoio para a etapa de **Implementação da Arquitetura, Banco de Dados, Entidades e Testes** do TCC.

---

## 1. Arquitetura do Sistema

O SysBarber utiliza uma **arquitetura em camadas** (Layered Architecture), separando responsabilidades em pastas distintas dentro de `lib/`:

```
lib/
├── main.dart              → Ponto de entrada; inicializa banco e rotas
│
├── models/               → CAMADA DE DOMÍNIO (Entidades)
│   └── models.dart          Define Cliente, Barbeiro, Servico, etc.
│
├── services/             → CAMADA DE NEGÓCIO E DADOS
│   ├── database_service.dart   Acesso ao banco SQLite (Repository)
│   ├── auth_service.dart       Lógica de autenticação/sessão
│   ├── validators.dart         Regras de validação
│   ├── formatters.dart         Máscaras de entrada (telefone, moeda, cartão)
│   └── booking_flow.dart       Estado do fluxo de agendamento
│
├── screens/              → CAMADA DE APRESENTAÇÃO (UI)
│   └── *.dart               As 13 telas do aplicativo + sub-telas do admin
│
├── widgets/              → COMPONENTES REUTILIZÁVEIS
│   └── common_widgets.dart  Botões, cards, avatares padronizados
│
└── theme/                → CONFIGURAÇÃO VISUAL
    └── app_theme.dart       Cores, fontes e estilos globais
```

**Vantagens dessa arquitetura:**
- **Separação de responsabilidades**: a UI não conhece detalhes do banco
- **Testabilidade**: serviços podem ser testados isoladamente
- **Manutenibilidade**: mudanças em uma camada têm impacto reduzido nas outras
- **Reuso**: widgets e serviços compartilhados entre telas

A área administrativa é dividida em sub-telas próprias (`admin_servicos_screen.dart`, `admin_barbeiros_screen.dart`, `admin_clientes_screen.dart`, `admin_relatorios_screen.dart`), mantendo cada arquivo com uma responsabilidade única.

---

## 2. Conexão com o Banco de Dados

O sistema usa **SQLite** (banco relacional local) através do pacote `sqflite`. Não há backend em nuvem: o aplicativo funciona integralmente offline.

A conexão é gerenciada pela classe `DatabaseService` usando o padrão **Singleton**, garantindo uma única instância de conexão durante toda a execução:

```dart
static final DatabaseService instance = DatabaseService._interno();
```

O banco é inicializado em `main.dart` antes do app iniciar, e as tabelas são criadas automaticamente na primeira execução (método `criarSchema`).

### Versionamento do schema

O banco está na **versão 3**. A evolução é feita pelo método `migrar`, acionado pelo `onUpgrade`, que altera as tabelas **sem apagar os dados** de quem já tem o aplicativo instalado:

| Versão | O que mudou |
|--------|-------------|
| v1 | Schema inicial com as 7 tabelas |
| v2 | `barbeiro` ganhou telefone, e-mail, senha e salário; `pagamento` ganhou tipo e cartão mascarado |
| v3 | `cliente` ganhou a marca de administrador |

### Testabilidade

Dois métodos permitem que os testes substituam o banco real por um banco **em memória**:

```dart
void injetarBancoParaTeste(Database db)
Future<void> resetarParaTeste()
```

O método `criarSchema` é público justamente para ser reaproveitado como `onCreate` nos testes.

---

## 3. Entidades e Modelo de Dados

O sistema possui **7 entidades**, cada uma mapeada para uma tabela:

| Entidade | Tabela | Descrição |
|----------|--------|-----------|
| `Cliente` | cliente | Usuários do app (com marca de administrador) |
| `Barbeiro` | barbeiro | Profissionais (com acesso próprio e salário) |
| `Servico` | servico | Serviços oferecidos |
| `Agendamento` | agendamento | Reservas de horário |
| `Pagamento` | pagamento | Pagamentos, antecipados ou na barbearia |
| `Fidelidade` | fidelidade | Saldo de pontos |
| `HistoricoPonto` | historico_ponto | Extrato de pontos |

### Diagrama de Relacionamentos (resumo)

```
cliente (1) ──< (N) agendamento (N) >── (1) barbeiro
                        │
                        │ (1)
                        v
                       (1) servico
                        │
                        │ (1)
                        v
                  pagamento

cliente (1) ──── (1) fidelidade
cliente (1) ──< (N) historico_ponto
```

Cada entidade implementa:
- **`toMap()`** — converte o objeto para um mapa (para inserir no banco)
- **`fromMap()`** — reconstrói o objeto a partir de um registro do banco

Esse padrão é conhecido como **serialização/desserialização** de objetos.

### Segurança das senhas

Nenhuma senha é armazenada em texto puro. Tanto clientes quanto barbeiros têm a senha guardada como **hash SHA-256 com salt**, gerado por `DatabaseService.hashSenha`. Nos pagamentos com cartão, apenas os **4 últimos dígitos** são persistidos.

### Controle de acesso por perfil

| Perfil | Como entra | O que acessa |
|--------|-----------|--------------|
| Cliente | cadastro no app | agendamento, fidelidade, perfil |
| Barbeiro | e-mail e senha cadastrados pelo admin | apenas a própria agenda |
| Administrador | conta marcada com `admin = 1` | painel completo e relatórios |

---

## 4. Validação de Software (Testes)

O projeto possui **69 testes automatizados**, divididos em duas categorias.

### 4.1 Testes Unitários (`test/`)

Testam unidades isoladas de código, sem dependências externas.

| Arquivo | O que testa |
|---------|-------------|
| `unit_test.dart` | Hash de senha, serialização de entidades, enums |
| `validators_test.dart` | Validação de e-mail, nome, telefone, senha, barbeiro e cartão |
| `formatters_test.dart` | Máscaras de telefone, moeda e cartão |

**Exemplos de casos testados:**
- A mesma senha sempre gera o mesmo hash (determinismo)
- Senhas diferentes geram hashes diferentes
- E-mails inválidos são rejeitados
- Conversão objeto → mapa → objeto mantém os dados (ida e volta)
- Números de cartão são validados pelo algoritmo de Luhn
- A máscara de moeda converte centavos e volta sem perder o valor

### 4.2 Testes de Integração (`integration_test/`)

Testam a integração entre múltiplos componentes — neste caso, **Entidades + DatabaseService + SQLite** — usando um banco **em memória** (não afeta os dados reais).

| Arquivo | O que testa |
|---------|-------------|
| `database_integration_test.dart` | Fluxos completos com banco de dados |

**Exemplos de casos testados:**
- Seed inicial cria 3 barbeiros e 5 serviços
- Cadastro de cliente + autenticação com senha correta/incorreta
- Detecção de e-mail duplicado
- Contas criadas pelo app nunca nascem administradoras
- Fluxo completo de agendamento (criar → recuperar com JOIN)
- Cancelamento muda o status corretamente
- **Horário agendado fica indisponível** (regra de negócio)
- **Pagamento pendente não credita pontos**; confirmar credita uma única vez
- Agenda do profissional lista apenas os próprios atendimentos
- Painel do dia conta somente o movimento da data, ignorando cancelados
- Relatórios consolidam faturamento, pendências e rankings
- CRUD completo de serviços e de barbeiros

### 4.3 Rodar todos os testes de uma vez

```bash
flutter test
```

A saída mostrará:
```
00:05 +69: All tests passed!
```

> O Flutter não executa `test/` e `integration_test/` na mesma invocação. Por isso `test/database_integration_test.dart` apenas reexporta a suíte de integração, permitindo que um único `flutter test` rode os 69 testes.

---

## 5. Mapa de Requisitos da Etapa

| Requisito | Status | Onde está |
|-----------|--------|-----------|
| Implementação da Arquitetura | ✅ | Estrutura em camadas em `lib/` |
| Conexão com o Banco de Dados | ✅ | `lib/services/database_service.dart` |
| Criação de Entidades | ✅ | `lib/models/models.dart` |
| Testes Unitários | ✅ | `test/unit_test.dart`, `validators_test.dart`, `formatters_test.dart` |
| Testes de Integração | ✅ | `integration_test/database_integration_test.dart` |
| Migração de Schema | ✅ | `DatabaseService.migrar` (v1 → v3) |
| Controle de Acesso por Perfil | ✅ | `lib/services/auth_service.dart` |

---

**Autor:** Matheus Nunes de Paula
**TCC — Engenharia de Software — 2026**
