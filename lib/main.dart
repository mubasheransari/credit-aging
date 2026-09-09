import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/background_monitor_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();

  await NotificationService.initialize();

  await configureBackgroundMonitoring();

  if (AuthService.isLoggedIn) {
    await startBackgroundMonitoring();
  }

  runApp(const CreditAgingApp());
}

class CreditAgingApp extends StatelessWidget {
  const CreditAgingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Credit Aging',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService.isLoggedIn) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
