// lib/widgets/custom_snackbar.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel, // Keep existing parameter names
    VoidCallback? onAction, // Keep existing parameter names
    bool showProgress = false,
  }) {
    final theme = Theme.of(context);
    final isError = type == SnackBarType.error;
    final color = isError ? Colors.red : Colors.green;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onAction?.call();
                },
              )
            : null,
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  // For loading states
  static void showLoading(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      showProgress: true,
      duration: const Duration(days: 1),
    );
  }

  static void hideLoading(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
