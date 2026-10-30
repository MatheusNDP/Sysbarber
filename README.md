# SysBarber — Barbearia portátil

Trabalho de Conclusão de Curso — Engenharia de Software.
Aplicativo mobile em **Flutter/Dart** com banco **SQLite local** (sem Firebase) e
autenticação própria com senhas em **PBKDF2-HMAC-SHA256** e salt individual.
O SysBarber é pensado para funcionar **online**, cada pessoa no próprio
celular; neste trabalho, o servidor é **simulado** pelo banco do próprio
aparelho (veja [Pensado para ser online](#pensado-para-ser-online)).

**Por que "portátil":** o SysBarber é 100% mobile, sem versão web: cliente,
barbeiro e administrador fazem tudo pelo celular. É feito para barbearias
pequenas e médias em fase de crescimento, que não têm verba para sistemas
grandes.

---

## Como rodar

Pré-requisitos: Flutter 3.44 ou superior, com Dart 3.12 (versões mínimas
exigidas pelo `pubspec.lock`; testado com o Flutter 3.47.5), Android SDK e um
emulador Android.

```bash
flutter pub get
```

```bash
flutter run
```

> **Importante:** o projeto deve ficar em um caminho **sem acentos**
> (ex.: `C:\TCC\sysbarber`). Caminhos como "Área de Trabalho" quebram o
> build do Gradle no Windows.

### Primeiro acesso

O app não vem com conta de administrador nem senha padrão. Na primeira
abertura o banco está vazio, e a tela inicial leva à **configuração da
barbearia**: o dono cria a conta de administrador com o próprio nome, e-mail,
telefone e senha (regra 15), aceita os termos de uso (regra 18) e já entra
com ela.

A configuração tem a opção **"Começar com dados de exemplo"**, útil para testar
ou apresentar o app. Marcada, ela cria 5 serviços e 3 barbeiros, que entram com
estas contas e veem a própria agenda e o Perfil (regra 17):

| Barbeiro | E-mail de acesso | Senha |
|---|---|---|
| Carlos Eduardo | `carlos.eduardo@sysbarber.com` | `barbeiro123` |
| Rafael Souza | `rafael.souza@sysbarber.com` | `barbeiro123` |
| Marcos Lima | `marcos.lima@sysbarber.com` | `barbeiro123` |

**Marcos Lima começa indisponível**, para demonstrar a regra 14: ele aparece
apagado na escolha do profissional, mas entra no app normalmente. Desmarcada a
opção, a barbearia começa vazia: o administrador cadastra os próprios
serviços e convida os barbeiros (regra 10).

Contas criadas pelo formulário de cadastro nascem **sempre como cliente
comum** e não enxergam a área administrativa.

### Recuperação de senha por e-mail (EmailJS)

O código de "Esqueci minha senha" pode ir por e-mail de verdade, pelo
[EmailJS](https://www.emailjs.com), um serviço feito para enviar e-mail sem
servidor próprio (regra 16). Sem esta configuração, o app funciona do mesmo
jeito, mas o e-mail é **simulado**: a mensagem aparece na própria tela.

1. Crie uma conta grátis no EmailJS e, em **Email Services**, conecte o e-mail
   que vai enviar os códigos (por exemplo, um Gmail da barbearia).
2. Em **Email Templates**, crie um modelo com:
   - **To Email:** `{{to_email}}`
   - **Subject:** `SysBarber: código para criar uma nova senha`
   - **Content:**

     ```
     Olá, {{to_name}}!

     Seu código para criar uma nova senha no SysBarber é {{codigo}}. Ele vale por {{minutos}} minutos e só pode ser usado uma vez.

     Se você não pediu uma nova senha, ignore este e-mail: a sua senha continua a mesma.
     ```

   Na aba **Settings** do modelo, marque **Do not save private data**, para
   os códigos não ficarem guardados no histórico do EmailJS.
3. Em **Account → Security**, ligue **Allow EmailJS API for non-browser
   applications** (sem isso, o EmailJS recusa o app) e desligue **Use Private
   Key**: o app manda só a chave pública.
4. Copie `emailjs.exemplo.json` para `emailjs.json` e preencha o Service ID, o
   Template ID e a Public Key (em **Account → General**). O `emailjs.json`
   está no `.gitignore` e não vai para o repositório.
5. Rode ou gere o APK passando o arquivo:

   ```bash
   flutter run --dart-define-from-file=emailjs.json
   ```

   ```bash
   flutter build apk --dart-define-from-file=emailjs.json
   ```

O app usa só a chave **pública** do EmailJS; nenhuma chave privada vai no
APK.

### Uso da internet

Como o servidor é simulado no aparelho, a única requisição de rede do app é o
envio do e-mail da recuperação de senha, quando o EmailJS está configurado.
Todo o resto funciona sem internet: o banco é local (SQLite) e a fonte
**Montserrat** está embarcada no APK (`assets/fonts/`, declarada em
`pubspec.yaml`), e não baixada em tempo de execução. A identidade visual fica
idêntica com ou sem internet — importante para a apresentação. O SMS da
recuperação de senha é simulado (regra 16). Os botões do [Suporte](#suporte),
no Perfil, também não fazem requisição: só abrem o WhatsApp ou o app de e-mail
do aparelho, e são eles que usam a internet. O lembrete do horário (regra 20) é
uma notificação local, agendada no próprio aparelho, sem internet.

### Pensado para ser online

O SysBarber é pensado para funcionar online: cada pessoa (cliente, barbeiro e
administrador) usa o app no próprio celular, e um servidor central guarda os
dados da barbearia. Neste trabalho o servidor não foi feito: o banco do
próprio aparelho faz o papel dele, simulado, como o Pix, o cartão e o SMS da
recuperação de senha.

Clientes, barbeiros, serviços, agendamentos, pagamentos e pontos ficam no
arquivo `sysbarber.db`, guardado no aparelho onde o app está instalado. Na
prática:

- **Cada instalação é uma barbearia separada.** O banco é criado na primeira
  abertura do app. O mesmo app instalado em dois celulares gera dois bancos
  que não se comunicam: o que é cadastrado num não aparece no outro. Por isso,
  na demonstração (no emulador), clientes, barbeiros e administrador usam o
  mesmo aparelho, cada um entrando com a própria conta.
- **Cada pessoa sai da conta ao terminar.** A sessão fica salva, e o app
  reabre direto na última conta usada. Como na demonstração todos usam o mesmo
  aparelho, quem termina toca em **Sair**, no Perfil (o barbeiro também tem o
  ícone de saída na própria agenda).

O `DatabaseService` é a camada que o servidor substituiria: nenhuma tela
executa SQL, e as regras de negócio são conferidas por ele (veja
[Arquitetura](#arquitetura)). Fazer o servidor, com o banco na nuvem e os
dados compartilhados entre os aparelhos, fica fora do escopo deste trabalho
(veja [Limitações conhecidas](#limitações-conhecidas)).

---

## Testes

```bash
flutter test
```

São **347 testes** no total:

| Suíte | Testes | Conteúdo |
|---|---|---|
| `test/unit_test.dart` | 27 | Hash de senha (PBKDF2, vetor da RFC 7914, formato legado), serialização (inclusive do código de nova senha, da origem e da validade dele, e do convite do barbeiro, com o código digitado), enums, regras de estado do agendamento e os lembretes do horário (2 horas antes, só dos agendamentos em aberto) |
| `test/validators_test.dart` | 21 | Validação de cadastro, telefone, dados e contato do barbeiro e cartão (Luhn) |
| `test/formatters_test.dart` | 19 | Máscaras de telefone, moeda, cartão (até 19 dígitos, Amex) e código do convite, `formatarReal`, `mascararTelefone` e `mascararEmail` (de `common_widgets.dart`) |
| `test/erros_test.dart` | 3 | Mensagens de erro sem detalhes técnicos |
| `test/email_test.dart` | 5 | Envio do código por e-mail: a chamada à API do EmailJS (contra um servidor local), recusa e falta de conexão, e-mail simulado e o simulado como padrão sem a chave no build |
| `test/suporte_test.dart` | 5 | Suporte do Perfil: formato do contato, mensagem pronta, links do WhatsApp e do e-mail (sem "+" no lugar dos espaços) e o link que não abre |
| `test/telas_test.dart` | 67 | Telas: primeira abertura e configuração inicial, login sem credenciais à mostra, recuperação de senha (por e-mail e por SMS, simulados, entrada com o código da barbearia e liberação pelo administrador), carregamento, erro com "tentar novamente" em todas as telas que carregam dados, layout com fonte grande e nomes longos, acessibilidade, avisos de desistência num resgate, o termo "Concluído", a régua de dias, a agenda geral do administrador, os textos do pagamento na barbearia, o Suporte no fim do Perfil (cliente e administrador, WhatsApp e e-mail com a mensagem pronta, aviso sem app e celular pequeno), a escolha do profissional e Gerenciar Barbeiros sem nota dos barbeiros, ajustes visuais em celular pequeno, a barra de navegação fixa (troca de aba e voltar do Android), o ícone do serviço escolhido entre os ícones de linha, as abas e o Perfil do administrador e do barbeiro, os filtros da agenda geral (select de barbeiro e calendário de período), o convite do barbeiro (sheet, mensagem pronta, convites pendentes, outro código, cancelar, fechar pelo voltar e o barbeiro usando o código no login), a edição do barbeiro só com nome, especialidade e salário e a nova senha liberada para ele, o barbeiro trocando o próprio e-mail e telefone, os termos de uso (aceite no cadastro, o texto e o item no Perfil de cada perfil) a exclusão da conta pelo cliente (o que se perde, senha errada e a volta à abertura) e o reagendamento (o botão só até 1 hora antes e só para o cliente, e o caminho profissional → novo horário → confirmação → lista) e o lembrete do horário (a permissão pedida e o lembrete agendado ao reservar, e o lembrete apagado ao cancelar) |
| `integration_test/database_integration_test.dart` | 200 | Configuração inicial, CRUD, aceite dos termos de uso (cadastro, convite e configuração inicial) e exclusão da conta pelo cliente (dados apagados, pontos perdidos, atendimentos mantidos, e-mail livre e a recusa com senha errada, agendamento em aberto ou valor pendente), convite do barbeiro (código, validade de 7 dias, uso único, outro código, cancelamento, e-mail único e os dados conferidos no banco), agenda (dias, turnos e janela de 14 dias), agenda geral, reserva, pagamentos, cancelamento, fidelidade, relatórios, recuperação de senha por SMS e por e-mail (inclusive a nova senha liberada para o barbeiro), sessão, permissões de cada perfil (o administrador não agenda nem conta como cliente, edita só nome, especialidade e salário do barbeiro, e o barbeiro troca a própria senha, o e-mail e o telefone), reagendamento (prazo de 1 hora, só o próprio cliente e o que está em aberto, as regras de uma reserva no novo horário, o próprio horário fora das ocupações, o pagamento e o resgate mantidos), lembretes do horário (ao entrar, ao abrir o app, ao reservar, reagendar e cancelar, ao sair e para barbeiro e administrador) e migrações |

Os testes de integração usam **SQLite em memória** (`sqflite_common_ffi`), então
cada caso roda isolado, sem tocar no banco real do aparelho. Rodam com as
mesmas configurações do aparelho (chaves estrangeiras ligadas) e com menos
iterações de PBKDF2, só para a suíte ser rápida — o formato do hash é o mesmo.

O Flutter não executa `test/` e `integration_test/` na mesma invocação, então
`test/database_integration_test.dart` apenas reexporta a suíte de integração —
assim um único `flutter test` roda os 347 testes. Para rodar a suíte de
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
├── main.dart                    # Inicializa DB, lê configuração e sessão, rotas com permissão
├── theme/app_theme.dart         # Cores, tipografia e tema global
├── models/models.dart           # Entidades, enums e regras de estado (toMap/fromMap)
├── services/
│   ├── database_service.dart    # Singleton de acesso ao SQLite (CRUD + transações)
│   ├── auth_service.dart        # Configuração inicial, login, cadastro, recuperação de senha, sessão, perfil e permissões
│   ├── senhas.dart              # Hash PBKDF2 com salt individual
│   ├── sms.dart                 # Envio de SMS da recuperação de senha (simulado)
│   ├── email.dart               # Envio do código por e-mail: EmailJS ou simulado
│   ├── suporte.dart             # Contato do suporte, mensagem pronta e links do WhatsApp e do e-mail
│   ├── lembretes.dart           # Lembrete do horário: cálculo e notificações locais
│   ├── validators.dart          # Regras de validação (puras, testáveis)
│   ├── formatters.dart          # Máscaras de entrada (telefone, moeda, cartão, validade e CVV)
│   ├── erros.dart               # Tradução de exceções em mensagens ao usuário
│   └── booking_flow.dart        # Rascunho do agendamento (ou do reagendamento) em andamento
├── widgets/common_widgets.dart  # Componentes reutilizáveis e formatação de valores e datas (formatarReal etc.)
└── screens/                     # 22 telas (uma por arquivo)
```

**Padrões aplicados**

- **Singleton** — `DatabaseService.instance` e `AuthService.instance` garantem
  uma única conexão e uma única sessão em todo o app.
- **Separação de responsabilidades** — nenhuma tela executa SQL; tudo passa
  pela camada de serviços. As regras de estado (cancelar, concluir, registrar
  falta) ficam no modelo `Agendamento` e valem igualmente para a tela e para o
  banco.
- **Transações** — toda operação com mais de uma escrita (configuração
  inicial, reserva, cancelamento, confirmação de pagamento, resgate, cadastro,
  pedido e uso do código de nova senha) acontece numa
  única transação: ou tudo é gravado, ou nada é. O saldo de pontos é movido com
  `UPDATE ... SET pontos = pontos + ?`, sem ler-somar-gravar.
- **Serialização toMap/fromMap** — converte entidades ↔ linhas do SQLite.
- **Interfaces para o SMS e o e-mail** — `EnvioSms` e `EnvioEmail` separam o
  envio do resto do app. O SMS é simulado (`SmsSimulado`); o e-mail sai pelo
  EmailJS (`EmailJs`) quando o build traz a chave, ou é simulado
  (`EmailSimulado`). Um provedor novo entra implementando a interface, sem
  mudar as telas nem o banco. O mesmo vale para os lembretes: `Lembretes`
  tem as notificações do aparelho (`LembretesLocais`), e um servidor poderia
  mandar notificações push no lugar delas.
- **Injeção de dependência para teste** — `injetarBancoParaTeste()` troca o
  banco real por um em memória, e `criarSchema()`/`configurar()` são
  reaproveitados pelos testes. O Perfil recebe quem abre os links do Suporte
  (`abrirLink`, que por padrão usa o pacote `url_launcher`), a agenda geral
  recebe quem abre o calendário do período (`escolherPeriodo`, que por padrão
  usa o calendário do Material), e Gerenciar Barbeiros, quem abre o menu de
  compartilhar do convite (`compartilhar`, que por padrão usa o pacote
  `share_plus`); os testes trocam os três por falsos. O `AuthService` recebe os lembretes
  (`lembretes`), que nos testes ficam numa lista (`LembretesEmMemoria`).

---

## Banco de dados

9 tabelas relacionais criadas automaticamente, vazias, na primeira execução
(`sysbarber.db`, no diretório de documentos do app). O administrador e, se o
dono quiser, os dados de exemplo nascem na configuração inicial (veja
[Primeiro acesso](#primeiro-acesso)).

```
cliente ──┬──< agendamento >──── barbeiro ──┐
          │         │                       │
          │         └──< pagamento          │
          │         └──── servico           │
          ├──── fidelidade                  │
          ├──< historico_ponto              │
          └──── codigo_senha ───────────────┘

convite_barbeiro   (vira um barbeiro quando o código é usado)
```

`codigo_senha` guarda os códigos para criar uma senha nova (regra 16): cada
um é de um cliente ou de um barbeiro, e cada conta tem no máximo um.
`convite_barbeiro` guarda os convites que o administrador gera (regra 10):
nome, especialidade, salário, o hash do código e a validade. Ele não se liga
a outra tabela: quando o barbeiro usa o código, o convite é apagado e o
barbeiro entra na tabela `barbeiro`, na mesma transação. `cliente` e
`barbeiro` guardam quando a pessoa aceitou os termos de uso, e `cliente`,
quando a conta foi excluída (regra 18).

Versão atual do schema: **v8**. Um banco de qualquer versão anterior é
migrado sem perder dados (há testes que partem de um banco montado no formato
v2):

| Versão | Mudança |
|---|---|
| v2 | Barbeiro com contato, acesso e salário; pagamento com tipo e cartão mascarado |
| v3 | Marca de administrador. A migração não promove nem cria ninguém: sem administrador, o app pede a configuração inicial |
| v4 | Disponibilidade do barbeiro para novos agendamentos |
| v5 | Natureza do pagamento (serviço, multa, estorno, resgate); duração e preço registrados no agendamento; índice único por barbeiro e horário; e-mail de barbeiro único; índices de consulta. Os dois índices únicos só são criados se o banco antigo não tiver duplicados; sem eles, a reserva e o cadastro de barbeiro continuam conferindo no app |
| v6 | Tabela `codigo_senha`, com os códigos da recuperação de senha |
| v7 | Tabela `convite_barbeiro`, com os convites do barbeiro |
| v8 | Aceite dos termos de uso no cliente e no barbeiro e a exclusão da conta no cliente. Quem já tinha conta fica sem aceite registrado |

---

## Regras de negócio

1. Um cliente pode ter vários agendamentos — mas não dois ao mesmo tempo.
2. A barbearia atende de **segunda a sábado** (domingo não abre), das
   **09:00 às 12:00** e das **13:00 às 18:00**, com horários de 30 em 30
   minutos, e aceita reservas de hoje até 13 dias depois (14 dias, contando
   hoje). Um horário só é oferecido se **o serviço inteiro cabe** no turno e
   sem invadir outro atendimento do barbeiro: uma Coloração de 60 min às 09:00
   bloqueia 09:30 e não é oferecida às 11:30 nem às 17:30. Horários que já
   passaram não aparecem. Cancelar libera o horário de volta. O banco confere
   tudo isso de novo na reserva.
3. O agendamento só é gravado **junto com o pagamento**, numa única
   transação: quem desiste no meio do caminho não deixa horário ocupado.
4. Todo pagamento é vinculado a um agendamento, e cada agendamento tem no
   máximo um pagamento de serviço (ou resgate) valendo: um segundo seria
   cobrança em dobro.
5. Pontos acompanham dinheiro que entrou: cada R$ 1,00 pago vale 1 ponto
   (arredondado). O pagamento antecipado pontua na hora; o "pagar na
   barbearia", só quando a barbearia (barbeiro ou administrador) confirma o
   recebimento. Multa é receita, mas **não gera pontos**.
6. Meta de fidelidade: 500 pontos = 1 serviço gratuito, qualquer que seja o
   preço do serviço. O resgate é feito na etapa de pagamento e exige saldo de
   pelo menos 500 pontos; saldo negativo (depois de um estorno) não libera
   prêmio.
7. Cancelamento com menos de 1 hora de antecedência tem multa de 50% do
   valor; cancelamento feito pela barbearia é sempre sem multa. O acerto
   depende de como o cliente pagou:
   - **pagou antecipado:** o estorno devolve o que não ficou retido como
     multa, e os pontos do serviço são revertidos **por inteiro**, mesmo que o
     saldo fique negativo;
   - **ia pagar na barbearia:** no prazo, a cobrança é cancelada; fora dele, a
     cobrança vira a multa de 50%, pendente, paga no balcão;
   - **pagou com pontos (resgate):** não há multa em dinheiro; os 500 pontos
     voltam se o cancelamento for no prazo ou feito pela barbearia, e são
     perdidos se o cliente cancelar com menos de 1 hora.
8. O desfecho de um atendimento é um só: **cancelado** (só antes do horário;
   depois dele, o banco recusa o cancelamento), **concluído** (a partir do dia
   marcado, inclusive depois do horário) ou **não compareceu** (depois do
   horário, com a mesma penalidade do cancelamento com menos de 1 hora: multa
   ou, num resgate, a perda dos pontos). Encerrado, não aceita mais nenhuma
   ação.
9. Preço e duração ficam registrados no agendamento: reajustar um serviço não
   muda multa nem histórico de quem já marcou.
10. O administrador cadastra, edita e exclui serviços; convida, edita e
    exclui barbeiros e liga e desliga a disponibilidade deles; e consulta os
    clientes (sem editar os dados deles). Ele pode liberar uma nova senha
    para o cliente ou o barbeiro que a esqueceu (regra 16). Serviço ou
    barbeiro com agendamentos não pode ser excluído: os atendimentos
    sumiriam do histórico dos clientes.

    O barbeiro entra pelo **convite**. Em Gerenciar Barbeiros, o
    administrador informa nome, especialidade e salário e recebe um código
    de 8 letras e números (sem 0, O, 1, I e L, que se confundem), que vale
    por 7 dias e uma vez só. Ele envia o código pelo botão Compartilhar, que
    abre o menu do aparelho (WhatsApp ou outro app) com uma mensagem pronta,
    ou o copia. No login, em "Tenho um convite de barbeiro", o barbeiro
    digita o código e cria a conta com e-mail, telefone e senha. Enquanto o
    convite não é usado, ele aparece só em "Convites pendentes", e o cliente
    não pode agendar com ele. Gerar outro código cancela o anterior e conta a
    validade de novo; o convite também pode ser cancelado. Depois, o
    administrador edita só nome, especialidade e salário: o e-mail, o
    telefone e a senha são do barbeiro, que muda o e-mail e o telefone no
    Perfil. O banco confere a validade, o uso único e os dados, e a conta
    nova e o fim do convite acontecem na mesma transação.
11. Senhas nunca são armazenadas em texto puro — PBKDF2 com salt individual.
    O mesmo vale para os códigos da recuperação de senha (regra 16) e do
    convite do barbeiro (regra 10).
12. E-mail é único no sistema: não se repete entre clientes, entre barbeiros
    nem entre um cliente e um barbeiro. No banco, cada tabela tem o próprio
    índice único; o cruzamento entre as duas é conferido pelo banco no
    cadastro do cliente, na configuração inicial, no convite do barbeiro e
    quando o barbeiro troca o e-mail.
13. Confirmar o recebimento (informando Pix, Cartão ou Dinheiro), concluir o
    atendimento e registrar falta são ações da barbearia: o barbeiro faz isso
    na própria agenda, e o administrador, na agenda geral, para qualquer
    barbeiro. O cancelamento feito por um dos dois é sempre sem multa; o
    cliente cancela os próprios agendamentos, seguindo a regra 7.
14. Barbeiro indisponível (o administrador liga e desliga) aparece apagado na
    escolha do profissional, sem poder ser escolhido, não oferece horários e o
    banco recusa reservas com ele. Os atendimentos já marcados continuam
    valendo, e ele segue entrando no app para concluí-los.
15. A barbearia tem **um único administrador**, criado na configuração
    inicial, na primeira abertura do app: o dono escolhe nome, e-mail,
    telefone e senha, e não existe conta nem senha padrão. Enquanto ele não
    existe, só a abertura e a configuração ficam acessíveis; depois, a
    configuração não abre mais, e o banco recusa uma segunda. A opção
    "Começar com dados de exemplo" cria também 3 barbeiros (senha
    `barbeiro123`) e 5 serviços, o que o banco só aceita numa barbearia vazia.
    Não há como promover outro cliente a administrador.
16. Quem esqueceu a senha cria uma nova sem saber a atual, de dois jeitos:
    - **por e-mail ou SMS:** em "Esqueci minha senha", no login, a pessoa
      digita o e-mail da conta (de cliente, do administrador ou de barbeiro)
      e escolhe como receber um código de 6 dígitos, que vale por 10
      minutos. **Por e-mail**, o código vai para esse mesmo e-mail. **Por
      SMS**, ela digita também o celular, e o código só sai se os dois forem
      da mesma conta. Com o código, a pessoa cria a senha nova e já entra.
      Um novo envio, por qualquer dos dois canais, só sai depois de 1
      minuto. O e-mail é enviado de verdade pelo EmailJS quando o build está
      configurado (veja
      [Recuperação de senha por e-mail](#recuperação-de-senha-por-e-mail-emailjs));
      sem isso, ele é simulado. O SMS é sempre simulado, como o Pix e o
      cartão. Simulados, o e-mail e o SMS aparecem na própria tela;
    - **pela barbearia:** a pessoa pede ao administrador, que libera um
      código provisório, válido por 24 horas: para o cliente, no detalhe
      dele em Gerenciar Clientes; para o barbeiro, em Editar barbeiro, em
      Gerenciar Barbeiros. Quem recebe entra com o e-mail e esse código no
      lugar da senha e é obrigado a criar uma senha nova antes de usar o
      app; o administrador não fica sabendo dela. Os códigos do e-mail e do
      SMS não servem para entrar pelo login.

    Os códigos valem uma vez só e são cancelados depois de 5 tentativas
    erradas. Cada conta tem no máximo um código valendo: um novo, de
    qualquer canal, substitui o anterior. Se o e-mail não sai (sem internet,
    por exemplo), o código é descartado. O banco confere tudo isso.
17. Cada perfil vê só as próprias telas (veja [Navegação](#navegação)):
    - **cliente:** agenda, paga, acompanha os próprios agendamentos e os
      pontos (Fidelidade) e mantém os dados no Perfil, onde também pode
      excluir a conta (regra 18);
    - **administrador:** só gerencia a barbearia (painel, agenda geral,
      gerenciar e relatórios) e tem o Perfil. Não agenda serviços nem tem
      pontos ou Fidelidade: o banco recusa a reserva feita pela conta dele.
      Ele também não conta como cliente: fica fora de Gerenciar Clientes e
      das contagens de clientes e de pontos do painel e dos relatórios;
    - **barbeiro:** vê a própria agenda e o Perfil, com os dados dele, a
      troca do próprio e-mail e telefone (regra 10) e da própria senha (o
      banco confere a atual), sem Suporte.
18. **Termos de uso e exclusão da conta** (LGPD):
    - quem cria conta aceita os termos de uso e a política de privacidade:
      o cliente no cadastro, o barbeiro no convite e o administrador na
      configuração inicial. Sem o aceite, o banco não cria a conta, e ele
      guarda quando o aceite aconteceu. O texto fica na tela "Termos e
      privacidade" (`/termos`), aberta pelo "Ler os termos" e pelo Perfil dos
      três perfis. As contas criadas antes dos termos não precisam aceitar;
    - o cliente exclui a própria conta no Perfil, com a senha atual. O banco
      recusa enquanto houver agendamento em aberto ou valor pendente com a
      barbearia (multa de cancelamento tardio ou de falta, ou serviço
      concluído ainda não pago no balcão): quem deve paga antes, como nos
      apps reais. Excluída, a conta perde nome, e-mail, telefone e senha, os
      pontos, o extrato de pontos e os códigos de senha, tudo na mesma
      transação; os atendimentos passados continuam nos relatórios, como
      "Cliente excluído". A conta sai de Gerenciar Clientes e das contagens
      de clientes, não entra mais, e o e-mail fica livre para uma conta nova,
      que começa do zero. O barbeiro continua sendo excluído pelo
      administrador (regra 10), e o administrador não se exclui.
19. O cliente **reagenda** o próprio agendamento até 1 hora antes do horário,
    o mesmo prazo do cancelamento sem multa; com menos de 1 hora, só resta
    cancelar, com a penalidade da regra 7. Ele pode trocar a data, o horário
    e o barbeiro, sem limite de vezes; o serviço não muda. O preço, a duração
    e o pagamento (antecipado, na barbearia ou com pontos) continuam os
    mesmos. O novo horário passa pelas mesmas conferências de uma reserva
    (regras 1, 2 e 14), sem contar o próprio agendamento como ocupado, e não
    pode ser igual ao atual. A barbearia não reagenda: ela cancela (regra
    13). O banco confere tudo isso, numa transação.
20. O cliente recebe um **lembrete** de cada agendamento em aberto, 2 horas
    antes do horário: uma notificação no aparelho, com o serviço, o barbeiro
    e até que horas dá para cancelar ou reagendar sem multa (1 hora antes).
    Quem agenda com menos de 2 horas de antecedência fica sem lembrete. Os
    lembretes são refeitos a partir do banco ao entrar, ao abrir o app e
    depois de reservar, cancelar ou reagendar; sair da conta apaga os
    lembretes dela no aparelho. A permissão de notificação (Android 13 em
    diante) é pedida no primeiro agendamento feito no aparelho. Só o cliente
    recebe: avisar o barbeiro de um agendamento novo precisaria de um
    servidor, porque o aviso sairia de outro celular.

---

## Segurança

- **Senhas:** PBKDF2-HMAC-SHA256, 50 mil iterações, salt aleatório de 16 bytes
  por conta, comparação em tempo constante. No login, no cadastro, na
  configuração inicial, na troca e na recuperação de senha e no convite do
  barbeiro, o hash é calculado em outro isolate, sem travar a tela (só a migração de bancos
  antigos calcula antes de a tela abrir). Hashes
  do formato antigo (SHA-256 com salt fixo) ainda entram e são **regravados
  no formato novo no primeiro login**.
- **Sem senha padrão:** não existe conta de administrador pronta; ela é criada
  pelo dono na configuração inicial (regra 15), e a tela de login não mostra
  credenciais.
- **Recuperação de senha:** os códigos saem de um gerador próprio para
  segredos (`Random.secure`) e são guardados só como hash PBKDF2, como as
  senhas. Valem por tempo limitado e uma vez só, e 5 tentativas erradas os
  cancelam. O e-mail vai só para o endereço da própria conta; o SMS só sai
  quando o e-mail e o celular são da mesma conta; e sai no máximo um código
  por minuto. Liberar uma nova senha confere se quem pede é o administrador.
- **Convite do barbeiro:** o código sai do mesmo gerador para segredos, tem
  8 letras e números e fica guardado só como hash PBKDF2; o administrador o
  vê uma vez, ao gerar. Usar o convite apaga o registro na mesma transação
  que cria a conta, e só se o código ainda for o mesmo e estiver valendo:
  um código trocado, cancelado ou vencido não cria a conta.
- **EmailJS:** o app leva só a chave pública, que fica fora do Git e entra no
  build. O texto do e-mail está no modelo da conta do EmailJS, então quem
  extrair a chave do APK só consegue disparar esse mesmo e-mail com código,
  até gastar a cota da conta.
- **Exclusão da conta:** pede a senha atual. O e-mail da conta excluída vira
  um endereço que não é de ninguém (`excluido-<id>@sysbarber.invalid`) e a
  senha fica vazia, então ninguém entra com ela, e o login recusa a conta
  marcada como excluída.
- **Permissões:** toda rota nomeada passa por `AuthService.podeAcessar` antes
  de ser construída. Antes da configuração inicial, só a abertura, a
  configuração e os termos de uso abrem; depois dela, a configuração não abre mais. A área
  principal (`/home`) e o Perfil abrem para os três perfis, cada um com as
  próprias abas; `/admin` só abre para o administrador; agendar, pagar e a
  Fidelidade, só para o cliente (o administrador não); a lista dos próprios
  agendamentos, para o cliente e o barbeiro (regra 17). O resto mostra
  "Acesso restrito". As telas do administrador abrem a partir do painel, e a
  agenda geral confere de novo se quem está logado é o administrador.
- **Sessão:** guarda só o id e o tipo de conta (cliente ou barbeiro); os dados
  são sempre relidos do banco, e uma conta excluída perde a sessão salva.
- **Dados sensíveis:** do cartão só ficam os 4 últimos dígitos; a agenda do
  barbeiro e a agenda geral não carregam o hash da senha dos clientes;
  mensagens de erro não mostram detalhes técnicos (esses vão só para o log).

---

## Telas

| Rota | Tela | Quem acessa |
|---|---|---|
| `/` | Splash — o nome do app e o slogan, "A barbearia na palma da sua mão"; entra direto se houver sessão salva; na primeira abertura, leva à configuração da barbearia | todos |
| `/configuracao` | Configuração inicial: cria o administrador, com o aceite dos termos, e, se marcado, os dados de exemplo | só antes de existir o administrador |
| `/login` | Login, com "Esqueci minha senha" e "Tenho um convite de barbeiro" | todos |
| `/convite-barbeiro` | Convite de barbeiro: o código que o administrador enviou e, conferido, a conta (e-mail, telefone, senha e o aceite dos termos); já entra na agenda | todos |
| `/recuperar-senha` | Esqueci minha senha: e-mail da conta e a escolha entre receber o código por e-mail ou por SMS (com o celular), o e-mail ou SMS simulado quando for o caso, e a senha nova. Também abre direto na senha nova para quem entra com o código da barbearia | todos |
| `/cadastro` | Criar conta, com o aceite dos termos (já entra logado) | todos |
| `/termos` | Termos de uso e política de privacidade: o que o app guarda, para quê, onde ficam os dados, com quem são compartilhados e os direitos de quem usa (LGPD) | todos, até antes da configuração inicial |
| `/home` | Área principal, com a barra de navegação fixa e as abas do perfil (veja [Navegação](#navegação)). O Início do cliente mostra o próximo horário, os pontos e o acesso rápido | todos os perfis |
| `/servicos` | Catálogo de serviços (também é a aba Serviços) | cliente |
| `/barbeiro` | Escolha do profissional (indisponível aparece apagado, sem seleção). Num reagendamento, o atual vem escolhido, com o aviso "Reagendando o horário de…" | cliente |
| `/horario` | Escolha de data (próximos 14 dias, sem domingos) e horário disponível. Num reagendamento, vira "Novo horário": não oferece o horário atual com o mesmo barbeiro e, confirmado, troca o horário e volta à lista | cliente |
| `/confirmacao` | Revisão do agendamento (confere o horário, não grava) | cliente |
| `/pagamento` | Pagamento (Pix / Cartão / na barbearia / pontos) — grava a reserva e agenda o lembrete; no primeiro agendamento do aparelho, o Android pede a permissão de notificação | cliente |
| `/agendamentos` | Meus agendamentos (cliente) ou Minha agenda (barbeiro); nos dois, também é a aba Agenda. O cliente tem "Reagendar" até 1 hora antes e "Cancelar agendamento" até o horário | cliente e barbeiro |
| `/fidelidade` | Pontos e histórico | cliente |
| `/perfil` | Dados de quem está logado, alterar senha e sair (também é a aba Perfil). O cliente vê ainda os agendamentos e os pontos; o cliente e o administrador editam nome e telefone e têm, no fim, o [Suporte](#suporte) (WhatsApp e e-mail); o barbeiro vê a especialidade e edita o e-mail e o telefone. Todos têm "Termos e privacidade"; o cliente também tem "Excluir minha conta", embaixo do Sair | todos os perfis |
| `/admin` | Painel administrativo (também é a aba Painel): movimento de hoje (agendamentos, barbeiros, clientes e serviços, com o total geral como referência) e acesso às telas abaixo | administrador |

Nas rotas marcadas "cliente", o administrador não entra: ele só gerencia
(regra 17). Antes da configuração inicial, só `/`, `/configuracao` e
`/termos` abrem; as demais rotas mostram "Acesso restrito".

Telas abertas a partir do painel administrativo (só o administrador chega a
elas; a agenda geral e os relatórios também são abas dele):

| Tela | O que faz |
|---|---|
| Agenda geral | Todos os atendimentos, de todos os barbeiros, com as ações da barbearia: receber, concluir, registrar falta e cancelar (sem multa). Dois filtros, que valem para as duas abas (em aberto e histórico): o barbeiro, num select, e o período, de um dia até outro, escolhido no calendário (que vai até o último dia que aceita reserva). O período escolhido aparece embaixo, com o botão de limpar |
| Gerenciar Serviços | Cadastrar, editar e excluir serviços. O ícone do serviço é escolhido entre cinco ícones de linha (corte, barba, combo, hidratação e coloração) |
| Gerenciar Barbeiros | Convidar barbeiros (o + abre um sheet: nome, especialidade e salário, depois o código, com Compartilhar e Copiar código), convites pendentes (gerar outro código e cancelar), editar nome, especialidade e salário, liberar uma nova senha para o barbeiro, excluir e ligar ou desligar a disponibilidade |
| Gerenciar Clientes | Consulta: busca por nome, e-mail ou telefone e detalhe com agendamentos e pontos. No detalhe, "Liberar nova senha" mostra o código provisório para entregar ao cliente (regra 16) |
| Relatórios | Faturamento líquido, a receber, ticket médio, folha salarial, resultado do mês (só nos recortes mensais), total de agendamentos e por status (confirmados, cancelados, concluídos e faltas), clientes, pontos em circulação e rankings: formas de pagamento, 5 serviços mais procurados e 5 barbeiros mais requisitados. Recortes: este mês, mês passado ou tudo |

Outras telas: **Acesso restrito**, mostrada no lugar de qualquer tela que o
perfil logado não pode abrir; e a tela de **falha ao abrir o banco** na
inicialização, com "Tentar novamente".

Toda tela que carrega dados mostra um estado de erro com
**"Tentar novamente"** quando o banco falha, em vez de um carregamento eterno.
No pagamento, se só o saldo de pontos não carregar, o aviso aparece no lugar
da oferta de resgate e o pagamento em dinheiro continua disponível.

### Navegação

A área principal (`/home`) é a mesma para todos os perfis: embaixo fica a
barra de navegação, com as abas de quem entrou (regra 17):

| Perfil | Abas |
|---|---|
| Cliente | Início, Serviços, Agenda (Meus agendamentos) e Perfil |
| Administrador | Painel, Agenda (a agenda geral), Relatórios e Perfil |
| Barbeiro | Agenda (Minha agenda) e Perfil |

Tocar na barra troca a aba sem abrir uma tela nova: a barra continua no lugar
e uma pílula amarela desliza até a aba escolhida, enquanto o conteúdo da aba
nova entra deslizando pelo mesmo lado. Cada aba relê o banco ao ser aberta.
Os atalhos do Início do cliente (Serviços, Agenda e Perfil), o cartão do
próximo horário e o "Agendamentos" do Perfil também trocam de aba, assim como
a Agenda geral e os Relatórios no Painel. Fora da primeira aba, o voltar do
Android volta para ela.

Fidelidade, Gerenciar Serviços, Barbeiros e Clientes e o agendamento
(profissional, horário, revisão e pagamento) abrem por cima, sem a barra, com
o botão de voltar. Ao terminar ou cancelar um agendamento, o app volta para o
Início. Serviços, Meus agendamentos e Perfil abertos pela rota, fora da área
principal (por exemplo, "Resgatar em um agendamento", na Fidelidade), também
vêm por cima, com o botão de voltar.

### Identidade visual

Tema escuro, com fundo grafite e destaque amarelo (`#FFD23F`), e uma fonte
só, a Montserrat (embarcada, licença SIL Open Font License em
`assets/fonts/Montserrat-OFL.txt`). As cores e o tema ficam em
`lib/theme/app_theme.dart`, e os componentes em
`lib/widgets/common_widgets.dart`:

- ícones de linha (Material Icons), muitas vezes dentro de um círculo, no
  lugar de emojis;
- botões em pílula: o principal amarelo e o secundário translúcido;
- botão redondo translúcido para voltar e para as ações da barra do topo
  (como o "+" de Gerenciar Serviços e o sair do barbeiro);
- abas e opções em pílula, com a escolhida em amarelo;
- barra de navegação flutuante e translúcida, na área principal.

O ícone de cada serviço continua gravado no banco como um emoji (os dados de
exemplo usam ✂️, 🪒, 💈, 💆 e 🎨); a tela mostra o ícone de linha
correspondente, e um valor fora dessa lista aparece como a tesoura.

Os textos prontos do Material, como os do calendário e os menus de copiar e
colar, ficam em português: o app usa as traduções do Flutter
(`flutter_localizations`), em pt_BR.

### Suporte

No fim do Perfil, a seção **Suporte** tem os botões **WhatsApp** e
**E-mail**, para falar com o suporte do SysBarber: quem mantém o app, e não a
barbearia. O contato é fixo no código (`ContatoSuporte`, em
`lib/services/suporte.dart`), o mesmo em qualquer instalação: o WhatsApp
(67) 99895-5038 e o e-mail `matheusnunesdepaula33@gmail.com`, do Matheus.
Os botões abrem
o WhatsApp (pelo link `wa.me`; sem o WhatsApp instalado, a página dele no
navegador) ou o app de e-mail do aparelho, já com a mensagem "Olá! Sou
Fulano (cliente) e preciso de ajuda com o SysBarber." (ou "(administrador)")
e, no e-mail, o assunto "Suporte SysBarber". A pessoa pode mudar o texto e é
ela quem envia: o app não manda nada sozinho. Se o aparelho não tem app para
abrir o link, o Perfil avisa (no caso do e-mail, mostrando o endereço).

O Suporte aparece no Perfil do cliente e do administrador. O barbeiro não tem
Suporte: se tiver algum problema, ele fala com o administrador.

---

## Fluxo principal

Primeiro acesso (uma vez só, em cada instalação):

```
Abertura → Configurar barbearia → Painel, já como administrador
               │
               cria o administrador e, se marcado,
               os dados de exemplo (na mesma transação)
```

Agendamento:

```
Serviços → Barbeiro → Horário → Confirmação → Pagamento → Home
                                     │             │
                              confere o horário    grava agendamento + pagamento
                              (não grava nada)     na mesma transação e credita
                                                   os pontos (se pago agora) ou
                                                   debita os 500 do resgate
```

Recuperação de senha (regra 16):

```
Login → Esqueci minha senha → e-mail → por e-mail: código no e-mail (EmailJS)
                                    └→ por SMS: + celular → SMS simulado
                                                       │
                                     código + senha nova → entra no app

Gerenciar Clientes (ou Editar barbeiro) → Liberar nova senha → código provisório
Login com o e-mail e o código → Crie sua nova senha → entra no app
```

Convite do barbeiro (regra 10):

```
Gerenciar Barbeiros → + → nome, especialidade e salário → código → Compartilhar
                                                              │
Login → Tenho um convite de barbeiro → código → e-mail, telefone e senha
                                                              │
                              conta criada e convite gasto na mesma transação
                              → Minha agenda
```

Exclusão da conta (regra 18):

```
Perfil → Excluir minha conta → senha → o banco confere agendamentos em aberto
                                       e valores pendentes
                                              │
                    dados pessoais, pontos e extrato apagados na mesma
                    transação → abertura do app
```

Reagendamento (regra 19):

```
Meus agendamentos → Reagendar (até 1 h antes) → Profissional → Novo horário
                                                                   │
                         confirma "de… para…" → o banco confere o novo horário
                         e troca data e barbeiro → volta à lista
```

---

## Limitações conhecidas

- O servidor central não foi feito: o banco do aparelho faz o papel dele (veja
  [Pensado para ser online](#pensado-para-ser-online)). Os dados não são
  compartilhados entre aparelhos, e cada instalação é uma barbearia separada.
  Para cada pessoa usar o app no próprio celular, falta o servidor, com o
  banco na nuvem — trabalho futuro.
- Valores em dinheiro são `REAL` no SQLite; multa e estorno são arredondados
  para centavos, mas a migração completa para centavos inteiros não foi feita.
- Os dias de funcionamento, os turnos, a grade e a janela de agendamento são
  fixos no código (`DatabaseService.atendeNoDia`, `turnos`, `horariosBase` e
  `diasDeAgenda`), sem feriados nem folgas configuráveis.
- Pix, cartão e o SMS da recuperação de senha são simulados: nenhum valor é
  cobrado de verdade e nenhum SMS sai do aparelho. Um SMS de verdade
  precisa de internet, de um provedor pago e de um servidor que guarde a chave
  do provedor (dentro do APK, ela poderia ser extraída).
- O e-mail da recuperação depende da conta do EmailJS: o plano grátis tem uma
  cota mensal de envios, e a chave pública vai dentro do APK. Com um servidor
  central, o envio sairia dele.
- O celular e o e-mail não são confirmados no cadastro: o código vai para o
  que a pessoa informou, mesmo errado. Nesse caso, o administrador libera uma
  nova senha para o cliente ou para o barbeiro.
- Não há troca de e-mail pelo próprio cliente (o barbeiro troca o dele no
  Perfil).
- O build de release ainda é assinado com a chave de debug (é preciso criar
  um keystore próprio antes de publicar).
- O lembrete usa alarme exato (`USE_EXACT_ALARM`; sem ele, o Android podia
  atrasar o aviso até 1 hora). Para publicar na Google Play, essa permissão
  passa pela avaliação da loja; se o aparelho não permitir alarme exato, o
  lembrete fica inexato. Como os dados ficam no aparelho, o lembrete existe
  só no aparelho em que o cliente está logado, e sair da conta o apaga; com
  um servidor, ele viraria uma notificação enviada pelo servidor.
- O app ainda usa o ícone padrão do Flutter, também nas notificações.
- Instalações feitas antes da configuração inicial mantêm a conta de
  administrador criada na época (`admin@sysbarber.com`, com a senha
  `admin1234` se ela não foi trocada no Perfil). Para configurar do zero, é
  preciso desinstalar e instalar o app de novo.
