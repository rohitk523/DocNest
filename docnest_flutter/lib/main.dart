// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/document_provider.dart';
import 'services/auth_service.dart';
import 'utils/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.initialize();

  final authService = AuthService();
  final String? token = await authService.getStoredToken();
  final bool isValidSession = await authService.isLoggedIn();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(token: token ?? ''),
        ),
      ],
      child: MyApp(isLoggedIn: isValidSession, token: token),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? token;

  const MyApp({
    Key? key,
    required this.isLoggedIn,
    this.token,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocNest',
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? HomeScreen(token: token!) : const LoginScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/DocNest.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
