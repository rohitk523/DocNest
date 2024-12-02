// lib/screens/web_login_screen.dart

import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../screens/home_screen.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({Key? key}) : super(key: key);

  @override
  _WebLoginScreenState createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
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
      final result = await _authService.loginWithGoogle();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(token: result['access_token']),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Left side - Image/Background
          if (size.width > 800)
            Expanded(
              child: Container(
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
              ),
            ),

          // Right side - Login content
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 800 ? 64.0 : 32.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo for mobile view
                  if (size.width <= 800)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Image.asset(
                        'assets/images/DocNest.png',
                        height: 100,
                      ),
                    ),

                  // Title and description
                  Text(
                    'Welcome to DocNest',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Secure document management made simple',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Google Sign In Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: _isLoading ? null : _loginWithGoogle,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/icons8-google-36.png',
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sign in with Google',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isLoading) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer links
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFooterLink('Privacy Policy'),
                      const SizedBox(width: 24),
                      _buildFooterLink('Terms of Service'),
                      const SizedBox(width: 24),
                      _buildFooterLink('Help Center'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Implement footer link actions
        },
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
