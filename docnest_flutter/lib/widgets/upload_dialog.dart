// lib/widgets/upload_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadDocumentDialog extends StatefulWidget {
  const UploadDocumentDialog({super.key});

  @override
  _UploadDocumentDialogState createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'other';
  File? _selectedFile;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          if (_nameController.text.isEmpty) {
            _nameController.text = result.files.single.name.split('.').first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
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
                    value?.isEmpty ?? true ? 'Required' : null,
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
                items: const [
                  DropdownMenuItem(
                    value: 'government',
                    child: Text('Government'),
                  ),
                  DropdownMenuItem(
                    value: 'medical',
                    child: Text('Medical'),
                  ),
                  DropdownMenuItem(
                    value: 'educational',
                    child: Text('Educational'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Other'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
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
                onPressed: _pickFile,
              ),
              if (_selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _selectedFile!.path.split('/').last,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_selectedFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a file')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': _nameController.text,
                'description': _descriptionController.text,
                'category': _selectedCategory,
                'file': _selectedFile,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: isDarkMode ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Upload'),
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
