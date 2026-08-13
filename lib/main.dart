import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Necessário para DateFormat com locale pt_BR.
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (_) {
    // Sem os dados de locale o app segue com a formatação padrão.
  }

  // Abre (e na primeira execução cria + popula) o banco.
  await DatabaseService.instance.database;

  // Restaura a sessão salva para manter o usuário logado entre execuções.
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
      theme: AppTheme.tema,
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
