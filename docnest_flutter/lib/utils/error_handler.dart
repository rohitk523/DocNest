// lib/utils/error_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void initialize() {
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        // Send to crash reporting service in release mode
        Zone.current.handleUncaughtError(details.exception, details.stack!);
      } else {
        // Show errors in debug mode
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      // Log error
      debugPrint('Caught error: $error');
      debugPrint('Stack trace: $stack');
      return true;
    };
  }
}
