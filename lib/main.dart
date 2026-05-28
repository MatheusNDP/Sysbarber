import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/cadastro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/servicos_screen.dart';
import 'screens/barbeiro_screen.dart';
import 'screens/horario_screen.dart';
import 'screens/confirmacao_screen.dart';
import 'screens/agendamentos_screen.dart';
import 'screens/pagamento_screen.dart';
import 'screens/fidelidade_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/perfil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Inicializa banco de dados
  await DatabaseService.instance.database;
  // Tenta restaurar sessão
  await AuthService.instance.carregarSessao();

  runApp(const SysBarberApp());
}

class SysBarberApp extends StatelessWidget {
  const SysBarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysBarber',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
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
      },
    );
  }
}
