# SysBarber — Sistema de Gestão de Barbearia

Trabalho de Conclusão de Curso — Engenharia de Software.
Aplicativo mobile em **Flutter/Dart** com banco **SQLite local** (sem Firebase) e
autenticação própria com senhas em **PBKDF2-HMAC-SHA256** e salt individual.

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
| Administrador | `admin@sysbarber.com` | `admin1234` | app do cliente + área administrativa |
| Barbeiros | `carlos.eduardo@sysbarber.com` (e demais) | `barbeiro123` | a própria agenda |

Contas criadas pelo formulário de cadastro nascem **sempre como cliente
comum** e não enxergam a área administrativa. A dica com as credenciais do
administrador aparece na tela de login **só em build de desenvolvimento**
(`kDebugMode`); um APK de release não as exibe.

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

São **174 testes** no total:

| Suíte | Testes | Conteúdo |
|---|---|---|
| `test/unit_test.dart` | 21 | Hash de senha (PBKDF2, vetor da RFC 7914, formato legado), serialização, enums e regras de estado do agendamento |
| `test/validators_test.dart` | 20 | Validação de cadastro, telefone, barbeiro e cartão (Luhn) |
| `test/formatters_test.dart` | 13 | Máscaras de telefone, moeda e cartão (até 19 dígitos, Amex) e `formatarReal` |
| `test/erros_test.dart` | 3 | Mensagens de erro sem detalhes técnicos |
| `test/telas_test.dart` | 7 | Telas: carregamento, erro com "tentar novamente", layout com fonte grande e nomes longos, acessibilidade |
| `integration_test/database_integration_test.dart` | 110 | CRUD, agenda, reserva, pagamentos, cancelamento, fidelidade, relatórios, sessão, permissões e migrações |

Os testes de integração usam **SQLite em memória** (`sqflite_common_ffi`), então
cada caso roda isolado, sem tocar no banco real do aparelho. Rodam com as
mesmas configurações do aparelho (chaves estrangeiras ligadas) e com menos
iterações de PBKDF2, só para a suíte ser rápida — o formato do hash é o mesmo.

O Flutter não executa `test/` e `integration_test/` na mesma invocação, então
`test/database_integration_test.dart` apenas reexporta a suíte de integração —
assim um único `flutter test` roda os 174 testes. Para rodar a suíte de
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
├── main.dart                    # Inicializa DB, restaura sessão, rotas com permissão
├── theme/app_theme.dart         # Cores, tipografia e tema global
├── models/models.dart           # Entidades, enums e regras de estado (toMap/fromMap)
├── services/
│   ├── database_service.dart    # Singleton de acesso ao SQLite (CRUD + transações)
│   ├── auth_service.dart        # Login, cadastro, sessão, perfil e permissões
│   ├── senhas.dart              # Hash PBKDF2 com salt individual
│   ├── validators.dart          # Regras de validação (puras, testáveis)
│   ├── formatters.dart          # Máscaras de entrada (telefone, moeda, cartão)
│   ├── erros.dart               # Tradução de exceções em mensagens ao usuário
│   └── booking_flow.dart        # Rascunho do agendamento em andamento
├── widgets/common_widgets.dart  # Componentes reutilizáveis
└── screens/                     # 18 telas (uma por arquivo)
```

**Padrões aplicados**

- **Singleton** — `DatabaseService.instance` e `AuthService.instance` garantem
  uma única conexão e uma única sessão em todo o app.
- **Separação de responsabilidades** — nenhuma tela executa SQL; tudo passa
  pela camada de serviços. As regras de estado (cancelar, concluir, registrar
  falta) ficam no modelo `Agendamento` e valem igualmente para a tela e para o
  banco.
- **Transações** — toda operação com mais de uma escrita (reserva,
  cancelamento, confirmação de pagamento, resgate, cadastro) acontece numa
  única transação: ou tudo é gravado, ou nada é. O saldo de pontos é movido com
  `UPDATE ... SET pontos = pontos + ?`, sem ler-somar-gravar.
- **Serialização toMap/fromMap** — converte entidades ↔ linhas do SQLite.
- **Injeção de dependência para teste** — `injetarBancoParaTeste()` troca o
  banco real por um em memória, e `criarSchema()`/`configurar()` são
  reaproveitados pelos testes.

---

## Banco de dados

7 tabelas relacionais criadas automaticamente na primeira execução
(`sysbarber.db`, no diretório de documentos do app), já populadas com
3 barbeiros, 5 serviços e a conta administradora.

```
cliente ──┬──< agendamento >──── barbeiro
          │         │
          │         └──< pagamento
          │         └──── servico
          ├──── fidelidade
          └──< historico_ponto
```

Versão atual do schema: **v5**. Um banco de qualquer versão anterior é
migrado sem perder dados (há teste que parte de um banco v2 real):

| Versão | Mudança |
|---|---|
| v2 | Barbeiro com contato, acesso e salário; pagamento com tipo e cartão mascarado |
| v3 | Marca de administrador — a conta demo vira a administradora, sem nunca promover um cliente comum |
| v4 | Disponibilidade do barbeiro para novos agendamentos |
| v5 | Natureza do pagamento (serviço, multa, estorno, resgate); duração e preço registrados no agendamento; índice único por barbeiro e horário; e-mail de barbeiro único; índices de consulta |

---

## Regras de negócio

1. Um cliente pode ter vários agendamentos — mas não dois ao mesmo tempo.
2. Um horário só é oferecido se **o serviço inteiro cabe** sem invadir outro
   atendimento do barbeiro (uma Coloração de 60 min às 09:00 bloqueia 09:30).
   Cancelar libera o horário de volta.
3. O agendamento só é gravado **junto com o pagamento**, numa única
   transação: quem desiste no meio do caminho não deixa horário ocupado.
4. Todo pagamento é vinculado a um agendamento, e cada agendamento tem no
   máximo um pagamento de serviço valendo.
5. Pontos acompanham dinheiro que entrou: o pagamento antecipado pontua na
   hora; o "pagar na barbearia", só quando o profissional confirma o
   recebimento. Multa é receita, mas **não gera pontos**.
6. Meta de fidelidade: 500 pontos = 1 serviço gratuito.
7. Cancelamento com menos de 1 hora de antecedência retém 50% do valor como
   multa; cancelamento feito pela barbearia é sempre sem multa. Os pontos do
   serviço cancelado são revertidos **por inteiro**, mesmo que o saldo fique
   negativo.
8. O desfecho de um atendimento é um só: **cancelado** (antes do horário),
   **concluído** (a partir do dia marcado, inclusive depois do horário) ou
   **não compareceu** (depois do horário, com multa). Encerrado, não aceita
   mais nenhuma ação.
9. Preço e duração ficam registrados no agendamento: reajustar um serviço não
   muda multa nem histórico de quem já marcou.
10. O administrador pode cadastrar, editar e excluir serviços e barbeiros.
11. Senhas nunca são armazenadas em texto puro — PBKDF2 com salt individual.
12. E-mail é único no sistema (clientes e barbeiros).

---

## Segurança

- **Senhas:** PBKDF2-HMAC-SHA256, 50 mil iterações, salt aleatório de 16 bytes
  por conta, comparação em tempo constante. O hash é calculado em outro
  isolate, sem travar a tela. Hashes do formato antigo (SHA-256 com salt fixo)
  ainda entram e são **regravados no formato novo no primeiro login**.
- **Permissões:** toda rota passa por `AuthService.podeAcessar` antes de ser
  construída. `/admin` só abre para o administrador; o barbeiro só acessa a
  própria agenda; o resto mostra "Acesso restrito".
- **Sessão:** guarda só o id e o tipo de conta (cliente ou barbeiro); os dados
  são sempre relidos do banco, e uma conta excluída perde a sessão salva.
- **Dados sensíveis:** do cartão só ficam os 4 últimos dígitos; a agenda do
  barbeiro não carrega o hash da senha dos clientes; mensagens de erro não
  mostram detalhes técnicos (esses vão só para o log).

---

## Telas

| Rota | Tela | Quem acessa |
|---|---|---|
| `/` | Splash — entra direto se houver sessão salva | todos |
| `/login` | Login | todos |
| `/cadastro` | Criar conta (já entra logado) | todos |
| `/home` | Início — próximo horário, pontos, acesso rápido | cliente |
| `/servicos` | Catálogo de serviços | cliente |
| `/barbeiro` | Escolha do profissional | cliente |
| `/horario` | Escolha de data e horário disponível | cliente |
| `/confirmacao` | Revisão do agendamento (confere o horário, não grava) | cliente |
| `/pagamento` | Pagamento (Pix / Cartão / na barbearia / pontos) — grava a reserva | cliente |
| `/agendamentos` | Meus agendamentos (cliente) ou Minha agenda (barbeiro) | cliente e barbeiro |
| `/fidelidade` | Pontos e histórico | cliente |
| `/perfil` | Dados do usuário, editar dados, alterar senha e sair | cliente |
| `/admin` | Painel administrativo, CRUDs e relatórios por período | administrador |

Toda tela que carrega dados mostra um estado de erro com
**"Tentar novamente"** quando o banco falha, em vez de um carregamento eterno.

---

## Fluxo principal

```
Serviços → Barbeiro → Horário → Confirmação → Pagamento → Home
                                     │             │
                              confere o horário    grava agendamento + pagamento
                              (não grava nada)     na mesma transação e credita
                                                   os pontos (se pago agora)
```

---

## Limitações conhecidas

- Valores em dinheiro são `REAL` no SQLite; multa e estorno são arredondados
  para centavos, mas a migração completa para centavos inteiros não foi feita.
- A grade de horários é fixa no código (`DatabaseService.horariosBase`), sem
  dias de folga configuráveis.
- Pix e cartão são simulados: nenhum valor é cobrado de verdade.
- Não há recuperação de senha nem exclusão de conta pelo próprio cliente.
- O build de release ainda é assinado com a chave de debug (é preciso criar
  um keystore próprio antes de publicar).
