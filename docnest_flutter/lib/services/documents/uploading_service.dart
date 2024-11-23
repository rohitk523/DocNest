// lib/services/document_uploading_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/document.dart';
import '../../utils/document_filename_utils.dart';
import '../document_service.dart';
import 'cache_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/upload_dialog.dart';
import '../../providers/document_provider.dart';
import '../../screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentUploadingService {
  static Future<void> showUploadDialog(BuildContext context,
      {String? preSelectedCategory}) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => UploadDocumentDialog(
          preSelectedCategory: preSelectedCategory,
        ),
      );

      if (result != null && context.mounted) {
        await handleUpload(
          context: context,
          name: result['name'],
          description: result['description'],
          category: result['category'],
          file: result['file'],
        );
      }
    } catch (e) {
      print('Error in showUploadDialog: $e');
      if (context.mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Upload Error',
          message: 'Error initiating upload: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => showUploadDialog(context,
              preSelectedCategory: preSelectedCategory),
        );
      }
    }
  }

  // For the static method in DocumentUploadingService
  static Future<void> handleUpload({
    required BuildContext context,
    required String name,
    required String description,
    required String category,
    required File file,
  }) async {
    final provider = context.read<DocumentProvider>();

    try {
      showUploadLoadingDialog(context);

      final documentService = DocumentService(token: provider.token);
      final cacheService = CacheService();

      final uploadedDoc = await documentService.uploadDocument(
        name: name,
        description: description,
        category: category,
        file: file,
      );

      final filename = DocumentFilenameUtils.getProperFilename(uploadedDoc);

      if (file is File) {
        final bytes = await file.readAsBytes();
        await cacheService.cacheDocumentWithName(filename, bytes);

        if (uploadedDoc.fileType?.startsWith('image/') == true ||
            uploadedDoc.fileType == 'application/pdf') {
          await cacheService.savePreview(
            uploadedDoc.filePath ?? '',
            uploadedDoc.fileType ?? '',
            bytes,
          );
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Pop our styled loading dialog
        provider.addDocument(uploadedDoc);
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Upload Successful',
          message: 'Document uploaded successfully',
        );
      }
    } catch (e) {
      print('Error in handleUpload: $e');
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);

        if (e.toString().contains('Could not validate credentials')) {
          await const FlutterSecureStorage().delete(key: 'auth_token');
          CustomSnackBar.showInfo(
            context: context,
            title: 'Session Expired',
            message: 'Please log in again to continue',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          CustomSnackBar.showError(
            context: context,
            title: 'Upload Failed',
            message: 'Error uploading document: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: () => handleUpload(
              context: context,
              name: name,
              description: description,
              category: category,
              file: file,
            ),
          );
        }
      }
    }
  }

  static void showUploadLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Uploading document...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> handleAuthError(BuildContext context) async {
    await const FlutterSecureStorage().delete(key: 'auth_token');
    if (context.mounted) {
      CustomSnackBar.showInfo(
        context: context,
        title: 'Session Expired',
        message: 'Please log in again',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }
}
