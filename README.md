# SysBarber — Sistema de Gestão de Barbearia

Aplicativo mobile em **Flutter / Dart** para TCC em Engenharia de Software.

---

## 🚀 INSTRUÇÕES RÁPIDAS (3 PASSOS)

### Pré-requisito
Ter o **Flutter SDK** instalado.
👉 https://docs.flutter.dev/get-started/install

Para verificar se está instalado, abra o **CMD** ou **PowerShell** e digite:
```
flutter --version
```

---

### PASSO 1 — Extrair o ZIP
Extraia o conteúdo do ZIP em uma pasta de sua escolha (ex: `C:\TCC\sysbarber`).

### PASSO 2 — Rodar o script de configuração
No terminal, dentro da pasta do projeto, rode os comandos:
```bash
flutter pub get
flutter run
```

### PASSO 3 — Abrir no Android Studio
1. Abra o **Android Studio**
2. Clique em **Open** e selecione a pasta `sysbarber`
3. Aguarde a indexação terminar
4. Selecione seu emulador na barra superior
5. Clique no botão **Run ▶** (verde)

🎉 **Pronto! O app vai rodar.**

---

## 🎬 Roteiro de Demonstração para a Banca

1. App abre na **Tela Inicial** (logo BarberApp dourado)
2. Clique em **ENTRAR** — credenciais já preenchidas
3. Veja a **Home** com o próximo agendamento
4. **Ver Serviços** → "Corte + Barba" → **Agendar**
5. Selecione um barbeiro → **CONTINUAR**
6. Escolha data e horário → **CONFIRMAR**
7. Revise os dados → **CONFIRMAR AGENDAMENTO**
8. Escolha Pix → **CONFIRMAR PAGAMENTO**
9. Veja a confirmação com pontos de fidelidade
10. Mostre **Meus Agendamentos**, **Fidelidade** e **Administração**

---

## 📁 Estrutura do Projeto

```
sysbarber/
├── README.md
├── pubspec.yaml                ← Dependências
└── lib/
    ├── main.dart               ← Entrada do app
    ├── theme/app_theme.dart    ← Cores e estilos
    ├── models/models.dart      ← Entidades do banco
    ├── services/mock_data.dart ← Dados mockados
    ├── widgets/                ← Componentes reutilizáveis
    └── screens/                ← 13 telas do sistema
```

---

## 📱 Telas Implementadas

| # | Tela                        | Funcionalidade                              |
|---|-----------------------------|---------------------------------------------|
| 1 | Splash / Tela Inicial       | Logo + botões Entrar/Criar Conta           |
| 2 | Login                       | E-mail e senha (pré-preenchido)            |
| 3 | Cadastro                    | Registro de novo cliente                    |
| 4 | Home                        | Saudação + próximo agendamento + atalhos   |
| 5 | Serviços                    | Lista com preço, duração, botão Agendar    |
| 6 | Seleção de Barbeiro         | Avatar, especialidade, avaliação           |
| 7 | Seleção de Horário          | Calendário + chips de horário              |
| 8 | Confirmação de Agendamento  | Resumo completo                             |
| 9 | Meus Agendamentos           | Abas Próximos/Histórico + cancelar         |
|10 | Pagamento                   | Pix/Cartão/Dinheiro                         |
|11 | Fidelidade                  | Pontos + barra de progresso + histórico    |
|12 | Área Administrativa         | Painel admin com estatísticas              |
| + | Perfil                      | Tela extra de perfil do usuário            |

---

## 🛠️ Tecnologias

- **Flutter** 3.x
- **Dart** 3.x
- **google_fonts** (Playfair Display + DM Sans)
- **intl** (formatação de datas)

---

## 💾 Sobre os Dados

O sistema usa **dados mockados em memória** (`lib/services/mock_data.dart`) para garantir que o app rode em qualquer ambiente, sem precisar configurar Firebase ou banco de dados.

Os dados incluem:
- 1 cliente (João da Silva)
- 5 serviços (Corte, Barba, Combo, Hidratação, Coloração)
- 3 barbeiros (Carlos, Rafael, Marcos)
- 3 agendamentos de exemplo
- 320 pontos de fidelidade

---


---

## 🧪 Testes Automatizados

O projeto inclui testes unitários e de integração para validação de software.

```bash
# Rodar todos os testes
flutter test

# Só testes unitários
flutter test test/

# Só testes de integração
flutter test integration_test/
```

Veja detalhes em `DOCUMENTACAO_TECNICA.md`.

---

## 🗄️ Banco de Dados

O app usa **SQLite** (via `sqflite`) com 7 tabelas: cliente, barbeiro, servico, agendamento, pagamento, fidelidade e historico_ponto. O banco é criado automaticamente na primeira execução, com dados iniciais (3 barbeiros, 5 serviços e 1 cliente demo).

**Conta demo:** `demo@sysbarber.com` / `demo1234`

## 👨‍💻 Autor

**Matheus Nunes de Paula**
TCC — Engenharia de Software — 2026
