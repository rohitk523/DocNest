// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/document_provider.dart';
import 'utils/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.initialize();
  // Get token from secure storage
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token') ?? '';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(token: token),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocNest',
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<String?>(
        future: const FlutterSecureStorage().read(key: 'auth_token'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final token = snapshot.data;

          if (token == null || token.isEmpty) {
            return const LoginScreen();
          }

          // Update DocumentProvider with token
          Future.microtask(() {
            context.read<DocumentProvider>().updateToken(token);
          });

          return HomeScreen(token: token);
        },
      ),
    );
  }
}
