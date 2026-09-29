import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/acesso_negado_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/agendamentos_screen.dart';
import 'screens/barbeiro_screen.dart';
import 'screens/cadastro_screen.dart';
import 'screens/confirmacao_screen.dart';
import 'screens/fidelidade_screen.dart';
import 'screens/home_screen.dart';
import 'screens/horario_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pagamento_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/servicos_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Erros não tratados vão para o log em vez de sumirem em silêncio.
  FlutterError.onError = (detalhes) {
    FlutterError.presentError(detalhes);
    developer.log(
      'Erro na interface',
      name: 'sysbarber',
      error: detalhes.exception,
      stackTrace: detalhes.stack,
    );
  };
  PlatformDispatcher.instance.onError = (erro, pilha) {
    developer.log(
      'Erro não tratado',
      name: 'sysbarber',
      error: erro,
      stackTrace: pilha,
    );
    return true;
  };

  // Necessário para DateFormat com locale pt_BR.
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (_) {
    // Sem os dados de locale o app segue com a formatação padrão.
  }

  await iniciar();
}

/// Abre o banco, restaura a sessão e sobe o app.
///
/// Se o banco não abrir (disco cheio, migração que falhou...), o usuário vê
/// uma tela explicando e pode tentar de novo — antes o app morria antes de
/// desenhar qualquer coisa.
Future<void> iniciar() async {
  try {
    // Abre (e na primeira execução cria + popula) o banco.
    await DatabaseService.instance.database;
  } catch (erro, pilha) {
    developer.log(
      'Falha ao abrir o banco',
      name: 'sysbarber',
      error: erro,
      stackTrace: pilha,
    );
    runApp(const _FalhaAoIniciarApp());
    return;
  }

  // Restaura a sessão salva para manter o usuário logado entre execuções.
  await AuthService.instance.carregarSessao();

  runApp(const SysBarberApp());
}

class _FalhaAoIniciarApp extends StatelessWidget {
  const _FalhaAoIniciarApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysBarber',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: const Scaffold(
        body: SafeArea(
          child: EstadoErro(
            mensagem:
                'Não foi possível abrir os dados do aplicativo. Verifique o '
                'espaço disponível no aparelho e tente novamente.',
            onTentarNovamente: iniciar,
          ),
        ),
      ),
    );
  }
}

class SysBarberApp extends StatelessWidget {
  const SysBarberApp({super.key});

  static final Map<String, WidgetBuilder> _telas = {
    '/': (_) => const SplashScreen(),
    '/login': (_) => const LoginScreen(),
    '/cadastro': (_) => const CadastroScreen(),
    '/home': (_) => const HomeScreen(),
    '/servicos': (_) => const ServicosScreen(),
    '/barbeiro': (_) => const BarbeiroScreen(),
    '/horario': (_) => const HorarioScreen(),
    '/confirmacao': (_) => const ConfirmacaoScreen(),
    '/agendamentos': (_) => const AgendamentosScreen(),
    '/pagamento': (_) => const PagamentoScreen(),
    '/fidelidade': (_) => const FidelidadeScreen(),
    '/admin': (_) => const AdminScreen(),
    '/perfil': (_) => const PerfilScreen(),
  };

  /// Toda rota passa pela permissão de quem está logado antes de ser
  /// construída — esconder o botão da área administrativa não bastava.
  static Route<void>? _gerarRota(RouteSettings settings) {
    final tela = _telas[settings.name];
    if (tela == null) return null;
    final permitido = AuthService.instance.podeAcessar(settings.name!);
    return MaterialPageRoute<void>(
      settings: settings,
      builder: permitido ? tela : (_) => const AcessoNegadoScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysBarber',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      initialRoute: '/',
      onGenerateRoute: _gerarRota,
    );
  }
}
