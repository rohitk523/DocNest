import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final contentType = _getContentType(type);

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: contentType,
        inMaterialBanner: false,
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: _getActionTextColor(type),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction?.call();
              },
            )
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static ContentType _getContentType(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return ContentType.success;
      case SnackBarType.error:
        return ContentType.failure;
      case SnackBarType.warning:
        return ContentType.warning;
      case SnackBarType.info:
        return ContentType.help;
    }
  }

  static Color _getActionTextColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Colors.green.shade800;
      case SnackBarType.error:
        return Colors.red.shade800;
      case SnackBarType.warning:
        return Colors.orange.shade800;
      case SnackBarType.info:
        return Colors.blue.shade800;
    }
  }

  // Convenience methods
  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SnackBarType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SnackBarType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SnackBarType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      title: title,
      message: message,
      type: SnackBarType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  // For loading states
  static void showLoading(BuildContext context, String message) {
    show(
      context: context,
      title: 'Loading',
      message: message,
      type: SnackBarType.info,
      duration: const Duration(days: 1),
    );
  }

  static void hideLoading(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
