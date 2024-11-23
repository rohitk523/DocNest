// lib/utils/document_filename_utils.dart

import '../models/document.dart';

class DocumentFilenameUtils {
  static String getFileExtension(String? mimeType) {
    return switch (mimeType) {
      'application/pdf' => '.pdf',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'application/msword' => '.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        '.docx',
      _ => '',
    };
  }

  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static String getProperFilename(Document document) {
    final extension = getFileExtension(document.fileType);
    final filename =
        document.name + (document.name.endsWith(extension) ? '' : extension);
    return sanitizeFileName(filename);
  }
}
