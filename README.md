# SysBarber — Sistema de Gestão de Barbearia

Trabalho de Conclusão de Curso — Engenharia de Software.
Aplicativo mobile em **Flutter/Dart** com banco **SQLite local** (sem Firebase) e
autenticação própria com hash **SHA-256**.

---

## Como rodar

Pré-requisitos: Flutter 3.x, Android SDK e um emulador Android.

```bash
flutter pub get
```

```bash
flutter run
```

> **Importante:** o projeto deve ficar em um caminho **sem acentos**
> (ex.: `C:\TCC\sysbarber`). Caminhos como "Área de Trabalho" quebram o
> build do Gradle no Windows.

### Contas do seed

| Perfil | E-mail | Senha | Acesso |
|---|---|---|---|
| Administrador | `admin@sysbarber.com` | `admin1234` | app + área administrativa |
| Barbeiros | `carlos.eduardo@sysbarber.com` (e demais) | `barbeiro123` | painel administrativo |

Contas criadas pelo formulário de cadastro nascem **sempre como cliente
comum** e não enxergam a área administrativa.

### Funciona 100% offline

O app não faz nenhuma requisição de rede. O banco é local (SQLite) e as fontes
**Playfair Display** e **DM Sans** estão embarcadas no APK
(`assets/fonts/`, declaradas em `pubspec.yaml`), e não baixadas em tempo de
execução. A identidade visual fica idêntica com ou sem internet — importante
para a apresentação.

---

## Testes

```bash
flutter test
```

São **63 testes** no total:

| Suíte | Testes | Conteúdo |
|---|---|---|
| `test/unit_test.dart` | 12 | Hash SHA-256, serialização das entidades, enums |
| `test/validators_test.dart` | 20 | Validação de cadastro, barbeiro e cartão (Luhn) |
| `test/formatters_test.dart` | 9 | Máscaras de telefone, moeda e cartão |
| `integration_test/database_integration_test.dart` | 22 | CRUD, JOIN, agenda, pagamentos, fidelidade e relatórios |

Os testes de integração usam **SQLite em memória** (`sqflite_common_ffi`), então
cada caso roda isolado, sem tocar no banco real do aparelho.

O Flutter não executa `test/` e `integration_test/` na mesma invocação, então
`test/database_integration_test.dart` apenas reexporta a suíte de integração —
assim um único `flutter test` roda os 37 testes. Para rodar a suíte de
integração em um dispositivo:

```bash
flutter test integration_test -d emulator-5554
```

Verificação estática:

```bash
flutter analyze
```

---

## Arquitetura

Arquitetura em camadas, com as telas isoladas do acesso a dados:

```
lib/
├── main.dart                    # Inicializa DB, restaura sessão, define rotas
├── theme/app_theme.dart         # Cores, tipografia e tema global
├── models/models.dart           # 7 entidades + 2 enums (toMap/fromMap)
├── services/
│   ├── database_service.dart    # Singleton de acesso ao SQLite (CRUD)
│   ├── auth_service.dart        # Login, cadastro, logout, sessão
│   ├── validators.dart          # Regras de validação (puras, testáveis)
│   └── booking_flow.dart        # Estado temporário do agendamento
├── widgets/common_widgets.dart  # Componentes reutilizáveis
└── screens/                     # 13 telas (uma por arquivo)
```

**Padrões aplicados**

- **Singleton** — `DatabaseService.instance` e `AuthService.instance` garantem
  uma única conexão e uma única sessão em todo o app.
- **Separação de responsabilidades** — nenhuma tela executa SQL; tudo passa
  pela camada de serviços.
- **Serialização toMap/fromMap** — converte entidades ↔ linhas do SQLite.
- **Injeção de dependência para teste** — `injetarBancoParaTeste()` troca o
  banco real por um em memória, e `criarSchema()` é reaproveitado pelos testes.

---

## Banco de dados

7 tabelas relacionais criadas automaticamente na primeira execução
(`sysbarber.db`, no diretório de documentos do app), já populadas com
3 barbeiros, 5 serviços e o cliente demo.

```
cliente ──┬──< agendamento >──── barbeiro
          │         │
          │         └──< pagamento
          │         └──── servico
          ├──── fidelidade
          └──< historico_ponto
```

---

## Regras de negócio

1. Um cliente pode ter vários agendamentos.
2. Um horário já agendado para um barbeiro fica indisponível naquela data —
   **cancelar o agendamento libera o horário de volta**.
3. Todo pagamento é vinculado a um agendamento.
4. Após o pagamento, o cliente ganha pontos equivalentes ao valor pago
   (arredondado).
5. Meta de fidelidade: 500 pontos = 1 serviço gratuito.
6. O administrador pode cadastrar, editar e excluir serviços.
7. Senhas nunca são armazenadas em texto puro — sempre hash SHA-256 com salt.
8. E-mail é único no sistema.

---

## Telas

| Rota | Tela |
|---|---|
| `/` | Splash — entra direto se houver sessão salva |
| `/login` | Login |
| `/cadastro` | Criar conta (já entra logado) |
| `/home` | Início — próximo horário, pontos, acesso rápido |
| `/servicos` | Catálogo de serviços |
| `/barbeiro` | Escolha do profissional |
| `/horario` | Escolha de data e horário disponível |
| `/confirmacao` | Revisão do agendamento |
| `/agendamentos` | Meus agendamentos (Próximos / Histórico) |
| `/pagamento` | Pagamento (Pix / Cartão / Dinheiro) |
| `/fidelidade` | Pontos e histórico |
| `/admin` | Painel administrativo + CRUD de serviços |
| `/perfil` | Dados do usuário e logout |

---

## Fluxo principal

```
Serviços → Barbeiro → Horário → Confirmação → Pagamento → Home
                                     │             │
                            grava agendamento   credita pontos
```
