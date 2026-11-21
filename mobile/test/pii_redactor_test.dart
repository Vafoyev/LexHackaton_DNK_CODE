import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/core/security/pii_redactor.dart';

void main() {
  group('PiiRedactor (O‘RQ-547 / 1125)', () {
    test('masks JSHSHIR, Passport, STIR, Bank Account, Card, Phone and Email',
        () async {
      const input = 'Fuqaro Aliyev (JSHSHIR: 31205941234567, pasport AA 1234567) '
          'va Alfa MChJ (STIR: 301234567, hisob: 20208000100123456789, '
          'karta: 8600 1234 5678 9012, tel: +998901234567, email: test@alfa.uz).';

      final result = await PiiRedactor.redactAsync(input);

      expect(result.maskedCount, 7);
      expect(result.redactedText, contains('[JSHSHIR_1]'));
      expect(result.redactedText, contains('[PASSPORT_1]'));
      expect(result.redactedText, contains('[STIR_1]'));
      expect(result.redactedText, contains('[BANK_ACC_1]'));
      expect(result.redactedText, contains('[CARD_1]'));
      expect(result.redactedText, contains('[PHONE_1]'));
      expect(result.redactedText, contains('[EMAIL_1]'));

      expect(result.redactedText, isNot(contains('31205941234567')));
      expect(result.redactedText, isNot(contains('AA 1234567')));
      expect(result.redactedText, isNot(contains('20208000100123456789')));
      expect(result.redactedText, isNot(contains('test@alfa.uz')));
    });

    test('returns 0 masked items on clean legal clauses', () async {
      const clean =
          'Ijrochi xizmatlarni 10 ish kuni ichida sifatli bajaradi.';
      final result = await PiiRedactor.redactAsync(clean);
      expect(result.maskedCount, 0);
      expect(result.redactedText, clean);
    });
  });
}
