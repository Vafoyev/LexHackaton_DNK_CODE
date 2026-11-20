import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

String _sha256HexSync(Uint8List bytes) {
  return sha256.convert(bytes).toString();
}

class FileIntegrity {
  const FileIntegrity._();

  static const int maxBytes = 10 * 1024 * 1024; // 10 MiB per LexGuard spec
  static const List<String> allowedExtensions = [
    'docx',
    'pdf',
    'txt',
    'jpg',
    'jpeg',
    'png',
  ];

  static bool isSupportedExtension(String filename) {
    final parts = filename.toLowerCase().split('.');
    if (parts.length < 2) return false;
    return allowedExtensions.contains(parts.last);
  }

  static Future<String> computeSha256Async(Uint8List bytes) {
    return compute(_sha256HexSync, bytes);
  }
}
