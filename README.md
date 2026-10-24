# SysBarber — Sistema de Gestão de Barbearia

Trabalho de Conclusão de Curso — Engenharia de Software.
Aplicativo mobile em **Flutter/Dart** com banco **SQLite local** (sem Firebase) e
autenticação própria com senhas em **PBKDF2-HMAC-SHA256** e salt individual.
Todos os dados ficam no aparelho: o sistema completo funciona em **um aparelho
compartilhado** (veja [Os dados ficam no aparelho](#os-dados-ficam-no-aparelho)).

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
telefone e senha (regra 15) e já entra com ela.

A configuração tem a opção **"Começar com dados de exemplo"**, útil para testar
ou apresentar o app. Marcada, ela cria 5 serviços e 3 barbeiros, que entram com
estas contas e veem só a própria agenda:

| Barbeiro | E-mail de acesso | Senha |
|---|---|---|
| Carlos Eduardo | `carlos.eduardo@sysbarber.com` | `barbeiro123` |
| Rafael Souza | `rafael.souza@sysbarber.com` | `barbeiro123` |
| Marcos Lima | `marcos.lima@sysbarber.com` | `barbeiro123` |

**Marcos Lima começa indisponível**, para demonstrar a regra 14: ele aparece
apagado na escolha do profissional, mas entra no app normalmente. Desmarcada a
opção, a barbearia começa vazia, e o administrador cadastra os próprios
serviços e barbeiros.

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

### Funciona offline

A única requisição de rede do app é o envio do e-mail da recuperação de senha,
quando o EmailJS está configurado. Todo o resto funciona sem internet: o banco
é local (SQLite) e as fontes **Playfair Display** e **DM Sans** estão
embarcadas no APK (`assets/fonts/`, declaradas em `pubspec.yaml`), e não
baixadas em tempo de execução. A identidade visual fica idêntica com ou sem
internet — importante para a apresentação. O SMS da recuperação de senha é
simulado (regra 16). Os botões do [Suporte](#suporte), no Perfil, também não
fazem requisição: só abrem o WhatsApp ou o app de e-mail do aparelho, e são
eles que usam a internet.

### Os dados ficam no aparelho

Não existe servidor. Clientes, barbeiros, serviços, agendamentos, pagamentos e
pontos ficam no arquivo `sysbarber.db`, guardado no próprio aparelho onde o app
está instalado. Isso tem três consequências:

- **Cada instalação é uma barbearia separada.** O banco é criado na primeira
  abertura do app. O mesmo app instalado em dois celulares gera dois
  bancos que não se comunicam: o que é cadastrado num não aparece no outro. O
  cliente que instala o app no próprio celular não vê os barbeiros nem os
  horários cadastrados no aparelho da barbearia.
- **O sistema completo funciona em um aparelho compartilhado**, por exemplo um
  tablet no balcão: clientes, barbeiros e administrador usam o mesmo aparelho,
  cada um entrando com a própria conta. É assim que o app é demonstrado, no
  emulador.
- **Cada pessoa precisa sair da conta ao terminar.** A sessão fica salva, e o
  app reabre direto na última conta usada. Num aparelho compartilhado, quem
  termina toca em **Sair**: o cliente e o administrador no Perfil, o barbeiro
  no ícone de saída da própria agenda.

Levar o app para o celular de cada cliente exige um servidor central, com o
banco na nuvem e sincronização entre os aparelhos. Isso fica fora do escopo
deste trabalho (veja [Limitações conhecidas](#limitações-conhecidas)).

---

## Testes

```bash
flutter test
```

São **274 testes** no total:

| Suíte | Testes | Conteúdo |
|---|---|---|
| `test/unit_test.dart` | 24 | Hash de senha (PBKDF2, vetor da RFC 7914, formato legado), serialização (inclusive do código de nova senha, da origem e da validade dele), enums e regras de estado do agendamento |
| `test/validators_test.dart` | 20 | Validação de cadastro, telefone, barbeiro e cartão (Luhn) |
| `test/formatters_test.dart` | 17 | Máscaras de telefone, moeda e cartão (até 19 dígitos, Amex), `formatarReal`, `mascararTelefone` e `mascararEmail` (de `common_widgets.dart`) |
| `test/erros_test.dart` | 3 | Mensagens de erro sem detalhes técnicos |
| `test/email_test.dart` | 5 | Envio do código por e-mail: a chamada à API do EmailJS (contra um servidor local), recusa e falta de conexão, e-mail simulado e o simulado como padrão sem a chave no build |
| `test/suporte_test.dart` | 5 | Suporte do Perfil: formato do contato, mensagem pronta, links do WhatsApp e do e-mail (sem "+" no lugar dos espaços) e o link que não abre |
| `test/telas_test.dart` | 43 | Telas: primeira abertura e configuração inicial, login sem credenciais à mostra, recuperação de senha (por e-mail e por SMS, simulados, entrada com o código da barbearia e liberação pelo administrador), carregamento, erro com "tentar novamente" em todas as telas que carregam dados, layout com fonte grande e nomes longos, acessibilidade, avisos de desistência num resgate, o termo "Concluído", a régua de dias, a agenda geral do administrador, os textos do pagamento na barbearia, o Suporte no fim do Perfil (cliente e administrador, WhatsApp e e-mail com a mensagem pronta, aviso sem app e celular pequeno) e ajustes visuais em celular pequeno |
| `integration_test/database_integration_test.dart` | 157 | Configuração inicial, CRUD, agenda (dias, turnos e janela de 14 dias), agenda geral, reserva, pagamentos, cancelamento, fidelidade, relatórios, recuperação de senha por SMS e por e-mail, sessão, permissões e migrações |

Os testes de integração usam **SQLite em memória** (`sqflite_common_ffi`), então
cada caso roda isolado, sem tocar no banco real do aparelho. Rodam com as
mesmas configurações do aparelho (chaves estrangeiras ligadas) e com menos
iterações de PBKDF2, só para a suíte ser rápida — o formato do hash é o mesmo.

O Flutter não executa `test/` e `integration_test/` na mesma invocação, então
`test/database_integration_test.dart` apenas reexporta a suíte de integração —
assim um único `flutter test` roda os 274 testes. Para rodar a suíte de
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
│   ├── validators.dart          # Regras de validação (puras, testáveis)
│   ├── formatters.dart          # Máscaras de entrada (telefone, moeda, cartão, validade e CVV)
│   ├── erros.dart               # Tradução de exceções em mensagens ao usuário
│   └── booking_flow.dart        # Rascunho do agendamento em andamento
├── widgets/common_widgets.dart  # Componentes reutilizáveis e formatação de valores e datas (formatarReal etc.)
└── screens/                     # 20 telas (uma por arquivo)
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
  mudar as telas nem o banco.
- **Injeção de dependência para teste** — `injetarBancoParaTeste()` troca o
  banco real por um em memória, e `criarSchema()`/`configurar()` são
  reaproveitados pelos testes. O Perfil recebe quem abre os links do Suporte
  (`abrirLink`, que por padrão usa o pacote `url_launcher`), e os testes o
  trocam por um falso.

---

## Banco de dados

8 tabelas relacionais criadas automaticamente, vazias, na primeira execução
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
```

`codigo_senha` guarda os códigos para criar uma senha nova (regra 16): cada
um é de um cliente ou de um barbeiro, e cada conta tem no máximo um.

Versão atual do schema: **v6**. Um banco de qualquer versão anterior é
migrado sem perder dados (há testes que partem de um banco montado no formato
v2):

| Versão | Mudança |
|---|---|
| v2 | Barbeiro com contato, acesso e salário; pagamento com tipo e cartão mascarado |
| v3 | Marca de administrador. A migração não promove nem cria ninguém: sem administrador, o app pede a configuração inicial |
| v4 | Disponibilidade do barbeiro para novos agendamentos |
| v5 | Natureza do pagamento (serviço, multa, estorno, resgate); duração e preço registrados no agendamento; índice único por barbeiro e horário; e-mail de barbeiro único; índices de consulta. Os dois índices únicos só são criados se o banco antigo não tiver duplicados; sem eles, a reserva e o cadastro de barbeiro continuam conferindo no app |
| v6 | Tabela `codigo_senha`, com os códigos da recuperação de senha |

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
10. O administrador cadastra, edita e exclui serviços e barbeiros, liga e
    desliga a disponibilidade dos barbeiros e consulta os clientes (sem
    editar os dados deles), podendo liberar uma nova senha para quem a
    esqueceu (regra 16). Serviço ou barbeiro com agendamentos não pode ser
    excluído: os atendimentos sumiriam do histórico dos clientes.
11. Senhas nunca são armazenadas em texto puro — PBKDF2 com salt individual.
    O mesmo vale para os códigos da recuperação de senha (regra 16).
12. E-mail é único no sistema: não se repete entre clientes, entre barbeiros
    nem entre um cliente e um barbeiro. No banco, cada tabela tem o próprio
    índice único; o cruzamento entre as duas é conferido pelo app no cadastro
    e pelo banco na configuração inicial.
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
    - **pela barbearia:** o cliente pede no balcão, e o administrador, no
      detalhe do cliente em Gerenciar Clientes, libera um código provisório,
      que vale por 24 horas. O cliente entra com o e-mail e esse código no
      lugar da senha e é obrigado a criar uma senha nova antes de usar o
      app; o administrador não fica sabendo dela. Os códigos do e-mail e do
      SMS não servem para entrar pelo login.

    Os códigos valem uma vez só e são cancelados depois de 5 tentativas
    erradas. Cada conta tem no máximo um código valendo: um novo, de
    qualquer canal, substitui o anterior. Se o e-mail não sai (sem internet,
    por exemplo), o código é descartado. O banco confere tudo isso. O barbeiro também pode receber uma
    senha nova do administrador, em Gerenciar Barbeiros.

---

## Segurança

- **Senhas:** PBKDF2-HMAC-SHA256, 50 mil iterações, salt aleatório de 16 bytes
  por conta, comparação em tempo constante. No login, no cadastro, na
  configuração inicial, na troca e na recuperação de senha e no cadastro de
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
- **EmailJS:** o app leva só a chave pública, que fica fora do Git e entra no
  build. O texto do e-mail está no modelo da conta do EmailJS, então quem
  extrair a chave do APK só consegue disparar esse mesmo e-mail com código,
  até gastar a cota da conta.
- **Permissões:** toda rota nomeada passa por `AuthService.podeAcessar` antes
  de ser construída. Antes da configuração inicial, só a abertura e a
  configuração abrem; depois dela, a configuração não abre mais. `/admin` só abre para o administrador; o barbeiro só
  acessa a própria agenda; o resto mostra "Acesso restrito". As telas do
  administrador abrem a partir do `/admin`, e a agenda geral confere de novo
  se quem está logado é o administrador.
- **Sessão:** guarda só o id e o tipo de conta (cliente ou barbeiro); os dados
  são sempre relidos do banco, e uma conta excluída perde a sessão salva.
- **Dados sensíveis:** do cartão só ficam os 4 últimos dígitos; a agenda do
  barbeiro e a agenda geral não carregam o hash da senha dos clientes;
  mensagens de erro não mostram detalhes técnicos (esses vão só para o log).

---

## Telas

| Rota | Tela | Quem acessa |
|---|---|---|
| `/` | Splash — entra direto se houver sessão salva; na primeira abertura, leva à configuração da barbearia | todos |
| `/configuracao` | Configuração inicial: cria o administrador e, se marcado, os dados de exemplo | só antes de existir o administrador |
| `/login` | Login, com "Esqueci minha senha" | todos |
| `/recuperar-senha` | Esqueci minha senha: e-mail da conta e a escolha entre receber o código por e-mail ou por SMS (com o celular), o e-mail ou SMS simulado quando for o caso, e a senha nova. Também abre direto na senha nova para quem entra com o código da barbearia | todos |
| `/cadastro` | Criar conta (já entra logado) | todos |
| `/home` | Início — próximo horário, pontos, acesso rápido | cliente |
| `/servicos` | Catálogo de serviços | cliente |
| `/barbeiro` | Escolha do profissional (indisponível aparece apagado, sem seleção) | cliente |
| `/horario` | Escolha de data (próximos 14 dias, sem domingos) e horário disponível | cliente |
| `/confirmacao` | Revisão do agendamento (confere o horário, não grava) | cliente |
| `/pagamento` | Pagamento (Pix / Cartão / na barbearia / pontos) — grava a reserva | cliente |
| `/agendamentos` | Meus agendamentos (cliente) ou Minha agenda (barbeiro) | cliente e barbeiro |
| `/fidelidade` | Pontos e histórico | cliente |
| `/perfil` | Dados do usuário, editar dados, alterar senha, sair e, no fim, o [Suporte](#suporte) (WhatsApp e e-mail) | cliente |
| `/admin` | Painel administrativo: movimento de hoje (agendamentos, barbeiros, clientes e serviços, com o total geral como referência) e acesso às telas abaixo | administrador |

Antes da configuração inicial, só `/` e `/configuracao` abrem; as demais rotas
mostram "Acesso restrito".

Telas abertas a partir do painel administrativo (só o administrador chega a
elas):

| Tela | O que faz |
|---|---|
| Agenda geral | Todos os atendimentos, de todos os barbeiros, com as ações da barbearia: receber, concluir, registrar falta e cancelar (sem multa) |
| Gerenciar Serviços | Cadastrar, editar e excluir serviços |
| Gerenciar Barbeiros | Cadastrar, editar e excluir barbeiros e ligar ou desligar a disponibilidade |
| Gerenciar Clientes | Consulta: busca por nome, e-mail ou telefone e detalhe com agendamentos e pontos. No detalhe, "Liberar nova senha" mostra o código provisório para entregar ao cliente (regra 16) |
| Relatórios | Faturamento líquido, a receber, ticket médio, folha salarial, resultado do mês (só nos recortes mensais), total de agendamentos e por status (confirmados, cancelados, concluídos e faltas), clientes, pontos em circulação e rankings: formas de pagamento, 5 serviços mais procurados e 5 barbeiros mais requisitados. Recortes: este mês, mês passado ou tudo |

Outras telas: **Acesso restrito**, mostrada no lugar de qualquer tela que o
perfil logado não pode abrir; e a tela de **falha ao abrir o banco** na
inicialização, com "Tentar novamente".

Toda tela que carrega dados mostra um estado de erro com
**"Tentar novamente"** quando o banco falha, em vez de um carregamento eterno.
No pagamento, se só o saldo de pontos não carregar, o aviso aparece no lugar
da oferta de resgate e o pagamento em dinheiro continua disponível.

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

O Suporte aparece para o cliente e para o administrador. O barbeiro não tem
Perfil: se tiver algum problema, ele fala com o administrador.

---

## Fluxo principal

Primeiro acesso (uma vez só, em cada instalação):

```
Abertura → Configurar barbearia → Início, já como administrador
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

Gerenciar Clientes → Liberar nova senha → código provisório, entregue no balcão
Login com o e-mail e o código → Crie sua nova senha → entra no app
```

---

## Limitações conhecidas

- Não há servidor: os dados não são compartilhados entre aparelhos, e cada
  instalação é uma barbearia separada. O sistema completo funciona em um
  aparelho compartilhado (veja
  [Os dados ficam no aparelho](#os-dados-ficam-no-aparelho)). Para clientes e
  barbearia usarem aparelhos diferentes, seria preciso um servidor central com
  sincronização — trabalho futuro.
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
  nova senha para o cliente, ou define uma para o barbeiro.
- Não há troca de e-mail nem exclusão de conta pelo próprio cliente.
- O build de release ainda é assinado com a chave de debug (é preciso criar
  um keystore próprio antes de publicar).
- Instalações feitas antes da configuração inicial mantêm a conta de
  administrador criada na época (`admin@sysbarber.com`, com a senha
  `admin1234` se ela não foi trocada no Perfil). Para configurar do zero, é
  preciso desinstalar e instalar o app de novo.
