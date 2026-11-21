import 'dart:async';
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
    final res = await _client.dio.get<dynamic>('/api/v1/analyses');
    final items = _extractList(res.data);
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
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/api/v1/analyses',
        data: {
          'sample_id': sampleId,
          'document_id': sampleId,
          'contract_id': sampleId,
          'allow_external_ai': allowExternalAi,
        },
      );

      final data = res.data ?? const {};
      // Agar natija bevosita to'liq qaytgan bo'lsa
      if (data['findings'] is List && (data['findings'] as List).isNotEmpty) {
        return _parseAnalysis(data);
      }

      // Agar asinxron analysis_id qaytgan bo'lsa, polling orqali kutamiz
      final analysisId = data['analysis_id'] as String? ?? data['id'] as String?;
      if (analysisId != null && analysisId.isNotEmpty) {
        final polled = await _pollAnalysisCompletion(analysisId);
        if (polled != null) return polled;
      }

      return _parseAnalysis(data);
    } catch (_) {
      // Backend mock sample fallback
      final mockRes = await _client.dio
          .get<Map<String, dynamic>>('/api/v1/mock/analysis-sample');
      if (mockRes.data != null) {
        return _parseAnalysis(mockRes.data!);
      }
      rethrow;
    }
  }

  @override
  Future<ContractAnalysis> analyzeUploadedFile({
    required String fileName,
    required Uint8List bytes,
    required bool isCameraScan,
    required bool allowExternalAi,
    required ContractType hintType,
  }) async {
    // 1. Faylni /api/v1/documents ga yuklash
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'is_camera_scan': isCameraScan,
      'doc_type': hintType.name,
    });

    final upload = await _client.dio.post<Map<String, dynamic>>(
      '/api/v1/documents',
      data: form,
    );

    // 2. Document ID olish (Go backend `id` qaytaradi)
    final docId = upload.data?['id'] as String? ??
        upload.data?['document_version_id'] as String? ??
        '';

    // 3. Tahlilni /api/v1/analyses orqali boshlash
    final analysis = await _client.dio.post<Map<String, dynamic>>(
      '/api/v1/analyses',
      data: {
        'document_id': docId,
        'contract_id': docId,
        'document_version_id': docId,
        'doc_type': hintType.name,
        'allow_external_ai': allowExternalAi,
      },
    );

    final data = analysis.data ?? const {};
    if (data['findings'] is List && (data['findings'] as List).isNotEmpty) {
      return _parseAnalysis(data);
    }

    final analysisId = data['analysis_id'] as String? ?? data['id'] as String?;
    if (analysisId != null && analysisId.isNotEmpty) {
      final polled = await _pollAnalysisCompletion(analysisId);
      if (polled != null) return polled;
    }

    return _parseAnalysis(data);
  }

  @override
  Future<ContractAnalysis> toggleFindingDecision({
    required String analysisId,
    required String findingId,
    required FindingDecision decision,
  }) async {
    await _client.dio.post<void>(
      '/api/v1/analyses/$analysisId/findings/$findingId/decision',
      data: {'decision': decision.name.toUpperCase()},
    );
    final updated = await getAnalysisById(analysisId);
    if (updated == null) {
      throw StateError('Tahlil topilmadi: $analysisId');
    }
    return updated;
  }

  @override
  Future<void> deleteAnalysis(String id) async {
    try {
      await _client.dio.delete<void>('/api/v1/analyses/$id');
    } catch (_) {
      await _client.dio.delete<void>('/api/v1/documents/$id');
    }
  }

  @override
  Future<List<LegalNorm>> getLegalNorms() async {
    final res = await _client.dio.get<dynamic>('/api/v1/legal-sources');
    final items = _extractList(res.data);
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
        officialUrl: m['official_url'] as String? ??
            m['lex_uz_url'] as String? ??
            'https://lex.uz/',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<RuleDescriptor>> getRules() async {
    final res = await _client.dio.get<dynamic>('/api/v1/rules');
    final items = _extractList(res.data);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return RuleDescriptor(
        code: m['code'] as String? ?? '',
        title: m['title'] as String? ?? m['name'] as String? ?? '',
        scope: m['scope'] as String? ?? m['category'] as String? ?? '',
        defaultCategory: m['default_category'] as String? ??
            m['category'] as String? ??
            '',
        description: m['description'] as String? ??
            m['legal_source'] as String? ??
            '',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<IntegrationItem>> getIntegrationStatuses() async {
    final res = await _client.dio.get<dynamic>('/api/v1/integrations/status');
    final items = _extractList(res.data);
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      final isHealthy = m['is_healthy'] as bool? ?? true;
      final mode = m['mode'] as String? ?? 'MOCK';
      return IntegrationItem(
        name: m['name'] as String? ?? '',
        statusLabel: m['status'] as String? ?? mode,
        isMock: m['is_mock'] as bool? ?? (mode.toUpperCase() == 'MOCK'),
        description: m['description'] as String? ??
            (isHealthy ? 'Sog‘lom (Onlayn)' : 'Tekshirilmoqda'),
      );
    }).toList(growable: false);
  }

  /// Helper extracting a List from either direct List JSON or `{ items: [...] }` / `{ data: [...] }`
  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['items'] is List) return data['items'] as List;
      if (data['data'] is List) return data['data'] as List;
    }
    return const [];
  }

  /// Polling helper waiting for background AI analysis completion
  Future<ContractAnalysis?> _pollAnalysisCompletion(
    String analysisId, {
    int maxAttempts = 6,
    Duration interval = const Duration(milliseconds: 400),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(interval);
      try {
        final analysis = await getAnalysisById(analysisId);
        if (analysis != null && analysis.findings.isNotEmpty) {
          return analysis;
        }
      } catch (_) {
        // Retry
      }
    }
    return null;
  }

  ContractAnalysis _parseAnalysis(Map<String, dynamic> m) {
    final rawFindings = (m['findings'] as List<dynamic>? ?? const []);
    final docMap = m['document'] as Map<String, dynamic>?;
    final summaryMap = m['summary'] as Map<String, dynamic>?;

    final fileName = m['filename'] as String? ??
        m['file_name'] as String? ??
        docMap?['filename'] as String? ??
        'shartnoma.docx';

    final sha = m['sha256'] as String? ?? docMap?['sha256'] as String? ?? '';
    final shaShort = m['sha256_short'] as String? ??
        (sha.length >= 8 ? sha.substring(0, 8) : sha);

    final balanceLabel = m['balance_label'] as String? ??
        summaryMap?['balance_label'] as String? ??
        'Tekshirildi';

    final piiCount = m['pii_masked'] as int? ??
        summaryMap?['pii_masked'] as int? ??
        0;

    return ContractAnalysis(
      id: m['id'] as String? ?? m['analysis_id'] as String? ?? '',
      title: m['title'] as String? ?? fileName,
      fileName: fileName,
      formatLabel: m['format'] as String? ?? 'DOCX',
      languageLabel: m['language'] as String? ?? 'UZ',
      contractType: ContractType.service,
      contractDate: m['contract_date'] as String? ??
          docMap?['contract_date'] as String? ??
          '2026-11-21',
      analyzedAt: DateTime.tryParse(
            m['analyzed_at'] as String? ??
                m['created_at'] as String? ??
                '',
          ) ??
          DateTime.now(),
      executionMode: m['execution_mode'] as String? ?? 'RULE_ONLY',
      partyAName: m['party_a'] as String? ?? 'A taraf',
      partyBName: m['party_b'] as String? ?? 'B taraf',
      overallBalanceLabel: balanceLabel,
      piiMaskedCount: piiCount,
      piiCategories: const {},
      sha256Short: shaShort,
      retentionDays: m['retention_days'] as int? ?? 7,
      findings: rawFindings.map((item) {
        final f = item as Map<String, dynamic>;
        final sev = (f['severity'] as String? ??
                f['risk_level'] as String? ??
                'GRAY')
            .toUpperCase();
        final color = switch (sev) {
          'RED' => RiskColor.red,
          'YELLOW' => RiskColor.yellow,
          'GREEN' => RiskColor.green,
          _ => RiskColor.gray,
        };
        return ClauseFinding(
          id: f['id'] as String? ?? '',
          clauseNumber: f['clause_number'] as String? ?? '—',
          title: f['title'] as String? ??
              f['issue_title'] as String? ??
              '',
          ruleCode: f['rule_code'] as String? ??
              f['rule_id'] as String? ??
              '',
          riskColor: color,
          backendCategory: f['risk_category'] as String? ??
              f['category'] as String? ??
              'UNKNOWN',
          verificationStatus: VerificationStatus.verified,
          balance: NeutralityBalance.balanced,
          balanceLabel: f['balance_label'] as String? ?? 'Muvozanatli',
          originalText: f['original_quote'] as String? ??
              f['problematic_quote'] as String? ??
              '',
          explanation: f['explanation'] as String? ??
              f['issue_explanation'] as String? ??
              '',
          suggestedRevision: f['suggested_revision'] as String? ??
              f['suggested_redline'] as String? ??
              '',
        );
      }).toList(growable: false),
    );
  }
}
