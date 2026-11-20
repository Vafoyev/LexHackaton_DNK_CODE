import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../domain/entities/lex_models.dart';
import '../domain/repositories/lexguard_repository.dart';

/// Production HTTP adapter targeting the Go Modular Monolith (`/api/v1`).
class RemoteLexGuardRepository implements LexGuardRepository {
  RemoteLexGuardRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<ContractAnalysis>> getAnalyses() async {
    final res = await _client.dio.get<Map<String, dynamic>>('/api/v1/analyses');
    final items = (res.data?['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => _parseAnalysis(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<ContractAnalysis?> getAnalysisById(String id) async {
    final res =
        await _client.dio.get<Map<String, dynamic>>('/api/v1/analyses/$id');
    if (res.data == null) return null;
    return _parseAnalysis(res.data!);
  }

  @override
  Future<ContractAnalysis> analyzeDemoSample(
    String sampleId, {
    required bool allowExternalAi,
  }) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '/api/v1/analyses',
      data: {
        'sample_id': sampleId,
        'allow_external_ai': allowExternalAi,
      },
    );
    return _parseAnalysis(res.data ?? const {});
  }

  @override
  Future<ContractAnalysis> analyzeUploadedFile({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    required ContractType hintType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'is_camera_scan': isCameraScan,
      'doc_type': hintType.name,
    });
    final upload = await _client.dio.post<Map<String, dynamic>>(
      '/api/v1/documents',
      data: form,
    );
    final docVersionId = upload.data?['document_version_id'] as String? ?? '';
    final analysis = await _client.dio.post<Map<String, dynamic>>(
      '/api/v1/analyses',
      data: {
        'document_version_id': docVersionId,
        'allow_external_ai': allowExternalAi,
      },
    );
    return _parseAnalysis(analysis.data ?? const {});
  }

  @override
  Future<ContractAnalysis> toggleFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  }) async {
    await _client.dio.post<void>(
      '/api/v1/analyses/$analysisId/findings/$findingId/decision',
      data: {'decision': decision.name},
    );
    final updated = await getAnalysisById(analysisId);
    if (updated == null) {
      throw StateError('Tahlil topilmadi: $analysisId');
    }
    return updated;
  }

  @override
  Future<void> deleteAnalysis(String id) async {
    await _client.dio.delete<void>('/api/v1/documents/$id');
  }

  @override
  Future<List<LegalNorm>> getLegalNorms() async {
    final res =
        await _client.dio.get<Map<String, dynamic>>('/api/v1/legal-sources');
    final items = (res.data?['items'] as List<dynamic>? ?? const []);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return LegalNorm(
        id: m['id'] as String? ?? '',
        code: m['code'] as String? ?? 'LEX-UZ',
        title: m['title'] as String? ?? '',
        article: m['article'] as String? ?? '',
        normNature: m['norm_nature'] as String? ?? 'DISPOSITIVE',
        effectiveFrom: m['effective_from'] as String? ?? '',
        summary: m['summary'] as String? ?? '',
        officialUrl: m['official_url'] as String? ?? 'https://lex.uz/',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<RuleDescriptor>> getRules() async {
    final res = await _client.dio.get<Map<String, dynamic>>('/api/v1/rules');
    final items = (res.data?['items'] as List<dynamic>? ?? const []);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return RuleDescriptor(
        code: m['code'] as String? ?? '',
        title: m['title'] as String? ?? '',
        scope: m['scope'] as String? ?? '',
        defaultCategory: m['default_category'] as String? ?? '',
        description: m['description'] as String? ?? '',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<IntegrationItem>> getIntegrationStatuses() async {
    final res = await _client.dio
        .get<Map<String, dynamic>>('/api/v1/integrations/status');
    final items = (res.data?['items'] as List<dynamic>? ?? const []);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return IntegrationItem(
        name: m['name'] as String? ?? '',
        statusLabel: m['status'] as String? ?? 'MOCK',
        isMock: m['is_mock'] as bool? ?? true,
        description: m['description'] as String? ?? '',
      );
    }).toList(growable: false);
  }

  ContractAnalysis _parseAnalysis(Map<String, dynamic> m) {
    final rawFindings = (m['findings'] as List<dynamic>? ?? const []);
    return ContractAnalysis(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? 'Shartnoma',
      fileName: m['file_name'] as String? ?? 'shartnoma.docx',
      formatLabel: m['format'] as String? ?? 'DOCX',
      languageLabel: m['language'] as String? ?? 'UZ',
      contractType: ContractType.service,
      contractDate: m['contract_date'] as String? ?? '2026-11-21',
      analyzedAt: DateTime.tryParse(m['analyzed_at'] as String? ?? '') ??
          DateTime.now(),
      executionMode: m['execution_mode'] as String? ?? 'RULE_ONLY',
      partyAName: m['party_a'] as String? ?? 'A taraf',
      partyBName: m['party_b'] as String? ?? 'B taraf',
      overallBalanceLabel: m['balance_label'] as String? ?? 'Tekshirildi',
      piiMaskedCount: m['pii_masked'] as int? ?? 0,
      piiCategories: const {},
      sha256Short: m['sha256_short'] as String? ?? '',
      retentionDays: m['retention_days'] as int? ?? 7,
      findings: rawFindings.map((item) {
        final f = item as Map<String, dynamic>;
        final sev = (f['severity'] as String? ?? 'GRAY').toUpperCase();
        final color = switch (sev) {
          'RED' => RiskColor.red,
          'YELLOW' => RiskColor.yellow,
          'GREEN' => RiskColor.green,
          _ => RiskColor.gray,
        };
        return ClauseFinding(
          id: f['id'] as String? ?? '',
          clauseNumber: f['clause_number'] as String? ?? '—',
          title: f['title'] as String? ?? '',
          ruleCode: f['rule_code'] as String? ?? '',
          riskColor: color,
          backendCategory: f['risk_category'] as String? ?? 'UNKNOWN',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: f['balance_label'] as String? ?? 'Muvozanatli',
          originalText: f['original_quote'] as String? ?? '',
          explanation: f['explanation'] as String? ?? '',
          suggestedRevision: f['suggested_revision'] as String? ?? '',
        );
      }).toList(growable: false),
    );
  }
}
