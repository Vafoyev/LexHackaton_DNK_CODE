import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class RedactionResult extends Equatable {
  const RedactionResult({
    required this.redactedText,
    required this.maskedCount,
    required this.categories,
  });

  final String redactedText;
  final int maskedCount;
  final Map<String, int> categories;

  @override
  List<Object?> get props => [redactedText, maskedCount, categories];
}

/// Top-level pure function safe for `compute(...)` across mobile, desktop, and web.
RedactionResult redactUzbekPiiSync(String input) {
  var text = input;
  final counts = <String, int>{};
  var total = 0;

  String replacePattern(RegExp regex, String label) {
    var localCount = 0;
    final updated = text.replaceAllMapped(regex, (_) {
      localCount++;
      total++;
      return '[${label}_$localCount]';
    });
    if (localCount > 0) {
      counts[label] = (counts[label] ?? 0) + localCount;
    }
    return updated;
  }

  // 1. 20-digit Uzbek bank accounts & 16-digit Uzcard/Humo cards (8600/9860/5614)
  text = replacePattern(
    RegExp(r'\b\d{20}\b'),
    'BANK_ACC',
  );
  text = replacePattern(
    RegExp(r'\b(?:8600|9860|5614)(?:[\s-]?\d{4}){3}\b'),
    'CARD',
  );

  // 2. 14-digit JSHSHIR (PINFL)
  text = replacePattern(
    RegExp(r'\b[1-6]\d{13}\b'),
    'JSHSHIR',
  );

  // 3. Passport / ID Card series (e.g. AA 1234567 or AD1234567)
  text = replacePattern(
    RegExp(r'\b[A-Z]{2}\s?\d{7}\b'),
    'PASSPORT',
  );

  // 4. 9-digit STIR / INN (context-aware or standalone 9-digit tax id)
  text = replacePattern(
    RegExp(r'(?:STIR|INN|СТИР|ИНН)[:\s№#]*\d{9}\b', caseSensitive: false),
    'STIR',
  );

  // 5. Uzbek Phone (+998 ...)
  text = replacePattern(
    RegExp(r'\+?998[\s\-()]?\d{2}[\s\-()]?\d{3}[\s\-()]?\d{2}[\s\-()]?\d{2}\b'),
    'PHONE',
  );

  // 6. Email addresses
  text = replacePattern(
    RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
    'EMAIL',
  );

  return RedactionResult(
    redactedText: text,
    maskedCount: total,
    categories: Map.unmodifiable(counts),
  );
}

class PiiRedactor {
  const PiiRedactor._();

  static Future<RedactionResult> redactAsync(String text) {
    return compute(redactUzbekPiiSync, text);
  }
}
