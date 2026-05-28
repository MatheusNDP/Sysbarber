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
│   └── booking_flow.dart       Estado do fluxo de agendamento
│
├── screens/              → CAMADA DE APRESENTAÇÃO (UI)
│   └── *.dart               As 13 telas do aplicativo
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

---

## 2. Conexão com o Banco de Dados

O sistema usa **SQLite** (banco relacional local) através do pacote `sqflite`.

A conexão é gerenciada pela classe `DatabaseService` usando o padrão **Singleton**, garantindo uma única instância de conexão durante toda a execução:

```dart
static final DatabaseService instance = DatabaseService._();
```

O banco é inicializado em `main.dart` antes do app iniciar, e as tabelas são criadas automaticamente na primeira execução (método `criarSchema`).

---

## 3. Entidades e Modelo de Dados

O sistema possui **7 entidades**, cada uma mapeada para uma tabela:

| Entidade | Tabela | Descrição |
|----------|--------|-----------|
| `Cliente` | cliente | Usuários do app |
| `Barbeiro` | barbeiro | Profissionais |
| `Servico` | servico | Serviços oferecidos |
| `Agendamento` | agendamento | Reservas de horário |
| `Pagamento` | pagamento | Pagamentos efetuados |
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

---

## 4. Validação de Software (Testes)

O projeto possui duas categorias de testes automatizados.

### 4.1 Testes Unitários (`test/`)

Testam unidades isoladas de código, sem dependências externas.

| Arquivo | O que testa |
|---------|-------------|
| `unit_test.dart` | Hash de senha, serialização de entidades, enums |
| `validators_test.dart` | Validação de e-mail, nome, telefone, senha |

**Exemplos de casos testados:**
- A mesma senha sempre gera o mesmo hash (determinismo)
- Senhas diferentes geram hashes diferentes
- E-mails inválidos são rejeitados
- Conversão objeto → mapa → objeto mantém os dados (ida e volta)

**Como rodar:**
```bash
flutter test test/
```

### 4.2 Testes de Integração (`integration_test/`)

Testam a integração entre múltiplos componentes — neste caso, **Entidades + DatabaseService + SQLite** — usando um banco **em memória** (não afeta os dados reais).

| Arquivo | O que testa |
|---------|-------------|
| `database_integration_test.dart` | Fluxos completos com banco de dados |

**Exemplos de casos testados:**
- Seed inicial cria 3 barbeiros e 5 serviços
- Cadastro de cliente + autenticação com senha correta/incorreta
- Detecção de e-mail duplicado
- Fluxo completo de agendamento (criar → recuperar com JOIN)
- Cancelamento muda o status corretamente
- **Horário agendado fica indisponível** (regra de negócio)
- Sistema de fidelidade acumula pontos e registra histórico
- CRUD completo de serviços (criar, editar, excluir)

**Como rodar:**
```bash
flutter test integration_test/
```

### 4.3 Rodar todos os testes de uma vez

```bash
flutter test
```

A saída mostrará algo como:
```
00:05 +28: All tests passed!
```

---

## 5. Mapa de Requisitos da Etapa

| Requisito | Status | Onde está |
|-----------|--------|-----------|
| Implementação da Arquitetura | ✅ | Estrutura em camadas em `lib/` |
| Conexão com o Banco de Dados | ✅ | `lib/services/database_service.dart` |
| Criação de Entidades | ✅ | `lib/models/models.dart` |
| Testes Unitários | ✅ | `test/unit_test.dart`, `test/validators_test.dart` |
| Testes de Integração | ✅ | `integration_test/database_integration_test.dart` |

---

**Autor:** Matheus Nunes de Paula
**TCC — Engenharia de Software — 2026**
