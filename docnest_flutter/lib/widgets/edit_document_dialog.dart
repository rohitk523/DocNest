// lib/widgets/edit_document_dialog.dart
import 'package:flutter/material.dart';
import '../models/document.dart';

class EditDocumentDialog extends StatefulWidget {
  final Document document;

  const EditDocumentDialog({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  _EditDocumentDialogState createState() => _EditDocumentDialogState();
}

class _EditDocumentDialogState extends State<EditDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;

  final List<String> _categories = [
    'government',
    'medical',
    'educational',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.document.name);
    _descriptionController =
        TextEditingController(text: widget.document.description);
    _selectedCategory = widget.document.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        'Edit Document',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
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
                ),
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
                ),
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
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category[0].toUpperCase() + category.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
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
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'category': _selectedCategory,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: isDarkMode ? Colors.black : Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
