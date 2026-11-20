import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexguard_mobile/features/contracts/data/local_demo_lexguard_repository.dart';
import 'package:lexguard_mobile/features/contracts/domain/entities/lex_models.dart';
import 'package:lexguard_mobile/features/contracts/presentation/cubit/contracts_cubit.dart';

void main() {
  group('ContractsCubit', () {
    late LocalDemoLexGuardRepository repo;
    late ContractsCubit cubit;

    setUp(() {
      repo = LocalDemoLexGuardRepository();
      cubit = ContractsCubit(repo);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('bootstrap loads demo analyses, legal norms, R1-R6 rules and mocks',
        () async {
      await cubit.bootstrap();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.analyses.length, 2);
      expect(cubit.state.legalNorms.length, greaterThanOrEqualTo(5));
      expect(cubit.state.rules.length, 6);
      expect(
        cubit.state.integrations.any((i) => i.isMock),
        isTrue,
      );
    });

    test('runDemoAnalysis creates 4-color findings and supports accept/dismiss',
        () async {
      await cubit.bootstrap();
      final created = await cubit.runDemoAnalysis(
        'sample_b2b_service',
        allowExternalAi: true,
        stepDelay: Duration.zero,
      );
      expect(created, isNotNull);
      expect(created!.countByColor(RiskColor.red), greaterThanOrEqualTo(1));
      expect(created.countByColor(RiskColor.yellow), greaterThanOrEqualTo(1));
      expect(created.countByColor(RiskColor.gray), greaterThanOrEqualTo(1));
      expect(created.countByColor(RiskColor.green), greaterThanOrEqualTo(1));
      expect(created.piiMaskedCount, greaterThan(0));

      final firstId = created.findings.first.id;
      await cubit.setFindingDecision(
        analysisId: created.id,
        findingId: firstId,
        decision: FindingDecision.accepted,
      );
      final updated = cubit.state.findById(created.id);
      expect(updated?.findings.first.decision, FindingDecision.accepted);

      await cubit.deleteAnalysis(created.id);
      expect(cubit.state.findById(created.id), isNull);
    });

    test('runFileAnalysis masks PII and triggers Notarial R6 for real estate',
        () async {
      await cubit.bootstrap();
      const text =
          'Kvartira oldi-sotdi shartnomasi. JSHSHIR: 31205941234567.';
      final result = await cubit.runFileAnalysis(
        fileName: 'kvartira.txt',
        bytes: Uint8List.fromList(text.codeUnits),
        isCameraScan: false,
        allowExternalAi: false,
        hintType: ContractType.realEstateSale,
        stepDelay: Duration.zero,
      );

      expect(result, isNotNull);
      expect(result!.executionMode, 'RULE_ONLY');
      expect(result.piiMaskedCount, 1);
      expect(
        result.findings.any((f) => f.ruleCode == 'R6_NOTARIAL_FORM'),
        isTrue,
      );
    });
  });
}
