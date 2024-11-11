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

String formatDateDetailed(DateTime date) {
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

// Enhanced category styling utilities
IconData getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'government':
      return Icons.account_balance;
    case 'medical':
      return Icons.local_hospital;
    case 'educational':
      return Icons.school;
    case 'other':
      return Icons.folder_outlined;
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
    case 'other':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

// New utility function to get background color for category
Color getCategoryBackgroundColor(String category) {
  return getCategoryColor(category).withOpacity(0.1);
}

// New utility function to get category display name
String getCategoryDisplayName(String category) {
  return category[0].toUpperCase() + category.substring(1).toLowerCase();
}

// Optional: Add gradient colors for categories
List<Color> getCategoryGradient(String category) {
  switch (category.toLowerCase()) {
    case 'government':
      return [Colors.blue.shade300, Colors.blue.shade600];
    case 'medical':
      return [Colors.red.shade300, Colors.red.shade600];
    case 'educational':
      return [Colors.green.shade300, Colors.green.shade600];
    case 'other':
      return [Colors.orange.shade300, Colors.orange.shade600];
    default:
      return [Colors.grey.shade300, Colors.grey.shade600];
  }
}

// Optional: Add category badge colors
Color getCategoryBadgeColor(String category) {
  switch (category.toLowerCase()) {
    case 'government':
      return Colors.blue.shade100;
    case 'medical':
      return Colors.red.shade100;
    case 'educational':
      return Colors.green.shade100;
    case 'other':
      return Colors.orange.shade100;
    default:
      return Colors.grey.shade100;
  }
}
