// lib/widgets/upload_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../utils/formatters.dart';

class UploadDocumentDialog extends StatefulWidget {
  const UploadDocumentDialog({super.key});

  @override
  _UploadDocumentDialogState createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  File? _selectedFile;
  bool _isUploading = false;

  // Define categories as objects to ensure unique values
  final List<Map<String, String>> _categories = [
    {'value': 'government', 'label': 'Government'},
    {'value': 'medical', 'label': 'Medical'},
    {'value': 'educational', 'label': 'Educational'},
    {'value': 'other', 'label': 'Other'},
  ];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);

        // Check file size (10MB limit)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'File size must be less than 10MB. Current size: ${formatFileSize(fileSize)}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          if (_nameController.text.isEmpty) {
            _nameController.text = result.files.single.name.split('.').first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleUpload() async {
    if (!_formKey.currentState!.validate() ||
        _selectedFile == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and select a file'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final result = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'file': _selectedFile,
      };

      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        'Upload Document',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      backgroundColor: theme.dialogBackgroundColor,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                dropdownColor: theme.dialogBackgroundColor,
                style: TextStyle(color: theme.colorScheme.onSurface),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category['value'],
                    child: Text(category['label']!),
                  );
                }).toList(),
                validator: (value) =>
                    value == null ? 'Please select a category' : null,
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(
                  Icons.attach_file,
                  color: isDarkMode ? Colors.black : Colors.white,
                ),
                label: Text(
                  _selectedFile == null ? 'Select File' : 'Change File',
                  style: TextStyle(
                    color: isDarkMode ? Colors.black : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isUploading ? null : _pickFile,
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedFile!.path.split('/').last,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<int>(
                  future: _selectedFile!.length(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return Text(
                      formatFileSize(snapshot.data!),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _handleUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: isDarkMode ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
