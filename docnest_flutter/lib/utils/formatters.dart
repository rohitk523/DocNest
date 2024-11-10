// lib/utils/formatters.dart
import 'package:flutter/material.dart';

String formatFileSize(int? size) {
  if (size == null) return '';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

IconData getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'government':
      return Icons.account_balance;
    case 'medical':
      return Icons.local_hospital;
    case 'educational':
      return Icons.school;
    default:
      return Icons.description;
  }
}

Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'government':
      return Colors.blue;
    case 'medical':
      return Colors.red;
    case 'educational':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

String formatDateDetailed(DateTime date) {
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
