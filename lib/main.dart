import 'package:flutter/material.dart';
import 'services/service_locator.dart';
import 'services/auth_service.dart';
import 'utils/themes.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/audit_logs_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  setupServiceLocator();
  
  final authService = getIt<AuthService>();
  await authService.loadPersistedUsers();
  
  runApp(const BioLockApp());
}

/// Raíz de la aplicación BioLock
class BioLockApp extends StatelessWidget {
  const BioLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BioLock System - Reconocimiento Facial',
      theme: BioLockThemes.darkTheme,
      home: _RootScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/setup': (context) => const SetupScreen(),
        '/login': (context) => const LoginScreen(),
        '/audit': (context) => const AuditLogsScreen(),
      },
    );
  }
}

/// Verifica si hay sesión activa y redirige a la pantalla correspondiente
class _RootScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    
    // Si hay usuarios registrados pero no hay sesión activa, mostrar login
    if (authService.isUserEnrolled && !authService.isLoggedIn) {
      return const LoginScreen();
    }
    
    // Si hay sesión activa, mostrar home
    if (authService.isLoggedIn) {
      return const HomeScreen();
    }
    
    // Si no hay usuarios, mostrar setup (registro)
    return const SetupScreen();
  }
}

