import 'dart:typed_data';

import '../entities/lex_models.dart';

abstract interface class LexGuardRepository {
  Future<List<ContractAnalysis>> getAnalyses();

  Future<ContractAnalysis?> getAnalysisById(String id);

  Future<ContractAnalysis> analyzeDemoSample(
    String sampleId, {
    required bool allowExternalAi,
  });

  Future<ContractAnalysis> analyzeUploadedFile({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    required ContractType hintType,
  });

  Future<ContractAnalysis> toggleFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  });

  Future<void> deleteAnalysis(String id);

  Future<List<LegalNorm>> getLegalNorms();

  Future<List<RuleDescriptor>> getRules();

  Future<List<IntegrationItem>> getIntegrationStatuses();
}
