// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/document_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get token from secure storage
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(token: token ?? ''),
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

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }

          return Consumer<DocumentProvider>(
            builder: (context, provider, child) {
              if (provider.token != snapshot.data) {
                Future.microtask(() {
                  provider.updateToken(snapshot.data!);
                });
              }
              return HomeScreen(token: snapshot.data!);
            },
          );
        },
      ),
    );
  }
}
