// lib/widgets/edit_document_dialog.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';

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

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final provider = Provider.of<DocumentProvider>(context);

    // Combine default and custom categories for the dropdown
    final allCategories = provider.allCategories;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: BoxDecoration(
          color: theme.dialogBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_document,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Edit Document',
                      style: AppTextStyles.headline2.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Document Name',
                        prefixIcon: Icon(
                          Icons.drive_file_rename_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      validator: (value) =>
                          (value?.isEmpty ?? true) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(
                          Icons.description_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(
                          getCategoryIcon(_selectedCategory),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      items: allCategories.map((category) {
                        final isDefault = provider.isDefaultCategory(category);
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                getCategoryIcon(category),
                                color: getCategoryColor(category),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(getCategoryDisplayName(category)),
                              if (!isDefault) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getCategoryBadgeColor(category),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Custom',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: getCategoryColor(category),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.button.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save_rounded,
                                  color:
                                      isDarkMode ? Colors.black : Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Changes',
                                  style: AppTextStyles.button.copyWith(
                                    color: isDarkMode
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
