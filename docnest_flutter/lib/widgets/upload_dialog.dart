import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import '../theme/app_theme.dart';

class UploadDocumentDialog extends StatefulWidget {
  final String? preSelectedCategory;

  const UploadDocumentDialog({
    super.key,
    this.preSelectedCategory,
  });

  @override
  _UploadDocumentDialogState createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _selectedCategory;
  File? _selectedFile;
  bool _isUploading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'government', 'label': 'Government'},
    {'value': 'medical', 'label': 'Medical'},
    {'value': 'educational', 'label': 'Educational'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preSelectedCategory?.toLowerCase() ?? 'other';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File size must be less than 10MB. Current size: ${formatFileSize(fileSize)}',
                ),
                backgroundColor: AppColors.errorLight,
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
            backgroundColor: AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleUpload() {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Please fill all required fields and select a file'),
          backgroundColor: AppColors.errorLight,
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
        'category':
            widget.preSelectedCategory?.toLowerCase() ?? _selectedCategory,
        'file': _selectedFile,
      };

      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.errorLight,
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
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;

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
        child: SingleChildScrollView(
          padding:
              EdgeInsets.only(bottom: bottomPadding), // Adjust for keyboard
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.upload_file,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.preSelectedCategory != null
                                ? 'Upload ${widget.preSelectedCategory!.toUpperCase()} Document'
                                : 'Upload Document',
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
                    if (_selectedFile == null) ...[
                      const SizedBox(height: 24),
                      DragTarget<String>(
                        onWillAccept: (data) => true,
                        onAccept: (data) => _pickFile(),
                        builder: (context, candidateData, rejectedData) {
                          return InkWell(
                            onTap: _pickFile,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.3),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Drag and drop files here\nor click to browse',
                                    style: AppTextStyles.subtitle1.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Supported formats: PDF, DOC, DOCX, JPG, JPEG, PNG',
                                    style: AppTextStyles.caption.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                      if (_selectedFile != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.insert_drive_file,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFile!.path.split('/').last,
                                      style: AppTextStyles.subtitle1.copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<int>(
                                      future: _selectedFile!.length(),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.hasData
                                              ? formatFileSize(snapshot.data!)
                                              : 'Calculating size...',
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _pickFile,
                                icon: Icon(
                                  Icons.change_circle_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Document Name',
                          prefixIcon: Icon(
                            Icons.drive_file_rename_outline,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        validator: (value) => (value?.isEmpty ?? true)
                            ? 'Name is required'
                            : null,
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
                      if (widget.preSelectedCategory == null) ...[
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
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category['value'],
                              child: Row(
                                children: [
                                  Icon(
                                    getCategoryIcon(category['value']!),
                                    color: getCategoryColor(category['value']!),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(category['label']!),
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
                      ],
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isUploading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                              onPressed: _isUploading ? null : _handleUpload,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: theme.colorScheme.primary,
                              ),
                              child: _isUploading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.upload_rounded,
                                          color: isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Upload Document',
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
