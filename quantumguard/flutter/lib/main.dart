// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/identity_service.dart';
import 'services/offline_service.dart';
import 'screens/auth/splash_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize offline storage
  await OfflineService.instance.init();
  
  runApp(const QuantumGuardApp());
}

class QuantumGuardApp extends StatelessWidget {
  const QuantumGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => IdentityService()),
        ChangeNotifierProvider(create: (_) => OfflineService.instance),
      ],
      child: MaterialApp(
        title: 'QuantumGuard',
        debugShowCheckedModeBanner: false,
        theme: QuantumGuardTheme.light,
        darkTheme: QuantumGuardTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
