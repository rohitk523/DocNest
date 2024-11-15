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

// Custom category colors map for dynamic categories
final Map<String, Color> _customCategoryColors = {};
int _colorIndex = 0;

// Predefined colors for custom categories
final List<Color> _categoryColorPalette = [
  Colors.purple,
  Colors.teal,
  Colors.indigo,
  Colors.pink,
  Colors.brown,
  Colors.cyan,
  Colors.deepOrange,
  Colors.lightBlue,
  Colors.amber,
  Colors.lime,
];

// Get or generate a color for a custom category
Color _getCustomCategoryColor(String category) {
  if (!_customCategoryColors.containsKey(category)) {
    _customCategoryColors[category] =
        _categoryColorPalette[_colorIndex % _categoryColorPalette.length];
    _colorIndex++;
  }
  return _customCategoryColors[category]!;
}

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
      // Custom category icons based on first letter
      final firstChar = category.toLowerCase()[0];
      switch (firstChar) {
        case 'a':
          return Icons.article_outlined;
        case 'b':
          return Icons.business_outlined;
        case 'c':
          return Icons.calendar_today_outlined;
        case 'd':
          return Icons.description_outlined;
        case 'e':
          return Icons.event_note_outlined;
        case 'f':
          return Icons.folder_special_outlined;
        case 'g':
          return Icons.grade_outlined;
        case 'h':
          return Icons.history_edu_outlined;
        case 'i':
          return Icons.info_outlined;
        case 'j':
          return Icons.join_inner_outlined;
        case 'k':
          return Icons.key_outlined;
        case 'l':
          return Icons.label_outlined;
        case 'm':
          return Icons.menu_book_outlined;
        case 'n':
          return Icons.note_outlined;
        case 'o':
          return Icons.offline_pin_outlined;
        case 'p':
          return Icons.pending_actions_outlined;
        case 'q':
          return Icons.quiz_outlined;
        case 'r':
          return Icons.receipt_long_outlined;
        case 's':
          return Icons.style_outlined;
        case 't':
          return Icons.topic_outlined;
        case 'u':
          return Icons.upcoming_outlined;
        case 'v':
          return Icons.verified_outlined;
        case 'w':
          return Icons.work_outline;
        case 'x':
          return Icons.extension_outlined;
        case 'y':
          return Icons.yard_outlined;
        case 'z':
          return Icons.zoom_in_outlined;
        default:
          return Icons.folder_outlined;
      }
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
      return _getCustomCategoryColor(category.toLowerCase());
  }
}

Color getCategoryBackgroundColor(String category) {
  return getCategoryColor(category).withOpacity(0.1);
}

String getCategoryDisplayName(String category) {
  if (category.isEmpty) return '';
  // Convert snake_case or kebab-case to space-separated
  final normalized = category.replaceAll(RegExp(r'[_-]'), ' ');
  // Capitalize each word
  return normalized.split(' ').map((word) {
    if (word.isEmpty) return '';
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }).join(' ');
}

List<Color> getCategoryGradient(String category) {
  final baseColor = getCategoryColor(category);
  return [
    baseColor.withOpacity(0.7),
    baseColor,
  ];
}

Color getCategoryBadgeColor(String category) {
  return getCategoryColor(category).withOpacity(0.15);
}

// New method to reset custom category colors (useful when logging out)
void resetCustomCategoryColors() {
  _customCategoryColors.clear();
  _colorIndex = 0;
}

// New method to get category accent color (for borders, highlights)
Color getCategoryAccentColor(String category) {
  final baseColor = getCategoryColor(category);
  final hslColor = HSLColor.fromColor(baseColor);
  return hslColor
      .withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0))
      .toColor();
}

// New method for category chip background color
Color getCategoryChipColor(String category, {bool selected = false}) {
  final baseColor = getCategoryColor(category);
  return selected ? baseColor.withOpacity(0.2) : baseColor.withOpacity(0.1);
}

// New method for category text color based on background
Color getCategoryTextColor(String category) {
  final backgroundColor = getCategoryColor(category);
  final grayscale = (0.299 * backgroundColor.red +
      0.587 * backgroundColor.green +
      0.114 * backgroundColor.blue);
  return grayscale > 128 ? Colors.black : Colors.white;
}
