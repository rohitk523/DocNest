import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  void _showErrorSnackBar(String message) {
    CustomSnackBar.showError(
      context: context,
      title: 'Error',
      message: message,
      actionLabel: 'Dismiss',
      onAction: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print('Attempting to log in with Google');
      final result = await _authService.loginWithGoogle();
      print('Google login result: $result');
      if (!mounted) return;

      print('Navigating to HomeScreen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(token: result['access_token']),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      print('Error during Google login: $e');
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/DocNest.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.2),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top spacing
                const SizedBox(height: 80),
                // App Title
                const Text(
                  'DocNest',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
                // Flexible space
                const Spacer(),
                // Google Sign In Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    width: double.infinity,
                    height: 48, // Fixed height like Claude's button
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(24), // More rounded corners
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _loginWithGoogle,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google Logo
                              const Image(
                                image: AssetImage(
                                    'assets/images/icons8-google-36.png'),
                              ),
                              const SizedBox(width: 12),
                              // Button Text
                              Text(
                                'Sign in with Google',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48), // Bottom spacing
                // Loading Indicator
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
